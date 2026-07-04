extends Node2D
class_name Core

const VisualStyle := preload("res://scripts/visual/visual_style.gd")

signal destroyed(core)

var team := 0
var max_health := 1000.0
var health := 1000.0
var radius := 64.0

func setup(core_team: int, core_position: Vector2) -> void:
	team = core_team
	position = core_position
	health = max_health
	queue_redraw()

func take_damage(amount: float, _source_team: int, _source_actor: Node = null) -> void:
	if health <= 0.0:
		return

	health = maxf(health - amount, 0.0)
	queue_redraw()

	if health <= 0.0:
		destroyed.emit(self)

func _draw() -> void:
	VisualStyle.draw_pixel_core(self, team, 10.0)
	draw_rect(Rect2(Vector2(-radius, -radius - 18.0), Vector2(radius * 2.0, 8.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-radius, -radius - 18.0), Vector2(radius * 2.0 * (health / max_health), 8.0)), Color(0.3, 1.0, 0.45))
