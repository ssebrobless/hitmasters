extends Node2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const FIELD_RADIUS_UNITS := 3.0
const FIELD_SEC := 4.0
const FIELD_SLOW_MULT := 0.60
const FIELD_VULN_MULT := 1.10
const FIELD_REFRESH_SEC := 0.22

var arena: Node = null
var source_actor: Node = null
var team := 0
var body_radius := FIELD_RADIUS_UNITS * SimConstants.UNIT_PX
var remaining := FIELD_SEC

func setup(field_arena: Node, source_actor: Node, field_position: Vector2) -> void:
	arena = field_arena
	self.source_actor = source_actor
	team = int(source_actor.team)
	global_position = field_position

func _physics_process(delta: float) -> void:
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0 or source_actor == null or not is_instance_valid(source_actor):
		retire()
		return
	if arena != null:
		for entity in arena.entities:
			if not TargetFilter.is_live_damage_target(source_actor, entity, {"require_damage_api": false, "require_modifier_api": true}):
				continue
			if entity.global_position.distance_to(global_position) <= body_radius + entity.body_radius:
				entity.add_modifier("Glowworm Field", {"move_speed_mult": FIELD_SLOW_MULT, "damage_taken_mult": FIELD_VULN_MULT}, FIELD_REFRESH_SEC)
	queue_redraw()

func retire() -> void:
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, Color(0.95, 0.9, 0.3, 0.12))
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 32, Color(0.95, 0.85, 0.24, 0.55), 2.0)
