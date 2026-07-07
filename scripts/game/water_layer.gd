extends Node2D

# Animated water ripples only — the sole terrain element that redraws.
# Precomputes ripple origins once; per frame it draws ~a few dozen lines
# and nothing else. Throttled to 20 Hz.

const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

const REDRAW_INTERVAL := 0.05

var ripple_rects: Array[Rect2] = []
var ripple_origins: Array[Vector2] = []
var ripple_rect_index: Array[int] = []
var elapsed := 0.0
var redraw_accumulator := 0.0

func setup(terrain_map: RefCounted) -> void:
	z_index = -9
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260704
	for rect: Rect2 in terrain_map.get_rects(TerrainMapScript.WATER):
		var rect_index := ripple_rects.size()
		ripple_rects.append(rect)
		for i in int(rect.get_area() / 14000.0) + 2:
			ripple_origins.append(Vector2(rng.randf_range(rect.position.x + 10.0, rect.end.x - 10.0), rng.randf_range(rect.position.y + 6.0, rect.end.y - 6.0)))
			ripple_rect_index.append(rect_index)

func get_redraw_interval() -> float:
	return REDRAW_INTERVAL

func get_ripple_count() -> int:
	return ripple_origins.size()

func _process(delta: float) -> void:
	elapsed += delta
	redraw_accumulator += delta
	if redraw_accumulator >= REDRAW_INTERVAL:
		redraw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	var phase := elapsed * 0.9
	for i in ripple_origins.size():
		var rect := ripple_rects[ripple_rect_index[i]]
		var drift := fmod(phase * 14.0 + float((i * 37) % 60), 60.0) - 30.0
		var ripple := ripple_origins[i] + Vector2(0.0, drift)
		if rect.grow(-4.0).has_point(ripple):
			draw_line(ripple + Vector2(-7.0, 0.0), ripple + Vector2(7.0, 0.0), Color(0.32, 0.55, 0.62, 0.5), 1.5)
