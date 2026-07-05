extends Node2D

# Static terrain: drawn ONCE. Godot caches the draw command list, so this
# node costs nothing per frame after the first draw. Animated water lives
# on water_layer.gd. Never call queue_redraw() here after setup.

const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

var terrain_map: RefCounted = null
var arena_rect := Rect2()

func setup(next_terrain_map: RefCounted) -> void:
	terrain_map = next_terrain_map
	arena_rect = terrain_map.arena_rect
	z_index = -10
	queue_redraw()

func _draw() -> void:
	if terrain_map == null:
		return
	for layer in terrain_map.zone_layers:
		var zone := String(layer["zone"])
		for rect: Rect2 in layer["rects"]:
			draw_rect(rect, VisualGrammar.terrain_color(zone))
			_draw_zone_detail(zone, rect)
			_draw_zone_edge(zone, rect)
	_draw_perch_anchors()
	draw_rect(arena_rect, Color(0.28, 0.33, 0.24), false, 6.0)

func _draw_zone_detail(zone: String, rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(rect.position.x), int(rect.position.y)))
	match zone:
		TerrainMapScript.LAND:
			for i in int(rect.get_area() / 9000.0):
				var spot := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				var tone := rng.randf_range(-0.02, 0.03)
				draw_circle(spot, rng.randf_range(6.0, 18.0), Color(0.16 + tone, 0.2 + tone * 1.4, 0.11 + tone))
			for i in int(rect.get_area() / 26000.0):
				var tuft := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				draw_line(tuft, tuft + Vector2(-1.5, -4.0), Color(0.24, 0.32, 0.16), 1.5)
				draw_line(tuft + Vector2(2.5, 0.0), tuft + Vector2(3.5, -4.5), Color(0.22, 0.3, 0.15), 1.5)
		TerrainMapScript.SHALLOW:
			for i in int(rect.get_area() / 11000.0) + 1:
				var speck := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				draw_circle(speck, rng.randf_range(2.0, 5.0), Color(0.24, 0.38, 0.3, 0.7))
			for i in int(rect.get_area() / 18000.0) + 1:
				var ripple := Vector2(rng.randf_range(rect.position.x + 8.0, rect.end.x - 8.0), rng.randf_range(rect.position.y + 8.0, rect.end.y - 8.0))
				var width := rng.randf_range(8.0, 18.0)
				draw_line(ripple + Vector2(-width * 0.5, 0.0), ripple + Vector2(width * 0.5, 0.0), Color(0.48, 0.68, 0.56, 0.34), 1.4)
				draw_line(ripple + Vector2(-width * 0.35, 4.0), ripple + Vector2(width * 0.35, 4.0), Color(0.34, 0.5, 0.42, 0.28), 1.0)
			for i in int(rect.get_area() / 30000.0) + 1:
				var reed := Vector2(rng.randf_range(rect.position.x + 6.0, rect.end.x - 6.0), rng.randf_range(rect.position.y + 6.0, rect.end.y - 6.0))
				draw_line(reed, reed + Vector2(-1.0, -7.0), Color(0.28, 0.42, 0.2), 2.0)
				draw_line(reed + Vector2(3.0, 0.0), reed + Vector2(4.0, -6.0), Color(0.25, 0.38, 0.18), 2.0)
		TerrainMapScript.COVER:
			draw_rect(rect, Color(0.1, 0.16, 0.09))
			for i in maxi(int(rect.get_area() / 2600.0), 3):
				var bush := Vector2(rng.randf_range(rect.position.x + 8.0, rect.end.x - 8.0), rng.randf_range(rect.position.y + 8.0, rect.end.y - 8.0))
				draw_circle(bush, rng.randf_range(7.0, 13.0), Color(0.14 + rng.randf() * 0.04, 0.24 + rng.randf() * 0.05, 0.12))
				draw_circle(bush + Vector2(-2.0, -3.0), rng.randf_range(3.0, 6.0), Color(0.2, 0.32, 0.16))
			draw_rect(rect, Color(0.05, 0.09, 0.05), false, 2.0)
		TerrainMapScript.HABITAT_BLUE, TerrainMapScript.HABITAT_RED:
			var team_tint := Color(0.3, 0.55, 0.85, 0.5) if zone == TerrainMapScript.HABITAT_BLUE else Color(0.85, 0.4, 0.35, 0.5)
			draw_rect(rect, team_tint, false, 4.0)
			var post_gap := 28.0
			var x := rect.position.x
			while x <= rect.end.x:
				draw_rect(Rect2(Vector2(x - 2.0, rect.position.y - 5.0), Vector2(4.0, 8.0)), Color(0.32, 0.24, 0.14))
				draw_rect(Rect2(Vector2(x - 2.0, rect.end.y - 3.0), Vector2(4.0, 8.0)), Color(0.32, 0.24, 0.14))
				x += post_gap
			var y := rect.position.y
			while y <= rect.end.y:
				draw_rect(Rect2(Vector2(rect.position.x - 5.0, y - 2.0), Vector2(8.0, 4.0)), Color(0.32, 0.24, 0.14))
				draw_rect(Rect2(Vector2(rect.end.x - 3.0, y - 2.0), Vector2(8.0, 4.0)), Color(0.32, 0.24, 0.14))
				y += post_gap
			for i in 7:
				var patch := Vector2(rng.randf_range(rect.position.x + 12.0, rect.end.x - 12.0), rng.randf_range(rect.position.y + 12.0, rect.end.y - 12.0))
				draw_circle(patch, rng.randf_range(6.0, 12.0), Color(0.2, 0.19, 0.1, 0.55))

func _draw_zone_edge(zone: String, rect: Rect2) -> void:
	match zone:
		TerrainMapScript.WATER:
			draw_rect(rect.grow(1.0), Color(0.42, 0.68, 0.7, 0.55), false, 3.0)
			draw_rect(rect.grow(-3.0), Color(0.04, 0.16, 0.22, 0.45), false, 1.5)
		TerrainMapScript.SHALLOW:
			_draw_stippled_rect(rect.grow(-2.0), Color(0.44, 0.56, 0.42, 0.55), 18.0)
			draw_rect(rect.grow(-5.0), Color(0.32, 0.48, 0.38, 0.22), false, 1.5)
		TerrainMapScript.COVER:
			draw_rect(rect.grow(2.0), Color(0.03, 0.055, 0.03, 0.85), false, 3.0)
		TerrainMapScript.HABITAT_BLUE, TerrainMapScript.HABITAT_RED:
			var color := Color(0.38, 0.68, 1.0, 0.65) if zone == TerrainMapScript.HABITAT_BLUE else Color(1.0, 0.48, 0.38, 0.65)
			draw_rect(rect.grow(-7.0), color, false, 2.0)

func _draw_stippled_rect(rect: Rect2, color: Color, step: float) -> void:
	var x := rect.position.x
	while x <= rect.end.x:
		draw_circle(Vector2(x, rect.position.y), 1.6, color)
		draw_circle(Vector2(x, rect.end.y), 1.6, color)
		x += step
	var y := rect.position.y
	while y <= rect.end.y:
		draw_circle(Vector2(rect.position.x, y), 1.6, color)
		draw_circle(Vector2(rect.end.x, y), 1.6, color)
		y += step

func _draw_perch_anchors() -> void:
	if terrain_map == null or not terrain_map.has_method("get_perch_anchors"):
		return
	for anchor: Vector2 in terrain_map.get_perch_anchors():
		draw_circle(anchor, 5.5, Color(0.7, 0.82, 0.48, 0.16))
		draw_line(anchor + Vector2(-5.0, 0.0), anchor + Vector2(5.0, 0.0), Color(0.78, 0.92, 0.58, 0.28), 1.2)
		draw_line(anchor + Vector2(0.0, -5.0), anchor + Vector2(0.0, 5.0), Color(0.78, 0.92, 0.58, 0.28), 1.2)
