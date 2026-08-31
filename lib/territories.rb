# frozen_string_literal: true

# Dominion Campaign territory types.
# Source: Necromunda Core Rulebook (2023) — the "N26" ruleset — as
# transcribed by necrovox.org / necroraw.com.ru. The 26 territories form two
# card suits; every gang holds a Settlement as its unlosable home territory.
module Territories
  HOME = "Settlement"

  ALL = {
    "Settlement" => {
      boons: {
        income: "D6×10 credits",
        reputation: "+1",
        recruit: "After each battle roll 2D6: any 6 = free Juve, double 6 = free Ganger"
      },
      note: "Starting territory — cannot be lost or staked"
    },
    "Old Ruins" => {
      boons: { income: "D3×10 credits (+1 per attached Dome Runner)" }
    },
    "Rogue Doc Shop" => {
      boons: {
        income: "D6×10 credits (Outlaw gangs)",
        recruit: "Free Rogue Doc Hanger-on (Law-abiding gangs)"
      }
    },
    "Promethium Cache" => {
      boons: {
        equipment: "3 fighters gain free incendiary charges",
        special: "Re-roll Ammo tests for Blaze weapons"
      }
    },
    "Wastes" => {
      boons: { special: "Choose the stake when challenged (Occupation); Leader Int test to Ambush as attacker (Takeover)" }
    },
    "Sludge Sea" => {
      boons: { equipment: "3 fighters gain free choke gas grenades" }
    },
    "Workshop" => {
      boons: {
        income: "D6×10 credits (Outlaw gangs)",
        recruit: "Free Ammo-jack Hanger-on (Law-abiding gangs)"
      }
    },
    "Collapsed Dome" => {
      boons: { income: "Roll 2D6×10 up to 6D6×10 — any double: nothing, and a random fighter suffers a Lasting Injury" }
    },
    "Refuse Drift" => {
      boons: { income: "2D6×5 credits — on a double, a random fighter misses the next battle" },
      enhanced: { house: "House Cawdor", boon: "Rep +1; income without the waste-lurker risk" }
    },
    "Corpse Farm" => {
      boons: { income: "D6×10 credits per fighter deleted from any roster last battle" },
      enhanced: { house: "House Cawdor", boon: "Rep +1; 2D6×10 credits per deleted fighter" }
    },
    "Bone Shrine" => {
      boons: { income: "2D6×5 credits" },
      enhanced: { house: "House Cawdor", boon: "Rep +2; 4D6×5 credits" }
    },
    "Drinking Hole" => {
      boons: {
        reputation: "+1",
        special: "Fighters may re-roll failed Cool tests (then −1 to hit for the battle)"
      },
      enhanced: { house: "House Delaque", boon: "Rep +2; 3 enemy fighters start Intoxicated" }
    },
    "Gambling Den" => {
      boons: {
        reputation: "+1",
        income: "Draw a card: matching suit = value×10, same colour = value×5, Joker = forfeit income to a rival"
      },
      enhanced: { house: "House Delaque", boon: "Rep +2; one enemy fighter misses the battle" }
    },
    "Needle Ways" => {
      boons: { special: "Up to 3 fighters gain Infiltrate" },
      enhanced: { house: "House Delaque", boon: "Up to 6 fighters gain Infiltrate" }
    },
    "Synth Still" => {
      boons: { special: "Chem-synths, medicae kits, stimm-slug stashes and Gas/Toxin weapons become Common" },
      enhanced: { house: "House Escher", boon: "Rep +1; those items also half price" }
    },
    "Stinger Mould Sprawl" => {
      boons: { special: "Once per post-battle sequence, re-roll one Lasting Injury" },
      enhanced: { house: "House Escher", boon: "Rep +1; remove a Lasting Injury, or re-roll incl. Memorable Death" }
    },
    "Narco Den" => {
      boons: { income: "D6×5 credits" },
      enhanced: { house: "House Escher", boon: "Rep +1; 2D6×5 credits (2D6×10 with a Synth Still)" }
    },
    "Slag Furnace" => {
      boons: { income: "D6×5 credits" },
      enhanced: { house: "House Goliath", boon: "Rep +2; free recruit rolls after every battle" }
    },
    "Fighting Pit" => {
      boons: { recruit: "2 free Hive Scum before every battle" },
      enhanced: { house: "House Goliath", boon: "Rep +2" }
    },
    "Smelting Works" => {
      boons: { income: "D6×5 credits" },
      enhanced: { house: "House Goliath", boon: "2D6×5 credits (2D6×10 with a Slag Furnace)" }
    },
    "Mine Workings" => {
      boons: { income: "D6×10 credits; work Captives for an extra D6×10 each" },
      enhanced: { house: "House Orlock", boon: "Rep +2" }
    },
    "Tunnels" => {
      boons: { special: "Up to 3 fighters may deploy via tunnels" },
      enhanced: { house: "House Orlock", boon: "Rep +1; up to 6 fighters via tunnels" }
    },
    "Toll Crossing" => {
      boons: { income: "D6×5 credits" },
      enhanced: { house: "House Orlock", boon: "Priority in round 1 of every battle" }
    },
    "Generatorium" => {
      boons: { special: "Once per Priority phase declare a power cut — Pitch Black rules apply" },
      enhanced: { house: "House Van Saar", boon: "Rep +1" }
    },
    "Archaeotech Device" => {
      boons: { special: "Weapons may gain Blaze, Rad-phage, Seismic or Shock (plus Unstable)" },
      enhanced: { house: "House Van Saar", boon: "Rep +2; weapons gain two traits" }
    },
    "Tech Bazaar" => {
      boons: {
        income: "D6×10 credits",
        equipment: "Leader/Champion may Haggle for half-price gear"
      },
      enhanced: { house: "House Van Saar", boon: "Rep +1; D6×10 (2D6×10 with an Archaeotech Device)" }
    }
  }.freeze

  # Territory pool for map generation: every type except the Settlement,
  # which is reserved as each gang's home territory.
  POOL = (ALL.keys - [HOME]).freeze

  module_function

  # Deals `count` territory types, shuffling the pool like the Dominion card
  # deck and reshuffling if the map needs more cards than the deck holds.
  def deal(count, rng = Random)
    deck = []
    deck.concat(POOL.shuffle(random: rng)) while deck.size < count
    deck.first(count)
  end

  # Short display lines for a territory's boons, e.g. "Income: D6×10 credits".
  def boon_lines(name)
    info = ALL[name]
    return [] unless info

    lines = info[:boons].map { |kind, text| "#{kind.to_s.capitalize}: #{text}" }
    lines << "Note: #{info[:note]}" if info[:note]
    lines << "Enhanced (#{info[:enhanced][:house]}): #{info[:enhanced][:boon]}" if info[:enhanced]
    lines
  end
end
