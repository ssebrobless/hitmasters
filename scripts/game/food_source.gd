extends Node2D

# Neutral ecology pickup. The arena owns spawn timing and consumption rules;
# this node only carries deterministic food data and draws itself.

const KIND_PLANT := "plant"
const KIND_CRITTER := "critter"
const PLANT_BERRY := "berry"
const PLANT_TREE := "tree"
const PLANT_SEED := "seed"
const PLANT_FLOWER := "flower"
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

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

func requires_attack_harvest() -> bool:
	return kind == KIND_PLANT

func harvest_hit(_actor: Node = null) -> bool:
	if consumed or kind != KIND_PLANT:
		return false
	harvest_hits_remaining = maxi(0, harvest_hits_remaining - 1)
	queue_redraw()
	return harvest_hits_remaining <= 0

func _draw() -> void:
	if consumed:
		return
	if kind == KIND_PLANT:
		_draw_plant()
	else:
		_draw_critter()

func _draw_plant() -> void:
	_draw_resource_marker()
	match plant_type:
		PLANT_TREE:
			_draw_tree()
		PLANT_SEED:
			_draw_seed_patch()
		PLANT_FLOWER:
			_draw_flower()
		_:
			_draw_berry_bush()
	_draw_harvest_pips()

func _draw_resource_marker() -> void:
	var marker_center := Vector2(0.0, 2.0)
	var marker_radius := body_radius + (4.5 if plant_type == PLANT_TREE else 3.0)
	var fill := VisualGrammar.harvestable_color("marker_fill", 0.22)
	var outline := VisualGrammar.harvestable_color("berry_marker", 0.62)
	match plant_type:
		PLANT_TREE:
			outline = VisualGrammar.harvestable_color("tree_marker", 0.72)
		PLANT_SEED:
			outline = VisualGrammar.harvestable_color("seed_marker", 0.66)
		PLANT_FLOWER:
			outline = VisualGrammar.harvestable_color("flower_marker", 0.68)
	draw_circle(marker_center, marker_radius, fill)
	draw_arc(marker_center, marker_radius, 0.0, TAU, 28, outline, 1.35, true)

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
	var stem := VisualGrammar.harvestable_color("berry_stem")
	var leaf := VisualGrammar.harvestable_color("berry_leaf")
	var fruit := VisualGrammar.harvestable_color("berry_fruit")
	draw_line(Vector2(0.0, 7.0), Vector2(0.0, -8.0), stem, 3.0)
	draw_circle(Vector2(-5.0, -2.0), 5.0, leaf)
	draw_circle(Vector2(5.0, -4.0), 5.0, leaf.lightened(0.1))
	draw_circle(Vector2(-2.0, -9.0), 2.2, fruit)
	draw_circle(Vector2(3.0, -6.0), 2.0, fruit.lightened(0.1))
	draw_circle(Vector2(-7.0, -4.0), 1.8, fruit.darkened(0.1))

func _draw_tree() -> void:
	var trunk := VisualGrammar.harvestable_color("tree_trunk")
	var canopy := VisualGrammar.harvestable_color("tree_canopy")
	var fruit := VisualGrammar.harvestable_color("tree_fruit")
	draw_rect(Rect2(Vector2(-3.0, -2.0), Vector2(6.0, 14.0)), trunk)
	draw_circle(Vector2(0.0, -10.0), 10.0, canopy)
	draw_circle(Vector2(-7.0, -4.0), 7.0, canopy.lightened(0.08))
	draw_circle(Vector2(7.0, -4.0), 7.0, canopy.darkened(0.04))
	draw_circle(Vector2(-3.0, -12.0), 2.0, fruit)
	draw_circle(Vector2(5.0, -7.0), 2.0, fruit.darkened(0.08))

func _draw_seed_patch() -> void:
	var soil := VisualGrammar.harvestable_color("seed_soil")
	var sprout := VisualGrammar.harvestable_color("seed_sprout")
	draw_rect(Rect2(Vector2(-8.0, -5.0), Vector2(16.0, 10.0)), soil)
	for x in [-5.0, 0.0, 5.0]:
		draw_line(Vector2(x, 3.0), Vector2(x, -5.0), sprout.darkened(0.1), 1.6)
		draw_circle(Vector2(x - 1.8, -3.0), 2.2, sprout)

func _draw_flower() -> void:
	var stem := VisualGrammar.harvestable_color("flower_stem")
	var petal := VisualGrammar.harvestable_color("flower_petal")
	var center := VisualGrammar.harvestable_color("flower_center")
	draw_line(Vector2(0.0, 8.0), Vector2(0.0, -5.0), stem, 2.4)
	draw_circle(Vector2(-5.0, -7.0), 4.0, petal.darkened(0.05))
	draw_circle(Vector2(5.0, -7.0), 4.0, petal.lightened(0.05))
	draw_circle(Vector2(0.0, -12.0), 4.0, petal)
	draw_circle(Vector2(0.0, -7.0), 3.0, center)

func _draw_harvest_pips() -> void:
	if harvest_hits_required <= 1:
		return
	var pip_color := VisualGrammar.harvestable_color("pip")
	var empty_color := VisualGrammar.harvestable_color("pip_empty", 0.72)
	for i in harvest_hits_required:
		var x := (float(i) - float(harvest_hits_required - 1) * 0.5) * 5.0
		var color := pip_color if i < harvest_hits_remaining else empty_color
		draw_circle(Vector2(x, body_radius + 5.0), 1.8, color)

func _draw_critter() -> void:
	var shell := VisualGrammar.harvestable_color("critter_shell")
	var belly := VisualGrammar.harvestable_color("critter_belly")
	draw_circle(Vector2.ZERO, body_radius, shell)
	draw_circle(Vector2(2.0, 0.0), body_radius * 0.62, belly)
	for i in 4:
		var y := -6.0 + float(i) * 4.0
		draw_line(Vector2(-body_radius + 2.0, y), Vector2(-body_radius - 4.0, y - 2.0), shell.darkened(0.25), 2.0)
		draw_line(Vector2(body_radius - 2.0, y), Vector2(body_radius + 4.0, y - 2.0), shell.darkened(0.25), 2.0)
