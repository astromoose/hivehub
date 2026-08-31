# frozen_string_literal: true

require "sinatra"
require "sinatra/json"
require "bcrypt"
require "net/http"
require "json"
require "securerandom"

require_relative "lib/models"
require_relative "lib/flavour"
require_relative "lib/generator"
require_relative "lib/icons"
require_relative "lib/munda_manager"

set :public_folder, File.join(__dir__, "public")
set :views, File.join(__dir__, "views")

use Rack::Session::Cookie,
    key: "hivehub.session",
    secret: ENV.fetch("SESSION_SECRET") { SecureRandom.hex(64) },
    expire_after: 60 * 60 * 24 * 14

GITHUB_CLIENT_ID = ENV["GITHUB_CLIENT_ID"]
GITHUB_CLIENT_SECRET = ENV["GITHUB_CLIENT_SECRET"]

helpers do
  def current_user
    @current_user ||= session[:user_id] && User[session[:user_id]]
  end

  def require_login!
    redirect "/login" unless current_user
  end

  def own_campaign!(id)
    campaign = Campaign[id.to_i]
    halt 404, erb(:not_found) unless campaign && campaign.user_id == current_user.id
    campaign
  end

  def own_zone!(id)
    zone = Zone[id.to_i]
    halt 404, erb(:not_found) unless zone && zone.campaign.user_id == current_user.id
    zone
  end

  def github_enabled? = GITHUB_CLIENT_ID && GITHUB_CLIENT_SECRET

  def h(text) = Rack::Utils.escape_html(text.to_s)

  def footer_quote = Flavour.quote

  def gang_icon_path(gang)
    Icons::PATHS[gang.icon || Icons.for_gang_type(gang.gang_type)]
  end

  # Inline SVG icon tinted with the gang's colour, for rosters/legends.
  def gang_icon_svg(gang, size: 18)
    path = gang_icon_path(gang)
    return "" unless path

    %(<svg class="gang-icon" width="#{size}" height="#{size}" viewBox="0 0 512 512" aria-hidden="true"><path fill="#{h gang.color}" d="#{path}"/></svg>)
  end
end

# ---------- Auth ----------

get "/" do
  current_user ? redirect("/dashboard") : redirect("/login")
end

get "/login" do
  redirect "/dashboard" if current_user
  erb :login
end

post "/login" do
  user = User.first(username: params[:username].to_s.strip.downcase)
  if user&.password_hash && BCrypt::Password.new(user.password_hash) == params[:password].to_s
    session[:user_id] = user.id
    redirect "/dashboard"
  else
    @error = "Access denied. The cogitator does not recognise you."
    erb :login
  end
end

get "/register" do
  redirect "/dashboard" if current_user
  erb :register
end

post "/register" do
  username = params[:username].to_s.strip.downcase
  password = params[:password].to_s
  if username !~ /\A[a-z0-9_\-]{3,32}\z/
    @error = "Callsign must be 3-32 characters: letters, numbers, - or _."
  elsif password.length < 8
    @error = "Passphrase must be at least 8 characters. The underhive is unforgiving."
  elsif User.first(username: username)
    @error = "That callsign is already carved into the wall."
  else
    user = User.create(username: username, display_name: params[:display_name].to_s.strip.then { it.empty? ? username : it },
                       password_hash: BCrypt::Password.create(password), created_at: Time.now)
    session[:user_id] = user.id
    redirect "/dashboard"
  end
  erb :register
end

post "/logout" do
  session.clear
  redirect "/login"
end

# ---------- GitHub OAuth ----------

get "/auth/github" do
  halt 404 unless github_enabled?
  state = SecureRandom.hex(16)
  session[:oauth_state] = state
  redirect "https://github.com/login/oauth/authorize?" + URI.encode_www_form(
    client_id: GITHUB_CLIENT_ID, state: state, scope: "read:user"
  )
end

get "/auth/github/callback" do
  halt 404 unless github_enabled?
  halt 400, "State mismatch" unless params[:state] == session.delete(:oauth_state)

  token_res = Net::HTTP.post(
    URI("https://github.com/login/oauth/access_token"),
    URI.encode_www_form(client_id: GITHUB_CLIENT_ID, client_secret: GITHUB_CLIENT_SECRET, code: params[:code]),
    "Accept" => "application/json"
  )
  token = JSON.parse(token_res.body)["access_token"]
  halt 400, "GitHub token exchange failed" unless token

  user_req = Net::HTTP::Get.new(URI("https://api.github.com/user"))
  user_req["Authorization"] = "Bearer #{token}"
  user_req["Accept"] = "application/vnd.github+json"
  gh = Net::HTTP.start("api.github.com", 443, use_ssl: true) { |http| http.request(user_req) }
  profile = JSON.parse(gh.body)
  halt 400, "GitHub profile fetch failed" unless profile["id"]

  user = User.first(github_uid: profile["id"].to_s) || User.create(
    github_uid: profile["id"].to_s,
    display_name: profile["name"] || profile["login"],
    created_at: Time.now
  )
  session[:user_id] = user.id
  redirect "/dashboard"
end

# ---------- Campaigns ----------

get "/dashboard" do
  require_login!
  @campaigns = current_user.campaigns_dataset.order(Sequel.desc(:created_at)).all
  erb :dashboard
end

post "/campaigns" do
  require_login!
  name = params[:name].to_s.strip
  if name.empty?
    redirect "/dashboard"
  else
    campaign = Campaign.create(user_id: current_user.id, name: name,
                               description: params[:description].to_s.strip, created_at: Time.now)
    Generator.generate_zone(campaign)
    redirect "/campaigns/#{campaign.id}"
  end
end

get "/campaigns/:id" do
  require_login!
  @campaign = own_campaign!(params[:id])
  @zones = @campaign.zones
  @gangs = @campaign.gangs
  erb :campaign
end

post "/campaigns/:id/delete" do
  require_login!
  own_campaign!(params[:id]).destroy
  redirect "/dashboard"
end

post "/campaigns/:id/zones" do
  require_login!
  campaign = own_campaign!(params[:id])
  begin
    zone = Generator.generate_zone(campaign)
    redirect "/zones/#{zone.id}"
  rescue RuntimeError => e
    session[:flash] = e.message
    redirect "/campaigns/#{campaign.id}"
  end
end

post "/campaigns/:id/gangs" do
  require_login!
  campaign = own_campaign!(params[:id])
  name = params[:name].to_s.strip
  gang_type = params[:gang_type].to_s
  if name.empty? || !Flavour::GANG_TYPES.include?(gang_type)
    session[:flash] = "A gang needs a name and a recognised affiliation."
  else
    begin
      Generator.add_gang(campaign, name: name, gang_type: gang_type)
    rescue RuntimeError => e
      session[:flash] = e.message
    end
  end
  redirect "/campaigns/#{campaign.id}"
end

post "/gangs/:id/delete" do
  require_login!
  gang = Gang[params[:id].to_i]
  halt 404 unless gang && gang.campaign.user_id == current_user.id
  gang.destroy
  redirect "/campaigns/#{gang.campaign_id}"
end

# ---------- Munda Manager integration ----------

post "/campaigns/:id/munda/link" do
  require_login!
  campaign = own_campaign!(params[:id])
  mm_id = params[:mm_campaign_id].to_s.strip
  if mm_id.empty?
    campaign.update(mm_campaign_id: nil, mm_campaign_name: nil, mm_synced_at: nil)
    session[:flash] = "Munda Manager uplink severed."
  else
    begin
      payload = MundaManager.fetch_campaign(mm_id)
      campaign.update(mm_campaign_id: mm_id,
                      mm_campaign_name: MundaManager.campaign_name_from(payload),
                      mm_synced_at: Time.now)
      session[:flash] = "Uplink established: #{MundaManager.campaign_name_from(payload)}"
    rescue MundaManager::Error => e
      session[:flash] = e.message
    end
  end
  redirect "/campaigns/#{campaign.id}"
end

post "/campaigns/:id/munda/import" do
  require_login!
  campaign = own_campaign!(params[:id])
  halt 400, "No Munda Manager campaign linked" unless campaign.mm_campaign_id
  begin
    payload = MundaManager.fetch_campaign(campaign.mm_campaign_id)
    known = campaign.gangs_dataset.exclude(mm_gang_id: nil).select_map(:mm_gang_id)
    imported = 0
    skipped = []
    MundaManager.gangs_from(payload).each do |mm|
      next if mm[:mm_id].nil? || known.include?(mm[:mm_id]) || mm[:name].empty?

      begin
        gang = Generator.add_gang(campaign, name: mm[:name], gang_type: mm[:gang_type])
        gang.update(mm_gang_id: mm[:mm_id], mm_owner: mm[:owner], mm_rating: mm[:rating],
                    mm_credits: mm[:credits], mm_reputation: mm[:reputation])
        imported += 1
      rescue RuntimeError => e
        skipped << "#{mm[:name]} (#{e.message})"
      end
    end
    campaign.update(mm_campaign_name: MundaManager.campaign_name_from(payload), mm_synced_at: Time.now)
    msg = "Imported #{imported} gang#{"s" unless imported == 1} from Munda Manager."
    msg += " Skipped: #{skipped.join("; ")}" unless skipped.empty?
    session[:flash] = msg
  rescue MundaManager::Error => e
    session[:flash] = e.message
  end
  redirect "/campaigns/#{campaign.id}"
end

post "/campaigns/:id/munda/sync" do
  require_login!
  campaign = own_campaign!(params[:id])
  halt 400, "No Munda Manager campaign linked" unless campaign.mm_campaign_id
  begin
    payload = MundaManager.fetch_campaign(campaign.mm_campaign_id)
    by_mm_id = MundaManager.gangs_from(payload).to_h { |g| [g[:mm_id], g] }
    updated = 0
    campaign.gangs_dataset.exclude(mm_gang_id: nil).each do |gang|
      mm = by_mm_id[gang.mm_gang_id] or next
      gang.update(mm_owner: mm[:owner], mm_rating: mm[:rating],
                  mm_credits: mm[:credits], mm_reputation: mm[:reputation])
      updated += 1
    end
    campaign.update(mm_campaign_name: MundaManager.campaign_name_from(payload), mm_synced_at: Time.now)
    session[:flash] = "Synced stats for #{updated} gang#{"s" unless updated == 1} from Munda Manager."
  rescue MundaManager::Error => e
    session[:flash] = e.message
  end
  redirect "/campaigns/#{campaign.id}"
end

# ---------- Zones & turf ----------

post "/zones/:id/archive" do
  require_login!
  zone = own_zone!(params[:id])
  zone.update(archived_at: zone.archived? ? nil : Time.now)
  session[:flash] = zone.archived? ? "Season #{zone.season} consigned to the archives." : "Season #{zone.season} restored to active record."
  redirect "/campaigns/#{zone.campaign_id}"
end

post "/zones/:id/delete" do
  require_login!
  zone = own_zone!(params[:id])
  campaign_id = zone.campaign_id
  zone.turfs_dataset.delete
  zone.delete
  session[:flash] = "Season #{zone.season} purged from the Guilder charts."
  redirect "/campaigns/#{campaign_id}"
end

get "/zones/:id" do
  require_login!
  @zone = own_zone!(params[:id])
  @campaign = @zone.campaign
  erb :zone
end

get "/zones/:id/data" do
  require_login!
  zone = own_zone!(params[:id])
  gangs = zone.campaign.gangs
  json(
    zone: { id: zone.id, name: zone.name, season: zone.season, description: zone.description },
    gangs: gangs.map { |g| { id: g.id, name: g.name, gang_type: g.gang_type, color: g.color, icon_path: gang_icon_path(g) } },
    turfs: zone.turfs.map do |t|
      { id: t.id, q: t.q, r: t.r, name: t.name, description: t.description,
        gang_id: t.gang_id, home_gang_id: t.home_gang_id }
    end
  )
end

post "/turfs/:id/assign" do
  require_login!
  turf = Turf[params[:id].to_i]
  halt 404 unless turf && turf.zone.campaign.user_id == current_user.id
  body = JSON.parse(request.body.read) rescue {}
  gang_id = body["gang_id"]
  if gang_id.nil?
    turf.update(gang_id: nil)
  else
    gang = Gang[gang_id.to_i]
    halt 422, json(error: "Unknown gang") unless gang && gang.campaign_id == turf.zone.campaign_id
    turf.update(gang_id: gang.id)
  end
  json(ok: true, turf: { id: turf.id, gang_id: turf.gang_id, home_gang_id: turf.home_gang_id })
end

not_found do
  erb :not_found
end
