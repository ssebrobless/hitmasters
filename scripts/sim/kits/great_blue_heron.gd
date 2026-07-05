extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const Projectile := preload("res://scripts/sim/abilities/projectile.gd")
const Dash := preload("res://scripts/sim/abilities/dash.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0

func tick(actor: Node, _delta: float) -> void:
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_spear(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_powder_puff(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		_flushing(actor)

func _spear(actor: Node) -> void:
	if actor.state == CreatureStateScript.State.AIRBORNE or actor.state == CreatureStateScript.State.PERCHED:
		return
	var range_px := KitHelpers.range_units(actor.stats, 3.0) * SimConstants.UNIT_PX
	Projectile.instant_line(actor, range_px, float(actor.stats.get("primary_damage", 55.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Spear", {
		"half_width_px": SimConstants.UNIT_PX * 0.5
	})
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 1.4)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _powder_puff(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var duration := KitHelpers.first_number(String(q.get("summary", "")), 2.0)
	if actor.has_method("cleanse_negative_modifiers"):
		actor.cleanse_negative_modifiers()
	actor.add_modifier("Powder Puff", {"cc_immune": 2.0}, duration)
	actor.q_timer = KitHelpers.cooldown_seconds(q)

func _flushing(actor: Node) -> void:
	if actor.state == CreatureStateScript.State.AIRBORNE or actor.state == CreatureStateScript.State.PERCHED:
		return
	var e := KitHelpers.ability(actor.creature_data, "E")
	var distance_units := KitHelpers.first_number(String(e.get("summary", "")), 2.0)
	Dash.start(actor, actor.get_aim_direction(), distance_units * SimConstants.UNIT_PX, 0.18)
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.flight_time_remaining = actor.flight_time_max
	actor.flight_toggle_requires_release = true
	actor.e_timer = KitHelpers.cooldown_seconds(e)
