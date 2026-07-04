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
	arena_rect = _rect_units(-40.0, -22.5, 80.0, 45.0)
	zone_layers = [
		{"zone": LAND, "rects": [arena_rect]},
		{"zone": SHALLOW, "rects": [
			_rect_units(-15.5, -16.5, 31.0, 6.5),
			_rect_units(-15.5, 10.0, 31.0, 6.5)
		]},
		{"zone": WATER, "rects": [
			_rect_units(-5.5, -22.5, 11.0, 45.0)
		]},
		{"zone": HABITAT_BLUE, "rects": [
			_rect_units(-39.0, -11.0, 12.0, 22.0)
		]},
		{"zone": HABITAT_RED, "rects": [
			_rect_units(27.0, -11.0, 12.0, 22.0)
		]},
		{"zone": COVER, "rects": [
			_rect_units(-22.0, -18.0, 6.0, 5.0),
			_rect_units(-22.0, 13.0, 6.0, 5.0),
			_rect_units(16.0, -18.0, 6.0, 5.0),
			_rect_units(16.0, 13.0, 6.0, 5.0),
			_rect_units(-3.0, -4.0, 2.5, 8.0),
			_rect_units(0.5, -4.0, 2.5, 8.0)
		]}
	]
	blue_core_position = Vector2(-33.0 * unit, 0.0)
	red_core_position = Vector2(33.0 * unit, 0.0)
	blue_minion_spawn = Vector2(-25.0 * unit, 0.0)
	red_minion_spawn = Vector2(25.0 * unit, 0.0)
	team_spawns = {
		0: Vector2(-30.5 * unit, 6.0 * unit),
		1: Vector2(30.5 * unit, -6.0 * unit)
	}
	bot_spawns = {
		"Blue Guard": Vector2(-31.0 * unit, -7.0 * unit),
		"Blue Ward": Vector2(-35.0 * unit, 4.0 * unit),
		"Red Blade": Vector2(31.0 * unit, -7.0 * unit),
		"Red Scope": Vector2(35.0 * unit, 4.0 * unit),
		"Red Chorus": Vector2(31.0 * unit, 7.0 * unit),
		"Red Rival": Vector2(31.0 * unit, -7.0 * unit)
	}
	wave_minion_offsets = [Vector2(0.0, -3.0 * unit), Vector2.ZERO, Vector2(0.0, 3.0 * unit)]
	objective_position = Vector2.ZERO
	objective_radius = 5.5 * unit

func _configure_1v1() -> void:
	var unit := SimConstants.UNIT_PX
	arena_rect = _rect_units(-27.5, -15.0, 55.0, 30.0)
	zone_layers = [
		{"zone": LAND, "rects": [arena_rect]},
		{"zone": SHALLOW, "rects": [
			_rect_units(-10.0, -11.0, 20.0, 4.5),
			_rect_units(-10.0, 6.5, 20.0, 4.5)
		]},
		{"zone": WATER, "rects": [
			_rect_units(-3.75, -15.0, 7.5, 30.0)
		]},
		{"zone": HABITAT_BLUE, "rects": [
			_rect_units(-26.5, -7.5, 8.5, 15.0)
		]},
		{"zone": HABITAT_RED, "rects": [
			_rect_units(18.0, -7.5, 8.5, 15.0)
		]},
		{"zone": COVER, "rects": [
			_rect_units(-15.0, -11.0, 4.5, 4.0),
			_rect_units(-15.0, 7.0, 4.5, 4.0),
			_rect_units(10.5, -11.0, 4.5, 4.0),
			_rect_units(10.5, 7.0, 4.5, 4.0),
			_rect_units(-1.5, -3.0, 3.0, 6.0)
		]}
	]
	blue_core_position = Vector2(-22.0 * unit, 0.0)
	red_core_position = Vector2(22.0 * unit, 0.0)
	blue_minion_spawn = Vector2(-16.5 * unit, 0.0)
	red_minion_spawn = Vector2(16.5 * unit, 0.0)
	team_spawns = {
		0: Vector2(-20.0 * unit, 4.0 * unit),
		1: Vector2(20.0 * unit, -4.0 * unit)
	}
	bot_spawns = {
		"Red Rival": Vector2(20.0 * unit, -4.0 * unit)
	}
	wave_minion_offsets = [Vector2(0.0, -2.25 * unit), Vector2(0.0, 2.25 * unit)]
	objective_position = Vector2.ZERO
	objective_radius = 4.0 * unit

func _rect_units(x: float, y: float, width: float, height: float) -> Rect2:
	var unit := SimConstants.UNIT_PX
	return Rect2(Vector2(x * unit, y * unit), Vector2(width * unit, height * unit))
