extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")

const LAND := "land"
const SHALLOW := "shallow"
const WATER := "water"
const COVER := "cover"
const HABITAT_BLUE := "habitat_blue"
const HABITAT_RED := "habitat_red"

var mode := "3v3"
var zone_layers: Array[Dictionary] = []
var arena_rect := Rect2()
var blue_core_position := Vector2.ZERO
var red_core_position := Vector2.ZERO
var blue_minion_spawn := Vector2.ZERO
var red_minion_spawn := Vector2.ZERO
var team_spawns := {}
var bot_spawns := {}
var wave_minion_offsets: Array[Vector2] = []
var objective_position := Vector2.ZERO
var objective_radius := 0.0

func configure(next_mode: String) -> void:
	mode = next_mode
	if mode == "1v1" or mode == "Hero Lab":
		_configure_1v1()
	else:
		_configure_3v3()

func get_zone_at(point: Vector2) -> String:
	for i in range(zone_layers.size() - 1, -1, -1):
		var layer := zone_layers[i]
		for rect: Rect2 in layer["rects"]:
			if rect.has_point(point):
				return String(layer["zone"])
	return LAND

func get_rects(zone: String) -> Array:
	for layer in zone_layers:
		if String(layer["zone"]) == zone:
			return layer["rects"].duplicate()
	return []

func get_cover_rects() -> Array:
	return get_rects(COVER)

func get_team_habitat_rect(team: int) -> Rect2:
	var habitat_zone := HABITAT_BLUE if team == 0 else HABITAT_RED
	var rects := get_rects(habitat_zone)
	return rects[0] if not rects.is_empty() else Rect2()

func _configure_3v3() -> void:
	var unit := SimConstants.UNIT_PX
	arena_rect = _rect_units(-120.0, -67.5, 240.0, 135.0)
	zone_layers = [
		{"zone": LAND, "rects": [arena_rect]},
		{"zone": SHALLOW, "rects": [
			_rect_units(-17.0, -67.5, 8.0, 135.0),
			_rect_units(9.0, -67.5, 8.0, 135.0),
			_rect_units(-82.0, -62.0, 28.0, 22.0),
			_rect_units(54.0, 40.0, 28.0, 22.0)
		]},
		{"zone": WATER, "rects": [
			_rect_units(-9.0, -67.5, 18.0, 135.0),
			_rect_units(-78.0, -58.0, 20.0, 14.0),
			_rect_units(58.0, 44.0, 20.0, 14.0)
		]},
		{"zone": HABITAT_BLUE, "rects": [
			_rect_units(-117.0, -19.0, 30.0, 38.0)
		]},
		{"zone": HABITAT_RED, "rects": [
			_rect_units(87.0, -19.0, 30.0, 38.0)
		]},
		{"zone": COVER, "rects": [
			_rect_units(-92.0, -48.0, 9.0, 7.0),
			_rect_units(83.0, 41.0, 9.0, 7.0),
			_rect_units(-92.0, 40.0, 9.0, 7.0),
			_rect_units(83.0, -47.0, 9.0, 7.0),
			_rect_units(-60.0, -26.0, 8.0, 6.0),
			_rect_units(52.0, 20.0, 8.0, 6.0),
			_rect_units(-60.0, 20.0, 8.0, 6.0),
			_rect_units(52.0, -26.0, 8.0, 6.0),
			_rect_units(-38.0, -56.0, 10.0, 7.0),
			_rect_units(28.0, 49.0, 10.0, 7.0),
			_rect_units(-38.0, 49.0, 10.0, 7.0),
			_rect_units(28.0, -56.0, 10.0, 7.0),
			_rect_units(-26.0, -8.0, 6.0, 16.0),
			_rect_units(20.0, -8.0, 6.0, 16.0)
		]}
	]
	blue_core_position = Vector2(-103.0 * unit, 0.0)
	red_core_position = Vector2(103.0 * unit, 0.0)
	blue_minion_spawn = Vector2(-84.0 * unit, 0.0)
	red_minion_spawn = Vector2(84.0 * unit, 0.0)
	team_spawns = {
		0: Vector2(-98.0 * unit, 10.0 * unit),
		1: Vector2(98.0 * unit, -10.0 * unit)
	}
	bot_spawns = {
		"Blue Guard": Vector2(-100.0 * unit, -11.0 * unit),
		"Blue Ward": Vector2(-106.0 * unit, 6.0 * unit),
		"Red Blade": Vector2(100.0 * unit, -11.0 * unit),
		"Red Scope": Vector2(106.0 * unit, 6.0 * unit),
		"Red Chorus": Vector2(100.0 * unit, 11.0 * unit),
		"Red Rival": Vector2(100.0 * unit, -11.0 * unit)
	}
	wave_minion_offsets = [Vector2(0.0, -4.0 * unit), Vector2.ZERO, Vector2(0.0, 4.0 * unit)]
	objective_position = Vector2.ZERO
	objective_radius = 7.0 * unit

func _configure_1v1() -> void:
	var unit := SimConstants.UNIT_PX
	arena_rect = _rect_units(-75.0, -42.0, 150.0, 84.0)
	zone_layers = [
		{"zone": LAND, "rects": [arena_rect]},
		{"zone": SHALLOW, "rects": [
			_rect_units(-12.0, -42.0, 6.0, 84.0),
			_rect_units(6.0, -42.0, 6.0, 84.0)
		]},
		{"zone": WATER, "rects": [
			_rect_units(-6.0, -42.0, 12.0, 84.0)
		]},
		{"zone": HABITAT_BLUE, "rects": [
			_rect_units(-73.0, -13.0, 20.0, 26.0)
		]},
		{"zone": HABITAT_RED, "rects": [
			_rect_units(53.0, -13.0, 20.0, 26.0)
		]},
		{"zone": COVER, "rects": [
			_rect_units(-52.0, -30.0, 8.0, 6.0),
			_rect_units(44.0, 24.0, 8.0, 6.0),
			_rect_units(-52.0, 24.0, 8.0, 6.0),
			_rect_units(44.0, -30.0, 8.0, 6.0),
			_rect_units(-20.0, -6.0, 5.0, 12.0),
			_rect_units(15.0, -6.0, 5.0, 12.0)
		]}
	]
	blue_core_position = Vector2(-62.0 * unit, 0.0)
	red_core_position = Vector2(62.0 * unit, 0.0)
	blue_minion_spawn = Vector2(-48.0 * unit, 0.0)
	red_minion_spawn = Vector2(48.0 * unit, 0.0)
	team_spawns = {
		0: Vector2(-58.0 * unit, 7.0 * unit),
		1: Vector2(58.0 * unit, -7.0 * unit)
	}
	bot_spawns = {
		"Red Rival": Vector2(58.0 * unit, -7.0 * unit)
	}
	wave_minion_offsets = [Vector2(0.0, -3.0 * unit), Vector2(0.0, 3.0 * unit)]
	objective_position = Vector2.ZERO
	objective_radius = 5.0 * unit

func _rect_units(x: float, y: float, width: float, height: float) -> Rect2:
	var unit := SimConstants.UNIT_PX
	return Rect2(Vector2(x * unit, y * unit), Vector2(width * unit, height * unit))
