extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Aura := preload("res://scripts/sim/abilities/aura.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

var primary_windup_remaining := 0.0
var grab_armed := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0

func reset_for_respawn(_actor: Node) -> void:
	primary_windup_remaining = 0.0
	grab_armed = false

func tick(actor: Node, delta: float) -> void:
	# The landing of an already-started windup happens regardless of stuns.
	if primary_windup_remaining > 0.0:
		primary_windup_remaining = maxf(primary_windup_remaining - delta, 0.0)
		if primary_windup_remaining <= 0.0:
			_land_bite(actor)

	if actor.input_frame == null or not actor.can_act():
		return

	# Q/E are processed even while a windup runs (inputs must not drop).
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0 and not grab_armed:
		grab_armed = true

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		var e := KitHelpers.ability(actor.creature_data, "E")
		var summary := String(e.get("summary", ""))
		var duration := KitHelpers.first_number(summary, 1.5)
		var radius_units := KitHelpers.nth_number(summary, 1, 1.5)
		# Enemies in the lure are stunned (no move, no actions); the turtle
		# itself cannot attack or cast, but can move (roster spec).
		Aura.apply(actor, radius_units * SimConstants.UNIT_PX, duration, {}, {"move_speed_mult": 0.0, "can_act_mult": 0.0}, "Lingual Lure")
		actor.add_modifier("Lingual Lure Self", {"can_act_mult": 0.0}, duration)
		actor.e_timer = KitHelpers.cooldown_seconds(e)
		return

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0 and primary_windup_remaining <= 0.0:
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

func _land_bite(actor: Node) -> void:
	var reach_units := KitHelpers.range_units(actor.stats, 1.0)
	if grab_armed:
		var q := KitHelpers.ability(actor.creature_data, "Q")
		reach_units += KitHelpers.first_number(String(q.get("summary", "")), 0.0)
	var hits := MeleeHit.hit(actor, reach_units * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite")
	if grab_armed:
		# Grab is spent by the empowered bite attempt; latchable hits are
		# pulled in front of the turtle's jaws.
		var grabbed: Node = null
		for hit in hits:
			if hit != null and is_instance_valid(hit) and hit.has_method("receive_latch"):
				grabbed = hit
				break
		if grabbed != null:
			grabbed.global_position = actor.global_position + actor.get_aim_direction() * (actor.body_radius + grabbed.body_radius)
			Latch.start(actor, grabbed, float(actor.stats.get("attack_interval_sec", 1.6)), "Grab")
		var q := KitHelpers.ability(actor.creature_data, "Q")
		actor.q_timer = KitHelpers.cooldown_seconds(q)
		grab_armed = false
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.0)) / actor.get_modifier_value("attack_speed_mult", 1.0)
