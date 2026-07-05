extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const EnvironmentProfileScript := preload("res://scripts/sim/environment_profile.gd")

func _initialize() -> void:
	var terrain := TerrainMapScript.new()
	terrain.configure("3v3")
	var unit := SimConstants.UNIT_PX
	var arena_units := terrain.arena_rect.size / unit
	var blue_habitat: Rect2 = terrain.get_team_habitat_rect(0)
	var red_habitat: Rect2 = terrain.get_team_habitat_rect(1)
	var cores_in_habitat := blue_habitat.has_point(terrain.blue_core_position) and red_habitat.has_point(terrain.red_core_position)
	var center_zone := terrain.get_zone_at(Vector2.ZERO)
	var shallow_zone := terrain.get_zone_at(Vector2(12.0 * unit, -13.0 * unit))
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

	terrain.configure("1v1")
	var duel_units := terrain.arena_rect.size / unit
	var duel_anchor_count := terrain.get_perch_anchors().size()

	var passed: bool = arena_units == Vector2(240.0, 135.0) and duel_units == Vector2(150.0, 84.0) and cores_in_habitat and center_zone == TerrainMapScript.WATER and shallow_zone == TerrainMapScript.SHALLOW and profiles_ok and anchors_ok and duel_anchor_count == terrain.get_cover_rects().size()
	print("terrain_3v3_units=%sx%s terrain_1v1_units=%sx%s cores_in_habitat=%s center=%s shallow=%s profiles_ok=%s anchors_ok=%s duel_anchor_count=%d" % [
		str(arena_units.x),
		str(arena_units.y),
		str(duel_units.x),
		str(duel_units.y),
		str(cores_in_habitat),
		center_zone,
		shallow_zone,
		str(profiles_ok),
		str(anchors_ok),
		duel_anchor_count
	])
	quit(0 if passed else 1)
