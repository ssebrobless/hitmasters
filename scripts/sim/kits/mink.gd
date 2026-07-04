extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Dash := preload("res://scripts/sim/abilities/dash.gd")
const Aura := preload("res://scripts/sim/abilities/aura.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

var choke_active := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0

func tick(actor: Node, _delta: float) -> void:
	if actor.input_frame == null:
		return
	if choke_active:
		var hits := MeleeHit.hit(actor, actor.body_radius * 1.5, _choke_damage(actor), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Choke")
		if not hits.is_empty():
			var q := KitHelpers.ability(actor.creature_data, "Q")
			var execute_seconds := KitHelpers.nth_number(String(q.get("summary", "")), 2, 0.0)
			Latch.start(actor, hits[0], execute_seconds, "Choke", execute_seconds)
			choke_active = false
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite")
		actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.0)) / actor.get_modifier_value("attack_speed_mult", 1.0)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		var q := KitHelpers.ability(actor.creature_data, "Q")
		var distance_units := KitHelpers.first_number(String(q.get("summary", "")), 0.0)
		var duration := (distance_units * SimConstants.UNIT_PX) / maxf(actor.get_speed_px() * 2.0, 1.0)
		Dash.start(actor, actor.get_aim_direction(), distance_units * SimConstants.UNIT_PX, duration)
		choke_active = true
		actor.q_timer = KitHelpers.nth_number(String(q.get("cooldown", "")), 0, 0.0)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		var e := KitHelpers.ability(actor.creature_data, "E")
		var summary := String(e.get("summary", ""))
		var radius_units := KitHelpers.first_number(summary, 0.0)
		var ally_dr := 1.0 - KitHelpers.first_percent(summary, 0.0)
		var ally_damage := 1.0 + KitHelpers.nth_number(summary, 2, 0.0) / 100.0
		var enemy_heal := 1.0 - KitHelpers.nth_number(summary, 4, 0.0) / 100.0
		var duration := KitHelpers.nth_number(summary, 5, 0.0)
		Aura.apply(actor, radius_units * SimConstants.UNIT_PX, duration, {"damage_taken_mult": ally_dr, "damage_dealt_mult": ally_damage}, {"healing_received_mult": enemy_heal}, "Scent Marking")
		actor.e_timer = KitHelpers.cooldown_seconds(e)

func _choke_damage(actor: Node) -> float:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	return KitHelpers.nth_number(String(q.get("summary", "")), 1, 0.0)
