extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Knockback := preload("res://scripts/sim/abilities/knockback.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const BITE_LATCH_SEC := 2.0
const GANG_UP_LATCH_SEC := 2.0
const GANG_UP_IMMOBILIZE_SOURCE := "Gang Up"
const DEFAULT_ATTACK_INTERVAL_SEC := 0.8
const DEFAULT_GANG_UP_REARM_SEC := 6.0

var gang_up_armed := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	gang_up_armed = false

func reset_for_respawn(_actor: Node) -> void:
	gang_up_armed = false

func tick(actor: Node, _delta: float) -> void:
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_bite(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_tail_whip(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0 and not gang_up_armed:
		gang_up_armed = true
		actor.e_timer = 0.2

func _bite(actor: Node) -> void:
	var reach_px := KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX
	var hits := MeleeHit.hit(actor, reach_px, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Gang Up" if gang_up_armed else "Bite", {"max_hits": 1})
	for hit in hits:
		if hit != null and is_instance_valid(hit) and hit.has_method("receive_latch"):
			if gang_up_armed:
				Latch.start(actor, hit, GANG_UP_LATCH_SEC, "Gang Up")
				if hit.has_method("add_modifier"):
					hit.add_modifier(GANG_UP_IMMOBILIZE_SOURCE, {"move_speed_mult": 0.0}, GANG_UP_LATCH_SEC)
				actor.e_timer = maxf(actor.e_timer, DEFAULT_GANG_UP_REARM_SEC)
			else:
				Latch.start(actor, hit, BITE_LATCH_SEC, "Bite")
			break
	gang_up_armed = false
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", DEFAULT_ATTACK_INTERVAL_SEC)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _tail_whip(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var knockback_units := KitHelpers.first_number(String(q.get("summary", "")), 1.5)
	var reach_px := maxf(KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX, knockback_units * SimConstants.UNIT_PX)
	var hits := MeleeHit.hit(actor, reach_px, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Tail Whip", {"allow_harvest": false})
	for hit in hits:
		var direction: Vector2 = hit.global_position - actor.global_position
		if direction == Vector2.ZERO:
			direction = actor.get_aim_direction()
		Knockback.apply(actor, hit, direction, knockback_units * SimConstants.UNIT_PX)
	actor.q_timer = KitHelpers.cooldown_seconds(q)
