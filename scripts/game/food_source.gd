extends Node2D

# Neutral ecology pickup. The arena owns spawn timing and consumption rules;
# this node only carries deterministic food data and draws itself.

const KIND_PLANT := "plant"
const KIND_CRITTER := "critter"

var kind := KIND_PLANT
var food_value := 28.0
var heal_fraction := 0.08
var body_radius := 12.0
var consumed := false

func setup(food_kind: String, spawn_position: Vector2, next_food_value := 28.0, next_heal_fraction := 0.08) -> void:
	kind = food_kind
	global_position = spawn_position
	food_value = next_food_value
	heal_fraction = next_heal_fraction
	body_radius = 10.0 if kind == KIND_PLANT else 12.0
	queue_redraw()

func is_alive() -> bool:
	return not consumed

func consume() -> void:
	consumed = true
	queue_free()

func _draw() -> void:
	if consumed:
		return
	if kind == KIND_PLANT:
		_draw_plant()
	else:
		_draw_critter()

func _draw_plant() -> void:
	var stem := Color(0.22, 0.55, 0.24)
	var leaf := Color(0.42, 0.86, 0.38)
	var fruit := Color(0.88, 0.72, 0.28)
	draw_line(Vector2(0.0, 7.0), Vector2(0.0, -8.0), stem, 3.0)
	draw_circle(Vector2(-5.0, -2.0), 5.0, leaf)
	draw_circle(Vector2(5.0, -4.0), 5.0, leaf.lightened(0.1))
	draw_circle(Vector2(0.0, -9.0), 3.5, fruit)

func _draw_critter() -> void:
	var shell := Color(0.5, 0.36, 0.2)
	var belly := Color(0.78, 0.62, 0.36)
	draw_circle(Vector2.ZERO, body_radius, shell)
	draw_circle(Vector2(2.0, 0.0), body_radius * 0.62, belly)
	for i in 4:
		var y := -6.0 + float(i) * 4.0
		draw_line(Vector2(-body_radius + 2.0, y), Vector2(-body_radius - 4.0, y - 2.0), shell.darkened(0.25), 2.0)
		draw_line(Vector2(body_radius - 2.0, y), Vector2(body_radius + 4.0, y - 2.0), shell.darkened(0.25), 2.0)
