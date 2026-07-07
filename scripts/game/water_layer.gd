extends Node2D

# Animated water ripples only — the sole terrain element that redraws.
# Precomputes ripple origins once; per frame it draws ~a few dozen lines
# and nothing else. Throttled to 20 Hz.

const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

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

func uses_expanding_ripple_arcs() -> bool:
	return true

func get_animation_primitive_budget_per_origin() -> int:
	return 3

func _process(delta: float) -> void:
	elapsed += delta
	redraw_accumulator += delta
	if redraw_accumulator >= REDRAW_INTERVAL:
		redraw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	var phase := elapsed * 0.42
	for i in ripple_origins.size():
		var rect := ripple_rects[ripple_rect_index[i]]
		var local_phase := fmod(phase + float((i * 29) % 100) / 100.0, 1.0)
		var drift := Vector2(
			sin(elapsed * 0.7 + float(i)) * 3.0,
			cos(elapsed * 0.5 + float(i) * 0.7) * 2.0
		)
		var ripple := ripple_origins[i] + drift
		if rect.grow(-6.0).has_point(ripple):
			var radius := lerpf(4.0, 18.0, local_phase)
			var alpha := (1.0 - local_phase) * 0.32
			var foam := Color(VisualGrammar.WATER_FOAM.r, VisualGrammar.WATER_FOAM.g, VisualGrammar.WATER_FOAM.b, alpha)
			draw_arc(ripple, radius, PI * 1.06, PI * 1.94, 12, foam, 1.25)
			draw_arc(ripple + Vector2(0.0, 3.0), radius * 0.62, PI * 0.08, PI * 0.92, 8, Color(foam.r, foam.g, foam.b, alpha * 0.55), 1.0)
			if i % 3 == 0:
				var glint_width := lerpf(5.0, 11.0, 1.0 - local_phase)
				draw_line(ripple + Vector2(-glint_width, -radius * 0.12), ripple + Vector2(glint_width, -radius * 0.12), Color(foam.r, foam.g, foam.b, alpha * 0.72), 1.0)
