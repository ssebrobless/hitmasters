extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

func _initialize() -> void:
	var terrain := TerrainMapScript.new()
	terrain.configure("3v3")
	var unit := SimConstants.UNIT_PX
	var arena_units := terrain.arena_rect.size / unit
	var blue_habitat: Rect2 = terrain.get_team_habitat_rect(0)
	var red_habitat: Rect2 = terrain.get_team_habitat_rect(1)
	var cores_in_habitat := blue_habitat.has_point(terrain.blue_core_position) and red_habitat.has_point(terrain.red_core_position)
	var center_zone := terrain.get_zone_at(Vector2.ZERO)
	var shallow_zone := terrain.get_zone_at(Vector2(8.0 * unit, -13.0 * unit))

	terrain.configure("1v1")
	var duel_units := terrain.arena_rect.size / unit

	var passed := arena_units == Vector2(80.0, 45.0) and duel_units == Vector2(55.0, 30.0) and cores_in_habitat and center_zone == TerrainMapScript.WATER and shallow_zone == TerrainMapScript.SHALLOW
	print("terrain_3v3_units=%sx%s terrain_1v1_units=%sx%s cores_in_habitat=%s center=%s shallow=%s" % [
		str(arena_units.x),
		str(arena_units.y),
		str(duel_units.x),
		str(duel_units.y),
		str(cores_in_habitat),
		center_zone,
		shallow_zone
	])
	quit(0 if passed else 1)
