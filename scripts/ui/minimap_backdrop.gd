extends Control

const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

const MAP_WIDTH := 232.0

var arena: Node = null

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
			draw_rect(mini, VisualGrammar.terrain_color(zone, 1.0, true))
	_draw_bridge_overlays(world, map_scale)

func _draw_bridge_overlays(world: Rect2, map_scale: float) -> void:
	if arena.terrain_map == null or not arena.terrain_map.has_method("get_land_bridge_rects"):
		return
	for rect: Rect2 in arena.terrain_map.get_land_bridge_rects():
		var mini := Rect2((rect.position - world.position) * map_scale, rect.size * map_scale)
		draw_rect(mini.grow(1.0), Color(0.08, 0.08, 0.04, 0.48))
		draw_rect(mini, Color(0.48, 0.42, 0.24, 0.72))
