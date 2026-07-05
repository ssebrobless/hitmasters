extends RefCounted

const LAND := "land"
const SHALLOW := "shallow"
const WATER := "water"
const COVER := "cover"
const HABITAT_BLUE := "habitat_blue"
const HABITAT_RED := "habitat_red"

const SURFACE_SOLID := "solid"
const SURFACE_MUD := "mud"
const SURFACE_WATER := "water"
const SURFACE_COVER := "cover"
const SURFACE_HABITAT := "habitat"

const DANGER_SAFE := "safe"
const DANGER_TRANSITION := "transition"
const DANGER_SWIM_PRESSURE := "swim_pressure"
const DANGER_WRONG_TERRAIN := "wrong_terrain"

const SHALLOW_LAND_SPEED_MULTIPLIER := 0.92
const SHALLOW_COMFORT_SPEED_MULTIPLIER := 1.04
const DEEP_WATER_SPEED_MULTIPLIER := 1.15
const DEEP_WATER_LAND_DRAG_MULTIPLIER := 0.62
const COVER_SPEED_MULTIPLIER := 0.95

static func for_zone(zone: String, movement_tags: Array = [], swim_time_remaining := -1.0) -> Dictionary:
	var profile := {
		"zone": zone,
		"surface": SURFACE_SOLID,
		"speed_mult": 1.0,
		"danger": DANGER_SAFE,
		"drains_swim": false,
		"restores_swim": true,
		"wrong_terrain_now": false,
		"wrong_terrain_if_swim_empty": false,
		"preferred_by": [],
		"fx_key": "land"
	}

	match zone:
		SHALLOW:
			profile["surface"] = SURFACE_MUD
			profile["speed_mult"] = _shallow_speed_multiplier(movement_tags)
			profile["danger"] = DANGER_TRANSITION
			profile["preferred_by"] = ["semi_aquatic", "wading", "paddling"]
			profile["fx_key"] = "shallow_drag"
		WATER:
			var wrong_now := _is_deep_water_wrong_now(movement_tags, swim_time_remaining)
			profile["surface"] = SURFACE_WATER
			profile["speed_mult"] = _deep_water_speed_multiplier(movement_tags, wrong_now)
			profile["drains_swim"] = has_limited_swim_time(movement_tags)
			profile["restores_swim"] = false
			profile["wrong_terrain_if_swim_empty"] = movement_tags.has("semi_aquatic")
			profile["wrong_terrain_now"] = wrong_now
			profile["danger"] = DANGER_WRONG_TERRAIN if bool(profile["wrong_terrain_now"]) else DANGER_SWIM_PRESSURE
			profile["preferred_by"] = ["aquatic", "semi_aquatic", "paddling", "wading"]
			profile["fx_key"] = "deep_water"
		COVER:
			profile["surface"] = SURFACE_COVER
			profile["speed_mult"] = COVER_SPEED_MULTIPLIER
			profile["danger"] = DANGER_TRANSITION
			profile["restores_swim"] = true
			profile["preferred_by"] = ["perch", "ambush"]
			profile["fx_key"] = "brush"
		HABITAT_BLUE, HABITAT_RED:
			profile["surface"] = SURFACE_HABITAT
			profile["danger"] = DANGER_SAFE
			profile["preferred_by"] = ["home"]
			profile["fx_key"] = "habitat"
		_:
			pass

	return profile

static func has_water_affinity(movement_tags: Array) -> bool:
	return _has_any_tag(movement_tags, ["aquatic", "semi_aquatic", "wading", "paddling"])

static func has_deep_water_speed_bonus(movement_tags: Array) -> bool:
	return _has_any_tag(movement_tags, ["aquatic", "semi_aquatic"])

static func uses_swim_speed_in_deep_water(movement_tags: Array) -> bool:
	return has_water_affinity(movement_tags)

static func has_limited_swim_time(movement_tags: Array) -> bool:
	return movement_tags.has("semi_aquatic")

static func is_deep_water_safe(movement_tags: Array, swim_time_remaining: float) -> bool:
	return not _is_deep_water_wrong_now(movement_tags, swim_time_remaining)

static func _shallow_speed_multiplier(movement_tags: Array) -> float:
	if has_water_affinity(movement_tags):
		return SHALLOW_COMFORT_SPEED_MULTIPLIER
	return SHALLOW_LAND_SPEED_MULTIPLIER

static func _deep_water_speed_multiplier(movement_tags: Array, wrong_now: bool) -> float:
	if has_deep_water_speed_bonus(movement_tags):
		return DEEP_WATER_SPEED_MULTIPLIER
	if wrong_now:
		return DEEP_WATER_LAND_DRAG_MULTIPLIER
	return 1.0

static func _is_deep_water_wrong_now(movement_tags: Array, swim_time_remaining: float) -> bool:
	if _has_any_tag(movement_tags, ["aquatic", "paddling", "wading"]):
		return false
	if movement_tags.has("semi_aquatic"):
		return swim_time_remaining >= 0.0 and swim_time_remaining <= 0.0
	return true

static func _has_any_tag(movement_tags: Array, wanted: Array) -> bool:
	for tag in wanted:
		if movement_tags.has(tag):
			return true
	return false
