# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# Client for Munda Manager's public campaign data API.
# https://www.mundamanager.com/api-access — no auth, rate limited 10 req/min.
module MundaManager
  BASE = "https://www.mundamanager.com"
  UUID_RE = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  Error = Class.new(StandardError)

  # Munda Manager gang types are close to ours; normalise known variants.
  TYPE_ALIASES = {
    "escher" => "House Escher", "goliath" => "House Goliath",
    "van saar" => "House Van Saar", "orlock" => "House Orlock",
    "delaque" => "House Delaque", "cawdor" => "House Cawdor",
    "enforcers" => "Palanite Enforcers", "palanite enforcers" => "Palanite Enforcers",
    "genestealer cults" => "Genestealer Cult", "genestealer cult" => "Genestealer Cult",
    "chaos cults" => "Helot Chaos Cult", "helot chaos cult" => "Helot Chaos Cult",
    "corpse grinder cults" => "Corpse Grinder Cult", "corpse grinder cult" => "Corpse Grinder Cult",
    "ash waste nomads" => "Ash Waste Nomads",
    "squat prospectors" => "Ironhead Squat Prospectors",
    "ironhead squat prospectors" => "Ironhead Squat Prospectors",
    "slave ogryns" => "Slave Ogryns", "spyrers" => "Spyrers",
    "underhive outcasts" => "Underhive Outcasts", "outcasts" => "Underhive Outcasts",
    "venators" => "Venators", "venators (bounty hunters)" => "Venators"
  }.freeze

  module_function

  def valid_uuid?(id) = !!(id.to_s.strip =~ UUID_RE)

  def normalise_type(type)
    t = type.to_s.strip
    TYPE_ALIASES[t.downcase] || TYPE_ALIASES[t.downcase.sub(/\Ahouse /, "")] || t
  end

  # Fetches campaign data; returns the parsed JSON hash.
  def fetch_campaign(campaign_id)
    id = campaign_id.to_s.strip
    raise Error, "Invalid Munda Manager campaign ID (expected a UUID)" unless valid_uuid?(id)

    uri = URI("#{BASE}/api/campaigns/#{id}/data?format=json")
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: 10, read_timeout: 15) do |http|
      req = Net::HTTP::Get.new(uri)
      req["Accept"] = "application/json"
      req["User-Agent"] = "HIVEHUB (Necromunda campaign map manager)"
      http.request(req)
    end
    case res.code.to_i
    when 200 then JSON.parse(res.body)
    when 404 then raise Error, "Campaign not found on Munda Manager"
    when 429 then raise Error, "Munda Manager rate limit hit — wait a minute and retry"
    else raise Error, "Munda Manager returned HTTP #{res.code}"
    end
  rescue JSON::ParserError
    raise Error, "Munda Manager returned unparseable data"
  rescue Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
    raise Error, "Could not reach Munda Manager: #{e.class}"
  end

  # Flattens the campaign payload into a list of gang hashes.
  def gangs_from(payload)
    (payload["members"] || []).flat_map do |member|
      owner = member.dig("user_info", "username")
      (member["gangs"] || []).map do |g|
        {
          mm_id: g["id"],
          name: g["name"].to_s,
          gang_type: normalise_type(g["type"]),
          owner: owner,
          rating: g["rating"],
          credits: g["credits"],
          reputation: g["reputation"]
        }
      end
    end
  end

  def campaign_name_from(payload) = payload.dig("campaign", "campaign_name")
end
