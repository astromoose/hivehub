# frozen_string_literal: true

# HIVEHUB — Necromunda flavour text pools.
module Flavour
  GANG_TYPES = [
    "House Escher", "House Goliath", "House Van Saar", "House Orlock",
    "House Delaque", "House Cawdor", "Palanite Enforcers", "Genestealer Cult",
    "Helot Chaos Cult", "Corpse Grinder Cult", "Ash Waste Nomads",
    "Ironhead Squat Prospectors", "Slave Ogryns", "Spyrers",
    "Underhive Outcasts", "Venators"
  ].freeze

  ZONE_PREFIX = %w[
    Sump Dust Ash Rust Slag Grime Cinder Gloom Sludge Vent
    Smelter Corpse Ember Static Rad Chem Scrap Murk Soot Grav
  ].freeze

  ZONE_SUFFIX = [
    "Falls", "Reach", "Warrens", "Hollows", "Spill", "Deeps", "Span",
    "Gulch", "Sprawl", "Terraces", "Sink", "Crossing", "Barrens",
    "Stacks", "Shambles", "Verge", "Wells", "Drift"
  ].freeze

  ZONE_DESCRIPTIONS = [
    "A forgotten sub-cluster where the dome-lights failed a generation ago. What light remains is sold by the hour.",
    "Once a thriving manufactorum district, now a maze of dead machinery and living grudges.",
    "The air recyclers here run at half capacity. So does the law.",
    "Downhive of the last Guilder outpost, where the water tithe is paid in blood as often as credits.",
    "A borderland of collapsed hab-stacks and flickering lumen-strips, claimed by everyone and held by no one.",
    "The Merchant Guild marked this sector 'unprofitable'. The gangs marked it 'home'.",
    "Rad-runoff from the spires above pools here, glowing faintly. The locals call it weather.",
    "An old mining concession, stripped bare of ore but rich in places to hide a body.",
    "Every tunnel here has two names: the one on the Guilder charts, and the one whispered after dark.",
    "The Enforcers patrol the perimeter once a cycle. Inside, older laws apply."
  ].freeze

  TURF_PREFIX = [
    "Collapsed", "Rusted", "Flooded", "Derelict", "Smog-choked", "Rad-scarred",
    "Abandoned", "Shattered", "Crumbling", "Blistered", "Half-lit", "Forsaken",
    "Leaking", "Scav-picked", "Burnt-out", "Creaking", "Sunken", "Sealed",
    "Howling", "Toxic"
  ].freeze

  TURF_PLACE = [
    "Dome", "Refinery", "Hab-block", "Promethium Cache", "Sludge Works",
    "Vent Shaft", "Fighting Pit", "Water Still", "Drinking Hole", "Chem Pit",
    "Slag Heap", "Manufactorum", "Transit Hub", "Guilder Post", "Shrine",
    "Archeotech Dig", "Cable Farm", "Corpse Farm", "Toll Bridge", "Gantry Maze",
    "Settlement", "Blackmarket Row"
  ].freeze

  TURF_DESCRIPTIONS = [
    "The rats here are big enough to saddle, and twice as mean.",
    "A tithe-collector went missing here in '26. His autoquill is still writing somewhere in the dark.",
    "Locals swear the pipes whisper heresy after the third shift-bell.",
    "Good sight-lines, bad air. Bring a rebreather and a friend you can outrun.",
    "The last three owners died of unnatural causes. All eighteen of them.",
    "Sump-water on tap and only mildly luminous. A prize worth bleeding for.",
    "Every wall bears the scorch-marks of old claims and older feuds.",
    "A Guilder once offered two thousand credits for this plot. Nobody ever found the Guilder.",
    "The floor is stable. Mostly. Step where the previous owners stepped.",
    "Scrap-prospectors say there's archeotech under the rubble. Scrap-prospectors say a lot of things.",
    "Come for the recaff, stay because the exits are watched.",
    "The lumen here flickers in patterns some say spell out names of the soon-to-die.",
    "Downdraft from the spire carries perfume and ash in equal measure.",
    "An old Redemptionist pyre-site. The soot never washed off the walls.",
    "Territory this good doesn't stay unclaimed. Territory this bad doesn't either.",
    "Home to a still that brews Second Best, the third best drink in the sector.",
    "The gantries groan under any weight above 'malnourished juve'.",
    "A dead zone for vox traffic. Perfect for deals best left unrecorded.",
    "They found a working servo-skull here once. It's the mayor now.",
    "Nothing grows here except debts and fungus. The fungus is more forgiving.",
    "The blast doors still work, which is more than can be said for the people who shut them.",
    "Watched over by a rusting statue of a forgotten lord-heir. The gangs use it for target practice."
  ].freeze

  QUOTES = [
    ["The Emperor protects, but a loaded stub gun helps.", "scrawled above the Sump Hole bar"],
    ["Underhive rats got three certainties: dark, debt, and the House always collecting.", "Old Mercator saying"],
    ["I've seen spire-born pay a thousand credits for 'authentic underhive grit'. We drink it for free.", "Sallow Marn, sump-farmer"],
    ["Turf ain't land. Turf is everyone who'll die for it.", "Kroza Vex, Goliath forge-boss"],
    ["The Arbitrator giveth, and the Arbitrator taketh away. Mostly taketh.", "anonymous, Dust Falls"],
    ["Never trust a Delaque's smile. Never see one, neither.", "Enforcer Provost Hale"],
    ["Down here the map is redrawn in blood every cycle. We just make it official.", "Guilder Cartographer Ottkin"],
    ["What's mine is mine. What's yours is negotiable.", "Escher queen, Cinder Wells"],
    ["The hive spire dumps its waste on us. We dump ours further down. It's a system.", "vent-scraper's proverb"],
    ["You can leave the underhive, but the underhive never leaves your lungs.", "medicae intake sign, Hope's End"],
    ["Six gangs came to Slag Gulch. One left. The rest stayed — as landmarks.", "campfire tale"],
    ["Credits spend. Bullets argue. Territory remembers.", "Orlock road-captain"]
  ].freeze

  def self.zone_name(rng = Random)
    "#{ZONE_PREFIX.sample(random: rng)} #{ZONE_SUFFIX.sample(random: rng)}"
  end

  def self.zone_description(rng = Random)
    ZONE_DESCRIPTIONS.sample(random: rng)
  end

  # Returns [name, description] pairs, unique names within a batch.
  def self.turf_batch(count, rng = Random)
    names = TURF_PREFIX.product(TURF_PLACE).sample(count, random: rng)
    descs = TURF_DESCRIPTIONS.sample(count, random: rng)
    descs += TURF_DESCRIPTIONS.sample(count - descs.size, random: rng) while descs.size < count
    names.each_with_index.map { |(pre, place), i| ["#{pre} #{place}", descs[i]] }
  end

  def self.quote(rng = Random)
    QUOTES.sample(random: rng)
  end
end
