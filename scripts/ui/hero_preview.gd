extends Control

const VisualStyle := preload("res://scripts/visual/visual_style.gd")

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
	VisualStyle.draw_battle_creature(self, hero_id, team, minf(size.x, size.y) * 0.24, Vector2(0.0, -1.0), 0.0, 1.0, false, {"moving": true, "walk_phase": Time.get_ticks_msec() * 0.004, "origin": center})

func _process(_delta: float) -> void:
	queue_redraw()
