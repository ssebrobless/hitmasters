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

func is_static_cached_layer() -> bool:
	return terrain_map != null and z_index == -10

func _draw() -> void:
	if terrain_map == null:
		return
	for layer in terrain_map.zone_layers:
		var zone := String(layer["zone"])
		for rect: Rect2 in layer["rects"]:
			draw_rect(rect, VisualGrammar.terrain_color(zone))
			_draw_zone_detail(zone, rect)
			_draw_zone_edge(zone, rect)
	_draw_land_bridges()
	_draw_environmental_obstacles()
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
				draw_circle(spot, rng.randf_range(6.0, 18.0), Color(
					VisualGrammar.BOG_LAND_DARK.r + tone,
					VisualGrammar.BOG_LAND_DARK.g + tone * 1.2,
					VisualGrammar.BOG_LAND_DARK.b + tone
				))
			for i in int(rect.get_area() / 26000.0):
				var tuft := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				draw_line(tuft, tuft + Vector2(-1.5, -4.0), VisualGrammar.BOG_MOSS, 1.5)
				draw_line(tuft + Vector2(2.5, 0.0), tuft + Vector2(3.5, -4.5), VisualGrammar.BOG_MOSS.darkened(0.08), 1.5)
		TerrainMapScript.SHALLOW:
			for i in int(rect.get_area() / 11000.0) + 1:
				var speck := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				draw_circle(speck, rng.randf_range(2.0, 5.0), Color(VisualGrammar.WATER_SHALLOW.r + 0.08, VisualGrammar.WATER_SHALLOW.g + 0.08, VisualGrammar.WATER_SHALLOW.b + 0.04, 0.7))
			for i in int(rect.get_area() / 18000.0) + 1:
				var ripple := Vector2(rng.randf_range(rect.position.x + 8.0, rect.end.x - 8.0), rng.randf_range(rect.position.y + 8.0, rect.end.y - 8.0))
				var width := rng.randf_range(8.0, 18.0)
				draw_line(ripple + Vector2(-width * 0.5, 0.0), ripple + Vector2(width * 0.5, 0.0), Color(VisualGrammar.WATER_FOAM.r, VisualGrammar.WATER_FOAM.g, VisualGrammar.WATER_FOAM.b, 0.28), 1.4)
				draw_line(ripple + Vector2(-width * 0.35, 4.0), ripple + Vector2(width * 0.35, 4.0), Color(VisualGrammar.WATER_SHALLOW.r + 0.08, VisualGrammar.WATER_SHALLOW.g + 0.08, VisualGrammar.WATER_SHALLOW.b + 0.06, 0.24), 1.0)
			for i in int(rect.get_area() / 30000.0) + 1:
				var reed := Vector2(rng.randf_range(rect.position.x + 6.0, rect.end.x - 6.0), rng.randf_range(rect.position.y + 6.0, rect.end.y - 6.0))
				draw_line(reed, reed + Vector2(-1.0, -7.0), VisualGrammar.BOG_REED, 2.0)
				draw_line(reed + Vector2(3.0, 0.0), reed + Vector2(4.0, -6.0), VisualGrammar.BOG_REED.darkened(0.14), 2.0)
		TerrainMapScript.COVER:
			draw_rect(rect, VisualGrammar.terrain_color(TerrainMapScript.COVER))
			for i in maxi(int(rect.get_area() / 2600.0), 3):
				var bush := Vector2(rng.randf_range(rect.position.x + 8.0, rect.end.x - 8.0), rng.randf_range(rect.position.y + 8.0, rect.end.y - 8.0))
				draw_circle(bush, rng.randf_range(7.0, 13.0), VisualGrammar.BOG_MOSS.darkened(rng.randf_range(0.08, 0.2)))
				draw_circle(bush + Vector2(-2.0, -3.0), rng.randf_range(3.0, 6.0), VisualGrammar.BOG_MOSS.lightened(0.08))
			draw_rect(rect, VisualGrammar.BOG_LAND_DARK.darkened(0.45), false, 2.0)
		TerrainMapScript.HABITAT_BLUE, TerrainMapScript.HABITAT_RED:
			var team_tint := Color(0.3, 0.55, 0.85, 0.5) if zone == TerrainMapScript.HABITAT_BLUE else Color(0.85, 0.4, 0.35, 0.5)
			draw_rect(rect, team_tint, false, 4.0)
			var post_gap := 28.0
			var x := rect.position.x
			while x <= rect.end.x:
				draw_rect(Rect2(Vector2(x - 2.0, rect.position.y - 5.0), Vector2(4.0, 8.0)), VisualGrammar.BOG_MUD)
				draw_rect(Rect2(Vector2(x - 2.0, rect.end.y - 3.0), Vector2(4.0, 8.0)), VisualGrammar.BOG_MUD)
				x += post_gap
			var y := rect.position.y
			while y <= rect.end.y:
				draw_rect(Rect2(Vector2(rect.position.x - 5.0, y - 2.0), Vector2(8.0, 4.0)), VisualGrammar.BOG_MUD)
				draw_rect(Rect2(Vector2(rect.end.x - 3.0, y - 2.0), Vector2(8.0, 4.0)), VisualGrammar.BOG_MUD)
				y += post_gap
			for i in 7:
				var patch := Vector2(rng.randf_range(rect.position.x + 12.0, rect.end.x - 12.0), rng.randf_range(rect.position.y + 12.0, rect.end.y - 12.0))
				draw_circle(patch, rng.randf_range(6.0, 12.0), Color(VisualGrammar.BOG_MUD_DARK.r, VisualGrammar.BOG_MUD_DARK.g, VisualGrammar.BOG_MUD_DARK.b, 0.55))

func _draw_zone_edge(zone: String, rect: Rect2) -> void:
	match zone:
		TerrainMapScript.WATER:
			draw_rect(rect.grow(1.0), VisualGrammar.WATER_FOAM, false, 2.0)
			draw_rect(rect.grow(-3.0), Color(VisualGrammar.WATER_DEEP.r * 0.75, VisualGrammar.WATER_DEEP.g * 0.8, VisualGrammar.WATER_DEEP.b * 0.9, 0.5), false, 1.5)
		TerrainMapScript.SHALLOW:
			_draw_stippled_rect(rect.grow(-2.0), Color(VisualGrammar.BOG_REED.r, VisualGrammar.BOG_REED.g, VisualGrammar.BOG_REED.b, 0.55), 18.0)
			draw_rect(rect.grow(-5.0), Color(VisualGrammar.WATER_SHALLOW.r + 0.03, VisualGrammar.WATER_SHALLOW.g + 0.03, VisualGrammar.WATER_SHALLOW.b + 0.02, 0.22), false, 1.5)
		TerrainMapScript.COVER:
			draw_rect(rect.grow(2.0), VisualGrammar.BOG_LAND_DARK.darkened(0.55), false, 3.0)
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

func _draw_land_bridges() -> void:
	if terrain_map == null or not terrain_map.has_method("get_land_bridge_rects"):
		return
	for rect: Rect2 in terrain_map.get_land_bridge_rects():
		draw_rect(rect.grow(4.0), Color(0.18, 0.2, 0.12, 0.52))
		draw_rect(rect, Color(0.34, 0.31, 0.19, 0.9))
		draw_rect(rect.grow(-4.0), Color(0.44, 0.39, 0.24, 0.42), false, 2.0)
		var plank_y := rect.position.y + 5.0
		while plank_y < rect.end.y - 3.0:
			draw_line(
				Vector2(rect.position.x + 5.0, plank_y),
				Vector2(rect.end.x - 5.0, plank_y),
				Color(0.18, 0.15, 0.09, 0.36),
				1.4
			)
			plank_y += 8.0
		for edge_x in [rect.position.x + 4.0, rect.end.x - 4.0]:
			draw_line(
				Vector2(edge_x, rect.position.y + 2.0),
				Vector2(edge_x, rect.end.y - 2.0),
				Color(0.2, 0.18, 0.1, 0.42),
				2.0
			)

func _draw_environmental_obstacles() -> void:
	if terrain_map == null or not terrain_map.has_method("get_environmental_obstacles"):
		return
	for obstacle: Dictionary in terrain_map.get_environmental_obstacles():
		var rect: Rect2 = obstacle.get("rect", Rect2())
		var center := rect.get_center()
		match String(obstacle.get("type", "")):
			"tree":
				_draw_tree_obstacle(center, rect.size)
			"rock":
				_draw_rock_obstacle(center, rect.size)
			_:
				_draw_bush_obstacle(center, rect.size)

func _draw_tree_obstacle(center: Vector2, size: Vector2) -> void:
	var radius := maxf(maxf(size.x, size.y) * 0.58, 16.0)
	draw_rect(Rect2(center + Vector2(-3.0, radius * 0.05), Vector2(6.0, radius * 0.58)), Color(0.3, 0.2, 0.11))
	draw_circle(center + Vector2(0.0, -radius * 0.18), radius * 0.72, Color(0.08, 0.2, 0.08))
	draw_circle(center + Vector2(-radius * 0.32, -radius * 0.02), radius * 0.46, Color(0.12, 0.28, 0.11))
	draw_circle(center + Vector2(radius * 0.34, 0.0), radius * 0.42, Color(0.07, 0.17, 0.07))
	draw_circle(center + Vector2(0.0, -radius * 0.42), radius * 0.36, Color(0.16, 0.34, 0.13))
	draw_circle(center + Vector2(radius * 0.18, -radius * 0.18), radius * 0.12, Color(0.42, 0.5, 0.18, 0.45))

func _draw_rock_obstacle(center: Vector2, size: Vector2) -> void:
	var half := size * 0.55
	var points := PackedVector2Array([
		center + Vector2(-half.x, half.y * 0.2),
		center + Vector2(-half.x * 0.62, -half.y * 0.58),
		center + Vector2(half.x * 0.12, -half.y * 0.82),
		center + Vector2(half.x * 0.86, -half.y * 0.28),
		center + Vector2(half.x * 0.72, half.y * 0.56),
		center + Vector2(-half.x * 0.15, half.y * 0.82)
	])
	draw_colored_polygon(points, Color(0.3, 0.32, 0.28))
	draw_polyline(points, Color(0.12, 0.13, 0.11), 2.0, true)
	draw_line(points[points.size() - 1], points[0], Color(0.12, 0.13, 0.11), 2.0)
	draw_line(center + Vector2(-half.x * 0.32, -half.y * 0.22), center + Vector2(half.x * 0.34, -half.y * 0.34), Color(0.46, 0.48, 0.42, 0.5), 1.5)
	draw_line(center + Vector2(-half.x * 0.06, half.y * 0.1), center + Vector2(half.x * 0.48, half.y * 0.24), Color(0.14, 0.15, 0.13, 0.52), 1.4)

func _draw_bush_obstacle(center: Vector2, size: Vector2) -> void:
	var radius := maxf(maxf(size.x, size.y) * 0.5, 12.0)
	for offset in [
		Vector2(-0.42, 0.04),
		Vector2(0.0, -0.2),
		Vector2(0.38, 0.0),
		Vector2(-0.08, 0.28)
	]:
		draw_circle(center + offset * radius, radius * 0.46, Color(0.1, 0.24, 0.1))
	draw_circle(center + Vector2(-radius * 0.18, -radius * 0.06), radius * 0.22, Color(0.18, 0.34, 0.14))
	draw_circle(center + Vector2(radius * 0.22, radius * 0.08), radius * 0.18, Color(0.16, 0.3, 0.12))

func _draw_perch_anchors() -> void:
	if terrain_map == null or not terrain_map.has_method("get_perch_anchors"):
		return
	for anchor: Vector2 in terrain_map.get_perch_anchors():
		draw_circle(anchor, 5.5, Color(0.7, 0.82, 0.48, 0.16))
		draw_line(anchor + Vector2(-5.0, 0.0), anchor + Vector2(5.0, 0.0), Color(0.78, 0.92, 0.58, 0.28), 1.2)
		draw_line(anchor + Vector2(0.0, -5.0), anchor + Vector2(0.0, 5.0), Color(0.78, 0.92, 0.58, 0.28), 1.2)
