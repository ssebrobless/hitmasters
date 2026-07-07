extends Node2D

const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

const GROW_SEC := 2.0
const FIELD_SEC := 10.0
const BODY_RADIUS := 14.0
const HEAL_FRACTION := 0.20

var arena: Node = null
var source_actor: Node = null
var team := 0
var body_radius := BODY_RADIUS
var grow_timer := GROW_SEC
var remaining := FIELD_SEC
var consumed := false

func setup(field_arena: Node, actor: Node, field_position: Vector2) -> void:
	arena = field_arena
	source_actor = actor
	team = int(actor.team)
	global_position = field_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	if consumed:
		return
	if source_actor == null or not is_instance_valid(source_actor):
		retire()
		return
	if grow_timer > 0.0:
		var was_growing := grow_timer > 0.0
		grow_timer = maxf(grow_timer - delta, 0.0)
		if was_growing and grow_timer <= 0.0:
			queue_redraw()
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		retire()
		return
	if arena != null:
		for entity in arena.entities:
			if not TargetFilter.is_live_ally_target(source_actor, entity, {"require_method": "heal"}):
				continue
			if entity.global_position.distance_to(global_position) <= body_radius + entity.body_radius:
				entity.heal(float(entity.max_health) * HEAL_FRACTION)
				retire()
				return

func is_alive() -> bool:
	return not consumed

func retire() -> void:
	if consumed:
		return
	consumed = true
	queue_free()

func _draw() -> void:
	var mature := grow_timer <= 0.0
	var fill := VisualGrammar.harvestable_color("seed_soil", 0.35) if not mature else VisualGrammar.harvestable_color("berry_leaf", 0.30)
	var outline := VisualGrammar.harvestable_color("seed_marker", 0.7) if not mature else VisualGrammar.harvestable_color("flower_petal", 0.75)
	draw_circle(Vector2.ZERO, body_radius, fill)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, outline, 2.0)
	if mature:
		draw_line(Vector2(0.0, 8.0), Vector2(0.0, -5.0), VisualGrammar.harvestable_color("flower_stem"), 2.0)
		draw_circle(Vector2(-4.0, -6.0), 4.0, VisualGrammar.harvestable_color("flower_petal").darkened(0.04))
		draw_circle(Vector2(4.0, -6.0), 4.0, VisualGrammar.harvestable_color("flower_petal").lightened(0.04))
		draw_circle(Vector2(0.0, -10.0), 4.0, VisualGrammar.harvestable_color("flower_petal"))
		draw_circle(Vector2(0.0, -6.0), 2.5, VisualGrammar.harvestable_color("flower_center"))
	else:
		draw_rect(Rect2(Vector2(-7.0, -4.0), Vector2(14.0, 8.0)), VisualGrammar.harvestable_color("seed_soil", 0.85))
		draw_line(Vector2(0.0, 3.0), Vector2(0.0, -5.0), VisualGrammar.harvestable_color("seed_sprout"), 1.6)
