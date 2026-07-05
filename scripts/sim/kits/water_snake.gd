extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const Knockback := preload("res://scripts/sim/abilities/knockback.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const BITE_DAMAGE := 8.0
const BITE_BLEED_TOTAL := 18.0
const BITE_BLEED_SEC := 3.0
const HOLD_LATCH_REFRESH_SEC := 0.75
const LATCH_DPS_RATIO := 0.01
const MUSKING_PUSH_DISTANCE_UNITS := 2.0
const INGESTION_THRESHOLD_RATIO := 0.15
const INGESTION_COOLDOWN_SEC := 20.0
const INGESTION_HEAL_RATIO := 0.85

var ingestion_timer := 0.0

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	ingestion_timer = 0.0

func reset_for_respawn(_actor: Node) -> void:
	ingestion_timer = 0.0

func tick(actor: Node, delta: float) -> void:
	ingestion_timer = maxf(ingestion_timer - delta, 0.0)
	_tick_latched(actor, delta)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY):
		if actor.latch_victim == null and actor.primary_timer <= 0.0:
			_bite(actor)
	elif actor.latch_victim != null and actor.latch_source == "Bite":
		actor.release_latch("primary_release")
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0 and actor.latch_victim == null:
		_musking(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		_retreat(actor)

func _bite(actor: Node) -> void:
	var hits := MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX, BITE_DAMAGE, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite", {"max_hits": 1})
	for hit in hits:
		if hit == null or not is_instance_valid(hit):
			continue
		if hit.has_method("apply_dot"):
			hit.apply_dot(actor, "Water Snake Bleed", BITE_BLEED_TOTAL, BITE_BLEED_SEC)
		if hit.has_method("receive_latch"):
			Latch.start(actor, hit, HOLD_LATCH_REFRESH_SEC, "Bite")
		break
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.7)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _tick_latched(actor: Node, delta: float) -> void:
	if actor.latch_victim == null or not is_instance_valid(actor.latch_victim) or actor.latch_source != "Bite":
		return
	var victim: Node = actor.latch_victim
	var held: bool = actor.input_frame != null and actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY)
	if held:
		actor.latch_timer = maxf(actor.latch_timer, HOLD_LATCH_REFRESH_SEC)
		victim.latch_timer = actor.latch_timer
		victim.take_damage_event(actor.make_damage_event(victim.max_health * LATCH_DPS_RATIO * delta, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Latched Bite"))
		_try_ingestion(actor, victim)
	else:
		actor.release_latch("primary_release")

func _try_ingestion(actor: Node, victim: Node) -> void:
	if ingestion_timer > 0.0 or victim.max_health >= actor.max_health:
		return
	if victim.health / maxf(victim.max_health, 1.0) > INGESTION_THRESHOLD_RATIO:
		return
	victim.take_damage_event(actor.make_damage_event(victim.health + victim.max_health, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Ingestion"))
	actor.heal(victim.max_health * INGESTION_HEAL_RATIO)
	ingestion_timer = INGESTION_COOLDOWN_SEC
	if actor.latch_victim == victim:
		actor.release_latch("ingestion")

func _musking(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var radius_units := KitHelpers.first_number(String(q.get("summary", "")), 3.0)
	var radius_px := radius_units * SimConstants.UNIT_PX
	if actor.arena != null:
		for entity in actor.arena.entities:
			if not TargetFilter.is_live_damage_target(actor, entity, {"require_damage_api": false}):
				continue
			var offset: Vector2 = entity.global_position - actor.global_position
			if offset.length() <= radius_px:
				var direction: Vector2 = offset.normalized() if offset != Vector2.ZERO else Vector2.RIGHT
				Knockback.apply(actor, entity, direction, MUSKING_PUSH_DISTANCE_UNITS * SimConstants.UNIT_PX)
	actor.q_timer = KitHelpers.cooldown_seconds(q)

func _retreat(actor: Node) -> void:
	var e := KitHelpers.ability(actor.creature_data, "E")
	var summary := String(e.get("summary", ""))
	var speed_bonus := 1.0 + KitHelpers.first_percent(summary, 0.2)
	var duration := KitHelpers.nth_number(summary, 1, 5.0)
	actor.add_modifier("Slithering Retreat", {"move_speed_mult": speed_bonus}, duration)
	actor.e_timer = KitHelpers.cooldown_seconds(e)
