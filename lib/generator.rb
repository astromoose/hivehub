# frozen_string_literal: true

require_relative "models"
require_relative "flavour"

# Generates zones (seasons) as random connected hexmaps of 12-20 turfs,
# and assigns gang home turf on map edges.
module Generator
  AXIAL_DIRS = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]].freeze

  # Gang colours: base palette + lightened variants for gangs 6-10.
  PALETTE = %w[#4a3b59 #a67d99 #c3b298 #6b9e9d #3b5a7d].freeze
  GANG_COLORS = (PALETTE + PALETTE.map { |c| tint = c[1..].scan(/../).map { |h| v = h.to_i(16); (v + (255 - v) * 0.4).round }; format("#%02x%02x%02x", *tint) }).freeze

  module_function

  def neighbours(q, r) = AXIAL_DIRS.map { |dq, dr| [q + dq, r + dr] }

  # Random connected blob of `count` axial hexes grown from origin.
  def random_hexes(count, rng = Random)
    hexes = { [0, 0] => true }
    frontier = neighbours(0, 0)
    while hexes.size < count
      cell = frontier.sample(random: rng)
      next if hexes[cell]

      hexes[cell] = true
      frontier.concat(neighbours(*cell).reject { |n| hexes[n] })
      frontier.reject! { |n| hexes[n] }
    end
    hexes.keys
  end

  def edge?(cell, cells_set)
    neighbours(*cell).any? { |n| !cells_set.include?(n) }
  end

  # Creates a new zone (season) for the campaign, with 12-20 turfs.
  # Guarantees >= 50% no-man's-land: turf count is at least twice the gang
  # count, and every existing gang gets a home on a map edge.
  def generate_zone(campaign, rng = Random)
    gangs = campaign.gangs_dataset.order(:created_at).all
    raise "Too many gangs for a 20-turf map (max 10)" if gangs.size > 10

    min_turfs = [12, gangs.size * 2].max
    count = rng.rand(min_turfs..20)
    season = (campaign.zones_dataset.max(:season) || 0) + 1

    zone = Zone.create(
      campaign_id: campaign.id,
      name: Flavour.zone_name(rng),
      season: season,
      description: Flavour.zone_description(rng),
      created_at: Time.now
    )

    cells = random_hexes(count, rng)
    flavour = Flavour.turf_batch(count, rng)
    cells.each_with_index do |(q, r), i|
      name, desc = flavour[i]
      Turf.create(zone_id: zone.id, q: q, r: r, name: name, description: desc, created_at: Time.now)
    end

    gangs.each { |gang| assign_home(zone, gang, rng) }
    zone
  end

  # Picks a random unowned edge turf as the gang's home in this zone.
  def assign_home(zone, gang, rng = Random)
    turfs = zone.turfs_dataset.all
    cells_set = turfs.map { |t| [t.q, t.r] }.to_h { |c| [c, true] }
    candidates = turfs.select { |t| t.gang_id.nil? && edge?([t.q, t.r], cells_set) }
    raise "No unclaimed edge turf left in #{zone.name}" if candidates.empty?

    home = candidates.sample(random: rng)
    home.update(gang_id: gang.id, home_gang_id: gang.id)
    home
  end

  # Adds a gang to a campaign and gives it a home on the latest zone.
  # Enforces the 50% no-man's-land rule at generation/addition time.
  def add_gang(campaign, name:, gang_type:, rng: Random)
    zone = campaign.latest_zone
    raise "No active season: chart a new zone before adding gangs" unless zone

    turf_count = zone.turfs_dataset.count
    claimed = zone.turfs_dataset.exclude(gang_id: nil).count
    raise "Map is at capacity: at least 50% must remain no-man's-land" if claimed + 1 > turf_count / 2

    color = GANG_COLORS[campaign.gangs_dataset.count % GANG_COLORS.size]
    gang = Gang.create(campaign_id: campaign.id, name: name, gang_type: gang_type,
                       color: color, created_at: Time.now)
    assign_home(zone, gang, rng)
    gang
  end
end
