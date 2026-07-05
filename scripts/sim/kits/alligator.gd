extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const BITE_LATCH_SEC := 3.0
const DEATH_ROLL_DPS := 30.0
const DEATH_ROLL_SEC := 5.0
const DEATH_ROLL_TURN_RAD_PER_SEC := TAU * 1.4
const AMBUSH_STEALTH_SEC := 9999.0
const AMBUSH_SLOW_MULT := 0.70
const DEVOUR_HEAL_RATIO := 0.50

var death_roll_timer := 0.0
var ambush_active := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	death_roll_timer = 0.0
	ambush_active = false

func reset_for_respawn(actor: Node) -> void:
	death_roll_timer = 0.0
	ambush_active = false
	if actor.has_method("remove_modifiers_from_source"):
		actor.remove_modifiers_from_source("Ambush")

func tick(actor: Node, delta: float) -> void:
	_tick_death_roll(actor, delta)
	_sync_ambush(actor)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY):
		if actor.latch_victim == null and actor.primary_timer <= 0.0:
			_bite(actor)
	elif actor.latch_victim != null and actor.latch_source == "Bite":
		actor.release_latch("primary_release")

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_try_death_roll(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0 and not ambush_active:
		_start_ambush(actor)

func on_damage_taken(actor: Node, _event: Resource, _amount: float, _before_health: float) -> void:
	_end_ambush(actor)

func on_kill(actor: Node, victim: Node) -> void:
	if victim != null and is_instance_valid(victim):
		actor.heal(float(victim.max_health) * DEVOUR_HEAL_RATIO)

func _bite(actor: Node) -> void:
	_end_ambush(actor)
	var damage := float(actor.stats.get("primary_damage", 0.0))
	var reach_px := KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX
	var hits := MeleeHit.hit(actor, reach_px, damage, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite", {"max_hits": 1})
	for hit in hits:
		if hit != null and is_instance_valid(hit) and hit.has_method("receive_latch"):
			Latch.start(actor, hit, BITE_LATCH_SEC, "Bite")
			break
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 1.8)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _try_death_roll(actor: Node) -> void:
	if actor.latch_victim == null or not is_instance_valid(actor.latch_victim):
		return
	if actor.latch_source != "Bite":
		return
	var victim: Node = actor.latch_victim
	if not _is_water(victim):
		return
	_end_ambush(actor)
	death_roll_timer = DEATH_ROLL_SEC
	actor.latch_source = "Death Roll"
	victim.latch_source = "Death Roll"
	actor.latch_timer = maxf(actor.latch_timer, DEATH_ROLL_SEC)
	victim.latch_timer = actor.latch_timer
	actor.q_timer = KitHelpers.cooldown_seconds(KitHelpers.ability(actor.creature_data, "Q"))

func _tick_death_roll(actor: Node, delta: float) -> void:
	if death_roll_timer <= 0.0:
		return
	if actor.latch_victim == null or not is_instance_valid(actor.latch_victim):
		death_roll_timer = 0.0
		return
	var victim: Node = actor.latch_victim
	death_roll_timer = maxf(death_roll_timer - delta, 0.0)
	actor.latch_timer = maxf(actor.latch_timer, death_roll_timer + delta)
	victim.latch_timer = actor.latch_timer
	victim.take_damage_event(actor.make_damage_event(DEATH_ROLL_DPS * delta, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Death Roll"))
	if actor.latch_victim == victim and is_instance_valid(victim):
		_apply_roll_motion(actor, victim, delta)
	if death_roll_timer <= 0.0 and actor.latch_victim == victim:
		actor.release_latch("death_roll_done")

func _apply_roll_motion(actor: Node, victim: Node, delta: float) -> void:
	var offset: Vector2 = actor.global_position - victim.global_position
	if offset == Vector2.ZERO:
		offset = -actor.get_aim_direction() * maxf(actor.body_radius + victim.body_radius, 1.0)
	var rolled := offset.rotated(DEATH_ROLL_TURN_RAD_PER_SEC * delta)
	actor.global_position = victim.global_position + rolled
	actor.velocity = rolled.normalized() * minf(actor.get_speed_px(), rolled.length() / maxf(delta, 0.001))
	actor.last_aim_direction = -rolled.normalized()

func _start_ambush(actor: Node) -> void:
	ambush_active = true
	actor.begin_stealth(AMBUSH_STEALTH_SEC, "Ambush")
	actor.remove_modifiers_from_source("Ambush")
	actor.add_modifier("Ambush", {"move_speed_mult": AMBUSH_SLOW_MULT}, AMBUSH_STEALTH_SEC)

func _sync_ambush(actor: Node) -> void:
	if ambush_active and not actor.is_stealthed():
		_end_ambush(actor)

func _end_ambush(actor: Node) -> void:
	if not ambush_active:
		return
	ambush_active = false
	actor.break_stealth()
	actor.remove_modifiers_from_source("Ambush")
	var e := KitHelpers.ability(actor.creature_data, "E")
	actor.e_timer = maxf(actor.e_timer, _ambush_cooldown(e))

func _ambush_cooldown(ability_data: Dictionary) -> float:
	if ability_data.has("cooldown_after_break_sec"):
		return float(ability_data["cooldown_after_break_sec"])
	return KitHelpers.cooldown_seconds(ability_data)

func _is_water(actor: Node) -> bool:
	if actor.has_method("get_current_zone"):
		return String(actor.get_current_zone()) == TerrainMapScript.WATER
	return false
