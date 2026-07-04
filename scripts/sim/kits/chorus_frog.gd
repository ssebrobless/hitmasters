extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const Projectile := preload("res://scripts/sim/abilities/projectile.gd")
const Aura := preload("res://scripts/sim/abilities/aura.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0

func tick(actor: Node, _delta: float) -> void:
	if actor.input_frame == null:
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		var range_units := KitHelpers.range_units(actor.stats, 1.0)
		Projectile.instant_line(actor, range_units * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Tongue Poke")
		actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.0)) / actor.get_modifier_value("attack_speed_mult", 1.0)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		var q := KitHelpers.ability(actor.creature_data, "Q")
		var summary := String(q.get("summary", ""))
		var radius_units := KitHelpers.first_number(summary, 0.0)
		var buff := 1.0 + KitHelpers.first_percent(summary, 0.0)
		var duration := KitHelpers.nth_number(summary, 2, 0.0)
		Aura.apply(actor, radius_units * SimConstants.UNIT_PX, duration, {"move_speed_mult": buff, "attack_speed_mult": buff}, {}, "Comb Call")
		actor.q_timer = KitHelpers.cooldown_seconds(q)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		var e := KitHelpers.ability(actor.creature_data, "E")
		var summary := String(e.get("summary", ""))
		var radius_units := KitHelpers.first_number(summary, 0.0)
		var debuff := 1.0 - KitHelpers.first_percent(summary, 0.0)
		var duration := KitHelpers.nth_number(summary, 2, 0.0)
		Aura.apply(actor, radius_units * SimConstants.UNIT_PX, duration, {}, {"damage_dealt_mult": debuff, "move_speed_mult": debuff}, "Cree")
		actor.e_timer = KitHelpers.cooldown_seconds(e)
