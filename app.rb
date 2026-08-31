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

# ---------- Zones & turf ----------

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
    gangs: gangs.map { |g| { id: g.id, name: g.name, gang_type: g.gang_type, color: g.color } },
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
