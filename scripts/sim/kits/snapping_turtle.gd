extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Aura := preload("res://scripts/sim/abilities/aura.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")

var primary_windup_remaining := 0.0
var grab_armed := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0

func tick(actor: Node, delta: float) -> void:
	if primary_windup_remaining > 0.0:
		primary_windup_remaining = maxf(primary_windup_remaining - delta, 0.0)
		if primary_windup_remaining <= 0.0:
			_land_bite(actor)
		return

	if actor.input_frame == null:
		return
	if actor.input_frame.is_pressed(preload("res://scripts/sim/input_frame.gd").BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		primary_windup_remaining = float(actor.stats.get("windup_sec", 0.0))
		if primary_windup_remaining > 0.0 and actor.has_method("emit_vfx_event"):
			var reach_units := KitHelpers.range_units(actor.stats, 1.0)
			if grab_armed:
				var grab := KitHelpers.ability(actor.creature_data, "Q")
				reach_units += KitHelpers.first_number(String(grab.get("summary", "")), 0.0)
			actor.emit_vfx_event("windup_started", {
				"actor": actor,
				"position": actor.global_position,
				"aim": actor.get_aim_direction(),
				"reach_px": reach_units * SimConstants.UNIT_PX,
				"duration": primary_windup_remaining,
				"source_ability": "Bite"
			})
		if primary_windup_remaining <= 0.0:
			_land_bite(actor)
	if actor.input_frame.is_pressed(preload("res://scripts/sim/input_frame.gd").BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		var q := KitHelpers.ability(actor.creature_data, "Q")
		grab_armed = true
		actor.q_timer = KitHelpers.cooldown_seconds(q)
	if actor.input_frame.is_pressed(preload("res://scripts/sim/input_frame.gd").BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		var e := KitHelpers.ability(actor.creature_data, "E")
		var summary := String(e.get("summary", ""))
		var duration := KitHelpers.first_number(summary, 0.0)
		var radius_units := KitHelpers.nth_number(summary, 1, 0.0)
		Aura.apply(actor, radius_units * SimConstants.UNIT_PX, duration, {}, {"move_speed_mult": 0.0}, "Lingual Lure")
		actor.e_timer = KitHelpers.cooldown_seconds(e)

func _land_bite(actor: Node) -> void:
	var reach_units := KitHelpers.range_units(actor.stats, 1.0)
	if grab_armed:
		var q := KitHelpers.ability(actor.creature_data, "Q")
		reach_units += KitHelpers.first_number(String(q.get("summary", "")), 0.0)
	var hits := MeleeHit.hit(actor, reach_units * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite")
	if grab_armed and not hits.is_empty():
		Latch.start(actor, hits[0], float(actor.stats.get("attack_interval_sec", 0.0)), "Grab")
	grab_armed = false
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.0)) / actor.get_modifier_value("attack_speed_mult", 1.0)
