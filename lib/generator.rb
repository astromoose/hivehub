# frozen_string_literal: true

require_relative "models"
require_relative "flavour"
require_relative "territories"
require_relative "icons"

# Generates zones (seasons) as random connected hexmaps sized by the
# Dominion territory table (3 turfs per gang, min 3 gangs, +2-6 extra),
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

  # Expands an existing zone's map to `target` turfs by frontier growth,
  # dealing fresh territory types for the new ground.
  def grow_zone(zone, target, rng = Random)
    turfs = zone.turfs_dataset.all
    add = target - turfs.size
    return zone if add <= 0

    cells = turfs.to_h { |t| [[t.q, t.r], true] }
    frontier = cells.keys.flat_map { |c| neighbours(*c) }.reject { |c| cells[c] }
    new_cells = []
    while new_cells.size < add
      cell = frontier.sample(random: rng)
      next if cells[cell]

      cells[cell] = true
      new_cells << cell
      frontier.concat(neighbours(*cell).reject { |n| cells[n] })
      frontier.reject! { |n| cells[n] }
    end

    types = Territories.deal(add, rng)
    used_prefixes = turfs.map { |t| t.name.split(" ", 2).first }
    prefixes = (Flavour::TURF_PREFIX - used_prefixes).sample(add, random: rng)
    descs = Flavour.turf_descriptions(add, rng)
    new_cells.each_with_index do |(q, r), i|
      Turf.create(zone_id: zone.id, q: q, r: r, name: "#{prefixes[i]} #{types[i]}",
                  description: descs[i], territory_type: types[i], created_at: Time.now)
    end
    zone
  end

  # Dominion territories per gang, per the N26 rulebook table
  # (3 players → 9, 4 → 12, ... i.e. three per player), assuming a minimum
  # of 3 players, plus 2-6 extra turfs of Arbitrator's discretion.
  TERRITORIES_PER_GANG = 3
  MIN_GANGS_FOR_SIZING = 3
  EXTRA_TURFS = (2..6).freeze
  MAX_GANGS = 10 # distinct gang colours

  # Creates a new zone (season) for the campaign, sized per the Dominion
  # territory table for the campaign's gang count. Guarantees >= 50%
  # no-man's-land and gives every existing gang a home on a map edge.
  def generate_zone(campaign, rng = Random)
    gangs = campaign.gangs_dataset.order(:created_at).all
    raise "Too many gangs (max #{MAX_GANGS})" if gangs.size > MAX_GANGS

    count = TERRITORIES_PER_GANG * [MIN_GANGS_FOR_SIZING, gangs.size].max + rng.rand(EXTRA_TURFS)
    season = (campaign.zones_dataset.max(:season) || 0) + 1

    zone = Zone.create(
      campaign_id: campaign.id,
      name: Flavour.zone_name(rng),
      season: season,
      description: Flavour.zone_description(rng),
      created_at: Time.now
    )

    cells = random_hexes(count, rng)
    types = Territories.deal(count, rng)
    prefixes = Flavour.turf_prefixes(count, rng)
    descs = Flavour.turf_descriptions(count, rng)
    cells.each_with_index do |(q, r), i|
      Turf.create(zone_id: zone.id, q: q, r: r, name: "#{prefixes[i]} #{types[i]}",
                  description: descs[i], territory_type: types[i], created_at: Time.now)
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
    # In Dominion campaigns every gang holds a Settlement as its home
    # territory, which cannot be lost or staked. Rename to match.
    name = home.territory_type ? home.name.sub(home.territory_type, Territories::HOME) : home.name
    home.update(gang_id: gang.id, home_gang_id: gang.id,
                territory_type: Territories::HOME, name: name)
    home
  end

  # Adds a gang to a campaign and gives it a home on the latest zone.
  # The map grows to the Dominion table size for the new gang count if
  # needed, and the 50% no-man's-land rule is enforced.
  def add_gang(campaign, name:, gang_type:, rng: Random)
    zone = campaign.latest_zone
    raise "No active season: chart a new zone before adding gangs" unless zone
    raise "Campaign is full (max #{MAX_GANGS} gangs)" if campaign.gangs_dataset.count >= MAX_GANGS

    gangs_after = campaign.gangs_dataset.count + 1
    min_size = TERRITORIES_PER_GANG * [MIN_GANGS_FOR_SIZING, gangs_after].max + EXTRA_TURFS.min
    grow_zone(zone, min_size, rng)

    turf_count = zone.turfs_dataset.count
    claimed = zone.turfs_dataset.exclude(gang_id: nil).count
    raise "Map is at capacity: at least 50% must remain no-man's-land" if claimed + 1 > turf_count / 2

    color = GANG_COLORS[campaign.gangs_dataset.count % GANG_COLORS.size]
    gang = Gang.create(campaign_id: campaign.id, name: name, gang_type: gang_type,
                       color: color, icon: Icons.for_gang_type(gang_type), created_at: Time.now)
    assign_home(zone, gang, rng)
    gang
  end
end
