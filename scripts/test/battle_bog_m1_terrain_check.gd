extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const EnvironmentProfileScript := preload("res://scripts/sim/environment_profile.gd")

func _initialize() -> void:
	var terrain := TerrainMapScript.new()
	terrain.configure("3v3")
	var unit := SimConstants.UNIT_PX
	var arena_units := terrain.arena_rect.size / unit
	var arena_origin_units := terrain.arena_rect.position / unit
	var blue_habitat: Rect2 = terrain.get_team_habitat_rect(0)
	var red_habitat: Rect2 = terrain.get_team_habitat_rect(1)
	var blue_habitat_units := Rect2(blue_habitat.position / unit, blue_habitat.size / unit)
	var red_habitat_units := Rect2(red_habitat.position / unit, red_habitat.size / unit)
	var habitats_ok: bool = blue_habitat_units.position == Vector2(-240.0, -40.0) \
		and blue_habitat_units.size == Vector2(40.0, 80.0) \
		and red_habitat_units.position == Vector2(200.0, -40.0) \
		and red_habitat_units.size == Vector2(40.0, 80.0)
	var cores_in_habitat := blue_habitat.has_point(terrain.blue_core_position) and red_habitat.has_point(terrain.red_core_position)
	var core_positions_ok: bool = terrain.blue_core_position / unit == Vector2(-223.0, 0.0) \
		and terrain.red_core_position / unit == Vector2(223.0, 0.0) \
		and terrain.team_spawns[0] / unit == Vector2(-218.0, 10.0) \
		and terrain.team_spawns[1] / unit == Vector2(218.0, -10.0)
	var center_zone := terrain.get_zone_at(Vector2.ZERO)
	var shallow_zone := terrain.get_zone_at(Vector2(16.0 * unit, 0.0))
	var upper_bridge_zone := terrain.get_zone_at(Vector2(0.0, -42.0 * unit))
	var lower_bridge_zone := terrain.get_zone_at(Vector2(0.0, 55.0 * unit))
	var shallow_land_profile := terrain.get_environment_profile_for_zone(TerrainMapScript.SHALLOW, ["land_walker"])
	var shallow_comfort_profile := terrain.get_environment_profile_for_zone(TerrainMapScript.SHALLOW, ["semi_aquatic"])
	var deep_land_profile := EnvironmentProfileScript.for_zone(TerrainMapScript.WATER, ["land_walker"])
	var habitat_profile := terrain.get_environment_profile_for_zone(TerrainMapScript.HABITAT_BLUE)
	var cover_rects := terrain.get_cover_rects()
	var perch_anchors := terrain.get_perch_anchors()
	var first_anchor: Vector2 = perch_anchors[0] if not perch_anchors.is_empty() else Vector2(1.0e20, 1.0e20)
	var nearest_first_anchor: Variant = terrain.get_nearest_perch_anchor(first_anchor)
	var far_anchor: Variant = terrain.get_nearest_perch_anchor(terrain.arena_rect.position)
	var anchors_ok: bool = perch_anchors.size() == cover_rects.size() \
		and not perch_anchors.is_empty() \
		and cover_rects[0].has_point(first_anchor) \
		and typeof(nearest_first_anchor) == TYPE_VECTOR2 \
		and far_anchor == null
	var deep_land_dragged: bool = bool(deep_land_profile["wrong_terrain_now"]) \
		and absf(float(deep_land_profile["speed_mult"]) - EnvironmentProfileScript.DEEP_WATER_LAND_DRAG_MULTIPLIER) < 0.001
	var profiles_ok: bool = float(shallow_land_profile["speed_mult"]) < 1.0 \
		and float(shallow_comfort_profile["speed_mult"]) > 1.0 \
		and deep_land_dragged \
		and String(habitat_profile["danger"]) == EnvironmentProfileScript.DANGER_SAFE
	var animal_zones_ok: bool = _animal_zones_ok(terrain.get_animal_zones())
	var food_resources_ok: bool = _food_resources_ok(terrain.get_food_spawn_points())

	terrain.configure("1v1")
	var duel_units := terrain.arena_rect.size / unit
	var duel_origin_units := terrain.arena_rect.position / unit
	var duel_anchor_count := terrain.get_perch_anchors().size()

	var shared_bounds_ok: bool = arena_units == Vector2(480.0, 170.0) \
		and arena_origin_units == Vector2(-240.0, -85.0) \
		and duel_units == Vector2(480.0, 170.0) \
		and duel_origin_units == Vector2(-240.0, -85.0)
	var bridges_ok: bool = upper_bridge_zone == TerrainMapScript.LAND and lower_bridge_zone == TerrainMapScript.LAND
	var passed: bool = shared_bounds_ok and habitats_ok and core_positions_ok and cores_in_habitat and center_zone == TerrainMapScript.WATER and shallow_zone == TerrainMapScript.SHALLOW and bridges_ok and profiles_ok and anchors_ok and animal_zones_ok and food_resources_ok and duel_anchor_count == terrain.get_cover_rects().size()
	print("terrain_3v3_units=%sx%s terrain_1v1_units=%sx%s habitats=%s cores=%s center=%s shallow=%s bridges=%s profiles_ok=%s anchors_ok=%s zones=%s food=%s duel_anchor_count=%d" % [
		str(arena_units.x),
		str(arena_units.y),
		str(duel_units.x),
		str(duel_units.y),
		str(habitats_ok),
		str(cores_in_habitat and core_positions_ok),
		center_zone,
		shallow_zone,
		str(bridges_ok),
		str(profiles_ok),
		str(anchors_ok),
		str(animal_zones_ok),
		str(food_resources_ok),
		duel_anchor_count
	])
	quit(0 if passed else 1)

func _animal_zones_ok(zones: Array) -> bool:
	if zones.size() != 10:
		return false
	var blue_boss_ok := false
	var red_boss_ok := false
	for zone in zones:
		if String(zone.get("group", "")) != "Boss":
			continue
		var center_units: Vector2 = zone.get("center_units", Vector2.ZERO)
		var activation_count := int(zone.get("breed_activation_count", 0))
		if String(zone.get("side", "")) == "blue":
			blue_boss_ok = center_units == Vector2(-48.0, 18.0) and activation_count == 5
		elif String(zone.get("side", "")) == "red":
			red_boss_ok = center_units == Vector2(48.0, 18.0) and activation_count == 5
	return blue_boss_ok and red_boss_ok

func _food_resources_ok(food_entries: Array) -> bool:
	var counts := {}
	var critter_count := 0
	for entry in food_entries:
		if String(entry.get("kind", "")) != "plant":
			if String(entry.get("kind", "")) == "critter":
				critter_count += 1
			continue
		var side := String(entry.get("side", ""))
		var plant_type := String(entry.get("plant_type", ""))
		if not ["blue", "red"].has(side) or not ["berry", "tree", "seed", "flower"].has(plant_type):
			return false
		var count_key := "%s:%s" % [side, plant_type]
		counts[count_key] = int(counts.get(count_key, 0)) + 1
		var expected_hits := 3 if plant_type == "tree" else 1
		if int(entry.get("harvest_hits", 0)) != expected_hits:
			return false
	for side in ["blue", "red"]:
		for plant_type in ["berry", "tree", "seed", "flower"]:
			var count_key := "%s:%s" % [side, plant_type]
			if int(counts.get(count_key, 0)) != 10:
				return false
	return critter_count >= 2
