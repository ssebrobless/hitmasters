extends Node2D

const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

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

func _physics_process(delta: float) -> void:
	if consumed:
		return
	if source_actor == null or not is_instance_valid(source_actor):
		retire()
		return
	if grow_timer > 0.0:
		grow_timer = maxf(grow_timer - delta, 0.0)
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
	queue_redraw()

func is_alive() -> bool:
	return not consumed

func retire() -> void:
	if consumed:
		return
	consumed = true
	queue_free()

func _draw() -> void:
	var mature := grow_timer <= 0.0
	var fill := Color(0.42, 0.24, 0.08, 0.35) if not mature else Color(0.2, 0.52, 0.18, 0.30)
	var outline := Color(0.7, 0.45, 0.16, 0.7) if not mature else Color(0.9, 0.48, 0.78, 0.75)
	draw_circle(Vector2.ZERO, body_radius, fill)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, outline, 2.0)
	if mature:
		draw_line(Vector2(0.0, 8.0), Vector2(0.0, -5.0), Color(0.22, 0.58, 0.22), 2.0)
		draw_circle(Vector2(-4.0, -6.0), 4.0, Color(0.92, 0.42, 0.82))
		draw_circle(Vector2(4.0, -6.0), 4.0, Color(0.94, 0.5, 0.86))
		draw_circle(Vector2(0.0, -10.0), 4.0, Color(0.9, 0.42, 0.78))
		draw_circle(Vector2(0.0, -6.0), 2.5, Color(0.95, 0.76, 0.24))
	else:
		draw_rect(Rect2(Vector2(-7.0, -4.0), Vector2(14.0, 8.0)), Color(0.36, 0.22, 0.12, 0.85))
		draw_line(Vector2(0.0, 3.0), Vector2(0.0, -5.0), Color(0.36, 0.68, 0.28), 1.6)
