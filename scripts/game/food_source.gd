extends Node2D

# Neutral ecology pickup. The arena owns spawn timing and consumption rules;
# this node only carries deterministic food data and draws itself.

const KIND_PLANT := "plant"
const KIND_CRITTER := "critter"
const PLANT_BERRY := "berry"
const PLANT_TREE := "tree"
const PLANT_SEED := "seed"
const PLANT_FLOWER := "flower"

var kind := KIND_PLANT
var plant_type := PLANT_BERRY
var food_value := 28.0
var heal_fraction := 0.08
var body_radius := 12.0
var harvest_hits_required := 1
var harvest_hits_remaining := 1
var consumed := false

func setup(food_kind: String, spawn_position: Vector2, next_food_value := 28.0, next_heal_fraction := 0.08) -> void:
	kind = food_kind
	plant_type = PLANT_BERRY
	global_position = spawn_position
	food_value = next_food_value
	heal_fraction = next_heal_fraction
	harvest_hits_required = 1
	harvest_hits_remaining = harvest_hits_required
	body_radius = 10.0 if kind == KIND_PLANT else 12.0
	queue_redraw()

func setup_from_entry(entry: Dictionary) -> void:
	var next_kind := String(entry.get("kind", KIND_PLANT))
	var next_plant_type := String(entry.get("plant_type", PLANT_BERRY))
	var default_food := 44.0 if next_plant_type == PLANT_TREE else 28.0
	var default_heal := 0.16 if next_plant_type == PLANT_TREE else 0.08
	setup(
		next_kind,
		entry.get("position", Vector2.ZERO),
		float(entry.get("food_value", default_food)),
		float(entry.get("heal_fraction", default_heal))
	)
	if kind == KIND_PLANT:
		plant_type = next_plant_type
		harvest_hits_required = int(entry.get("harvest_hits", 3 if plant_type == PLANT_TREE else 1))
		harvest_hits_remaining = harvest_hits_required
		body_radius = _plant_body_radius()
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
	match plant_type:
		PLANT_TREE:
			_draw_tree()
		PLANT_SEED:
			_draw_seed_patch()
		PLANT_FLOWER:
			_draw_flower()
		_:
			_draw_berry_bush()

func _plant_body_radius() -> float:
	match plant_type:
		PLANT_TREE:
			return 15.0
		PLANT_SEED:
			return 8.0
		PLANT_FLOWER:
			return 9.0
		_:
			return 10.0

func _draw_berry_bush() -> void:
	var stem := Color(0.22, 0.55, 0.24)
	var leaf := Color(0.42, 0.86, 0.38)
	var fruit := Color(0.82, 0.18, 0.27)
	draw_line(Vector2(0.0, 7.0), Vector2(0.0, -8.0), stem, 3.0)
	draw_circle(Vector2(-5.0, -2.0), 5.0, leaf)
	draw_circle(Vector2(5.0, -4.0), 5.0, leaf.lightened(0.1))
	draw_circle(Vector2(-2.0, -9.0), 2.2, fruit)
	draw_circle(Vector2(3.0, -6.0), 2.0, fruit.lightened(0.1))
	draw_circle(Vector2(-7.0, -4.0), 1.8, fruit.darkened(0.1))

func _draw_tree() -> void:
	var trunk := Color(0.42, 0.25, 0.12)
	var canopy := Color(0.18, 0.52, 0.28)
	var fruit := Color(0.9, 0.64, 0.2)
	draw_rect(Rect2(Vector2(-3.0, -2.0), Vector2(6.0, 14.0)), trunk)
	draw_circle(Vector2(0.0, -10.0), 10.0, canopy)
	draw_circle(Vector2(-7.0, -4.0), 7.0, canopy.lightened(0.08))
	draw_circle(Vector2(7.0, -4.0), 7.0, canopy.darkened(0.04))
	draw_circle(Vector2(-3.0, -12.0), 2.0, fruit)
	draw_circle(Vector2(5.0, -7.0), 2.0, fruit.darkened(0.08))

func _draw_seed_patch() -> void:
	var soil := Color(0.42, 0.28, 0.16)
	var sprout := Color(0.48, 0.82, 0.35)
	draw_rect(Rect2(Vector2(-8.0, -5.0), Vector2(16.0, 10.0)), soil)
	for x in [-5.0, 0.0, 5.0]:
		draw_line(Vector2(x, 3.0), Vector2(x, -5.0), sprout.darkened(0.1), 1.6)
		draw_circle(Vector2(x - 1.8, -3.0), 2.2, sprout)

func _draw_flower() -> void:
	var stem := Color(0.24, 0.62, 0.28)
	var petal := Color(0.92, 0.42, 0.82)
	var center := Color(0.96, 0.78, 0.24)
	draw_line(Vector2(0.0, 8.0), Vector2(0.0, -5.0), stem, 2.4)
	draw_circle(Vector2(-5.0, -7.0), 4.0, petal.darkened(0.05))
	draw_circle(Vector2(5.0, -7.0), 4.0, petal.lightened(0.05))
	draw_circle(Vector2(0.0, -12.0), 4.0, petal)
	draw_circle(Vector2(0.0, -7.0), 3.0, center)

func _draw_critter() -> void:
	var shell := Color(0.5, 0.36, 0.2)
	var belly := Color(0.78, 0.62, 0.36)
	draw_circle(Vector2.ZERO, body_radius, shell)
	draw_circle(Vector2(2.0, 0.0), body_radius * 0.62, belly)
	for i in 4:
		var y := -6.0 + float(i) * 4.0
		draw_line(Vector2(-body_radius + 2.0, y), Vector2(-body_radius - 4.0, y - 2.0), shell.darkened(0.25), 2.0)
		draw_line(Vector2(body_radius - 2.0, y), Vector2(body_radius + 4.0, y - 2.0), shell.darkened(0.25), 2.0)
