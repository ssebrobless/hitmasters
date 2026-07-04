extends Control

const VisualStyle := preload("res://scripts/visual/visual_style.gd")

const PREVIEW_REFERENCE_RADIUS_UNITS := 1.6
const PREVIEW_MAX_RADIUS_FRACTION := 0.31
const PREVIEW_MIN_RADIUS_FRACTION := 0.09

var hero_id := "snapping_turtle"
var team := 0

func set_hero(next_hero_id: String, next_team := 0) -> void:
	hero_id = next_hero_id
	team = next_team
	queue_redraw()

func set_creature(next_creature_id: String, next_team := 0) -> void:
	set_hero(next_creature_id, next_team)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.07, 0.085, 0.095))
	draw_rect(rect, Color(0.22, 0.28, 0.31), false, 2.0)
	draw_line(Vector2(0.0, size.y - 18.0), Vector2(size.x, size.y - 18.0), Color(0.13, 0.16, 0.17), 2.0)

	var center := size * 0.5 + Vector2(0.0, 10.0)
	var radius := _preview_radius()
	var max_radius := minf(size.x, size.y) * PREVIEW_MAX_RADIUS_FRACTION
	var team_ring := VisualStyle.team_color(team)
	team_ring.a = 0.42
	draw_arc(center, max_radius + 3.0, 0.0, TAU, 44, Color(0.62, 0.68, 0.62, 0.22), 1.0)
	draw_arc(center, radius + 4.0, 0.0, TAU, 44, team_ring, 1.5)
	VisualStyle.draw_battle_creature(self, hero_id, team, radius, Vector2(0.0, -1.0), 0.0, 1.0, false, {"moving": true, "walk_phase": Time.get_ticks_msec() * 0.004, "origin": center})

func _process(_delta: float) -> void:
	queue_redraw()

func _preview_radius() -> float:
	var min_dimension := minf(size.x, size.y)
	var max_radius := min_dimension * PREVIEW_MAX_RADIUS_FRACTION
	var min_radius := min_dimension * PREVIEW_MIN_RADIUS_FRACTION
	var radius_units := 0.6
	var catalog := get_node_or_null("/root/CreatureCatalog")
	if catalog != null:
		var creature: Dictionary = catalog.get_creature(hero_id)
		var footprint: Dictionary = creature.get("footprint", {})
		radius_units = float(footprint.get("radius_units", radius_units))
	return clampf(radius_units / PREVIEW_REFERENCE_RADIUS_UNITS * max_radius, min_radius, max_radius)
