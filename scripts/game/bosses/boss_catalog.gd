extends RefCounted
## Boss reward catalog (BB-BOSS-4). Const tables transcribing BATTLE_BOG_BOSS_DESIGN.md:
## the per-family habitat-stock buff (a SEPARATE channel from the capped breeding buffs,
## Decision #8) and the enemy-side terrain-disruption event fired ONLY when the OWNER
## claims its own side boss (an enemy steal grants the buff but no disruption).
##
## Effect keys that the creature stat system already consumes -- move_speed, max_health,
## damage, ability_haste, regen -- apply mechanically now. Design-specific keys
## (swim_duration, healing_received, damage_reduction, size, hunger_depletion,
## vision_range) are stored and exposed via arena.get_team_boss_stock_effect for later
## wiring; keeping the exact design values here means that wiring is a consume-site change
## only, never a re-transcription.

const FAMILY_BUFFS := {
	"champsosaurus": {"move_speed": 0.015, "swim_duration": 0.07},
	"platyhystrix": {"regen": 0.025, "healing_received": 0.05},
	"american_mastodon": {"max_health": 0.05, "damage_reduction": 0.02},
	"arthropleura": {"hunger_depletion": -0.06, "size": 0.04},
	"teratornis": {"move_speed": 0.015, "vision_range": 0.04}
}

# Enemy-side timed terrain disruption. Fired on OWNER claim only. Must inconvenience /
# reroute / reveal for a window -- never a permanent route-lock mutation (BOSS_DESIGN).
const FAMILY_TERRAIN_EVENTS := {
	"champsosaurus": {"kind": "flood_scar", "label": "Flood Scar", "duration": 12.0, "radius": 120.0},
	"platyhystrix": {"kind": "toxic_bloom", "label": "Toxic Bloom", "duration": 12.0, "radius": 120.0},
	"american_mastodon": {"kind": "trampled_ground", "label": "Trampled Ground", "duration": 12.0, "radius": 120.0},
	"arthropleura": {"kind": "leaf_litter", "label": "Leaf Litter", "duration": 12.0, "radius": 120.0},
	"teratornis": {"kind": "wind_shear", "label": "Wind Shear", "duration": 12.0, "radius": 120.0}
}

static func family_buff(family: String) -> Dictionary:
	return FAMILY_BUFFS.get(family, {})

static func family_terrain_event(family: String) -> Dictionary:
	return FAMILY_TERRAIN_EVENTS.get(family, {})
