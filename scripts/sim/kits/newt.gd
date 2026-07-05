extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Knockback := preload("res://scripts/sim/abilities/knockback.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const UNKEN_PUSH_RADIUS_UNITS := 3.0
const UNKEN_PUSH_DISTANCE_UNITS := 2.0
const TOXIC_REFLECT_RATIO := 0.6
const TOXIC_REFLECT_SEC := 3.0
const RIB_BURST_DAMAGE := 50.0
const RIB_THRESHOLD_RATIO := 0.10
const RIB_COOLDOWN_SEC := 10.0
const AUTOTOMY_COOLDOWN_SEC := 25.0
const AUTOTOMY_SPEED_MULT := 1.15
const AUTOTOMY_SEC := 10.0

var left_tail_next := false
var toxic_timer := 0.0
var rib_timer := 0.0
var autotomy_timer := 0.0
var tail_lost_timer := 0.0

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	left_tail_next = false
	toxic_timer = 0.0
	rib_timer = 0.0
	autotomy_timer = 0.0
	tail_lost_timer = 0.0

func reset_for_respawn(_actor: Node) -> void:
	left_tail_next = false
	toxic_timer = 0.0
	rib_timer = 0.0
	tail_lost_timer = 0.0

func tick(actor: Node, delta: float) -> void:
	toxic_timer = maxf(toxic_timer - delta, 0.0)
	rib_timer = maxf(rib_timer - delta, 0.0)
	autotomy_timer = maxf(autotomy_timer - delta, 0.0)
	tail_lost_timer = maxf(tail_lost_timer - delta, 0.0)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_tail_swing(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_unken_reflex(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		_start_toxic_secretion(actor)

func on_melee_contact_damage(actor: Node, attacker: Node, amount: float, _event: Resource) -> void:
	if toxic_timer <= 0.0 or amount <= 0.0 or attacker == null or not is_instance_valid(attacker) or not attacker.has_method("apply_dot"):
		return
	attacker.apply_dot(actor, "Toxic Secretion", amount * TOXIC_REFLECT_RATIO, TOXIC_REFLECT_SEC)

func on_damage_taken(actor: Node, event: Resource, amount: float, before_health: float) -> void:
	if amount <= 0.0 or rib_timer > 0.0 or event.source_actor == null or not is_instance_valid(event.source_actor) or event.source_actor == actor:
		return
	var crossed_threshold: bool = before_health > actor.max_health * RIB_THRESHOLD_RATIO and actor.health <= actor.max_health * RIB_THRESHOLD_RATIO
	if not crossed_threshold:
		return
	event.source_actor.take_damage_event(actor.make_damage_event(RIB_BURST_DAMAGE, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Rib Exudation"))
	if event.source_actor.has_method("apply_dot"):
		event.source_actor.apply_dot(actor, "Rib Exudation", amount * TOXIC_REFLECT_RATIO, TOXIC_REFLECT_SEC)
	rib_timer = RIB_COOLDOWN_SEC

func intercept_fatal_damage(actor: Node, _event: Resource, amount: float) -> bool:
	if amount <= 0.0 or autotomy_timer > 0.0:
		return false
	autotomy_timer = AUTOTOMY_COOLDOWN_SEC
	tail_lost_timer = AUTOTOMY_SEC
	actor.health = maxf(actor.max_health * RIB_THRESHOLD_RATIO, 1.0)
	actor.add_modifier("Caudal Autotomy", {"move_speed_mult": AUTOTOMY_SPEED_MULT}, AUTOTOMY_SEC)
	actor.emit_vfx_event("heal_tick", {
		"target": actor,
		"amount": actor.health,
		"position": actor.global_position
	})
	return true

func _tail_swing(actor: Node) -> void:
	if tail_lost_timer > 0.0:
		actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.95))
		return
	var source: String = "Left Tail" if left_tail_next else "Right Tail"
	left_tail_next = not left_tail_next
	MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 1.5) * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 19.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, source, {"max_hits": 1})
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.95)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _unken_reflex(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var duration := KitHelpers.first_number(String(q.get("summary", "")), 3.0)
	actor.add_modifier("Unken Reflex", {"invulnerable": 2.0, "move_speed_mult": 0.0}, duration)
	actor.q_timer = KitHelpers.cooldown_seconds(q)
	var radius_px := UNKEN_PUSH_RADIUS_UNITS * SimConstants.UNIT_PX
	var distance_px := UNKEN_PUSH_DISTANCE_UNITS * SimConstants.UNIT_PX
	if actor.arena == null:
		return
	for entity in actor.arena.entities:
		if not TargetFilter.is_live_damage_target(actor, entity, {"require_damage_api": false}):
			continue
		var offset: Vector2 = entity.global_position - actor.global_position
		if offset.length() <= radius_px:
			var direction: Vector2 = offset.normalized() if offset != Vector2.ZERO else Vector2.RIGHT
			Knockback.apply(actor, entity, direction, distance_px)

func _start_toxic_secretion(actor: Node) -> void:
	var e := KitHelpers.ability(actor.creature_data, "E")
	toxic_timer = KitHelpers.first_number(String(e.get("summary", "")), 5.0)
	actor.e_timer = KitHelpers.cooldown_seconds(e)
