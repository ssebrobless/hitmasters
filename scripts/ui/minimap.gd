extends Control

const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

const MAP_WIDTH := 232.0

var arena: Node = null
var redraw_accumulator := 0.0

func _process(delta: float) -> void:
	# 8 Hz is plenty for a minimap.
	redraw_accumulator += delta
	if redraw_accumulator >= 0.125:
		redraw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	if arena == null or not is_instance_valid(arena):
		return
	var world: Rect2 = arena.arena_rect
	if world.size.x <= 0.0:
		return
	var map_scale := MAP_WIDTH / world.size.x
	var map_size := world.size * map_scale
	draw_rect(Rect2(Vector2.ZERO, map_size).grow(3.0), Color(0.03, 0.04, 0.03, 0.9))
	for layer in arena.terrain_map.zone_layers:
		var zone := String(layer["zone"])
		for rect: Rect2 in layer["rects"]:
			var mini := Rect2((rect.position - world.position) * map_scale, rect.size * map_scale)
			draw_rect(mini, _zone_color(zone))

	for core_team in arena.cores.keys():
		var core = arena.cores[core_team]
		if core != null and is_instance_valid(core):
			var core_point: Vector2 = (core.global_position - world.position) * map_scale
			draw_rect(Rect2(core_point - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), _team_color(core.team))

	for entity in arena.entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		var point: Vector2 = (entity.global_position - world.position) * map_scale
		var is_actor: bool = entity.has_method("is_scored_actor") and entity.is_scored_actor()
		draw_circle(point, 2.5 if is_actor else 1.5, _team_color(entity.team))

	if arena.player != null and is_instance_valid(arena.player):
		var player_point: Vector2 = (arena.player.global_position - world.position) * map_scale
		draw_arc(player_point, 4.0, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, 0.95), 1.5)
		var viewport_world: Vector2 = get_viewport_rect().size / arena.camera_zoom
		var view_rect := Rect2((arena.player.global_position - viewport_world * 0.5 - world.position) * map_scale, viewport_world * map_scale)
		draw_rect(view_rect.intersection(Rect2(Vector2.ZERO, map_size)), Color(1.0, 1.0, 1.0, 0.35), false, 1.0)

	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.5, 0.55, 0.45, 0.7), false, 1.5)

func _zone_color(zone: String) -> Color:
	match zone:
		TerrainMapScript.WATER:
			return Color(0.12, 0.3, 0.4)
		TerrainMapScript.SHALLOW:
			return Color(0.18, 0.33, 0.28)
		TerrainMapScript.COVER:
			return Color(0.1, 0.18, 0.1)
		TerrainMapScript.HABITAT_BLUE:
			return Color(0.14, 0.22, 0.32)
		TerrainMapScript.HABITAT_RED:
			return Color(0.3, 0.15, 0.13)
		_:
			return Color(0.16, 0.2, 0.11)

func _team_color(team: int) -> Color:
	return Color(0.35, 0.7, 1.0) if team == 0 else Color(1.0, 0.4, 0.35)
