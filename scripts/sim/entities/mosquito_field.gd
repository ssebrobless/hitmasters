extends Node2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const FIELD_RADIUS_UNITS := 3.0
const AOE_DPS := 15.0
const SLOW_MULT := 0.95
const SLOW_REFRESH_SEC := 0.24

var arena: Node = null
var source_actor: Node = null
var source_kit: RefCounted = null
var team := 0
var body_radius := FIELD_RADIUS_UNITS * SimConstants.UNIT_PX
var remaining := 3.0
var retired := false

func setup(field_arena: Node, actor: Node, kit: RefCounted, field_position: Vector2, duration: float) -> void:
	arena = field_arena
	source_actor = actor
	source_kit = kit
	team = int(actor.team)
	global_position = field_position
	remaining = duration

func _physics_process(delta: float) -> void:
	if retired:
		return
	if source_actor == null or not is_instance_valid(source_actor):
		retire()
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		retire()
		return
	if arena != null:
		for entity in arena.entities:
			if not TargetFilter.is_live_damage_target(source_actor, entity, {"require_modifier_api": true}):
				continue
			if entity.global_position.distance_to(global_position) > body_radius + entity.body_radius:
				continue
			var before: float = entity.health if "health" in entity else 0.0
			var event := DamageEventScript.new()
			event.setup(AOE_DPS * delta, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, source_actor, "Mosquito AOE")
			entity.take_damage_event(event)
			entity.add_modifier("Mosquito AOE", {"move_speed_mult": SLOW_MULT}, SLOW_REFRESH_SEC)
			var dealt: float = maxf(before - float(entity.health if "health" in entity else before), 0.0)
			if dealt > 0.0 and source_kit != null and source_kit.has_method("record_blood_gain"):
				source_kit.record_blood_gain(source_actor, dealt)
	queue_redraw()

func is_alive() -> bool:
	return not retired

func retire() -> void:
	if retired:
		return
	retired = true
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, Color(0.18, 0.16, 0.18, 0.16))
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 36, Color(0.45, 0.45, 0.48, 0.55), 2.0)
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var r := body_radius * (0.25 + 0.06 * float(i % 5))
		draw_circle(Vector2(cos(angle), sin(angle)) * r, 2.0, Color(0.1, 0.1, 0.11, 0.75))
