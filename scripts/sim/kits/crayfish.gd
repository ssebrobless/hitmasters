extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Dash := preload("res://scripts/sim/abilities/dash.gd")
const Charges := preload("res://scripts/sim/abilities/charges.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const MERAL_SIZE_MULT := 1.3
const MERAL_SPEED_MULT := 1.05
const MERAL_DAMAGE_TAKEN_MULT := 0.7
const MOLT_INTERVAL_SEC := 30.0
const MOLT_WINDOW_SEC := 1.0
const MOLT_DR_MULT := 0.98
const MOLT_VULNERABLE_MULT := 1.12
const MOLT_MAX_STACKS := 5

var escape_charges := Charges.new()
var left_claw_next := false
var meral_timer := 0.0
var base_body_radius := 0.0
var molt_timer := 0.0
var molt_window_timer := 0.0
var molt_stacks := 0

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var q := KitHelpers.ability(actor.creature_data, "Q")
	escape_charges.setup(int(q.get("charges", 3)), KitHelpers.cooldown_seconds(q))
	actor.q_charges = escape_charges.charges
	base_body_radius = actor.body_radius
	meral_timer = 0.0
	molt_timer = MOLT_INTERVAL_SEC
	molt_window_timer = 0.0
	molt_stacks = 0

func reset_for_respawn(actor: Node) -> void:
	_restore_meral(actor)
	left_claw_next = false
	escape_charges.setup(escape_charges.max_charges, escape_charges.recharge_seconds)
	actor.q_charges = escape_charges.charges
	molt_timer = MOLT_INTERVAL_SEC
	molt_window_timer = 0.0
	molt_stacks = 0

func tick(actor: Node, delta: float) -> void:
	escape_charges.tick(actor.get_ability_delta(delta) if actor.has_method("get_ability_delta") else delta)
	actor.q_charges = escape_charges.charges
	_tick_meral(actor, delta)
	_tick_molting(actor, delta)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_pinch(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and escape_charges.can_spend():
		_escape(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0 and meral_timer <= 0.0:
		_start_meral(actor)

func _pinch(actor: Node) -> void:
	var source := "Left Claw" if left_claw_next else "Right Claw"
	left_claw_next = not left_claw_next
	var reach_px := KitHelpers.range_units(actor.stats, 1.5) * SimConstants.UNIT_PX
	MeleeHit.hit(actor, reach_px, float(actor.stats.get("primary_damage", 20.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, source, {"max_hits": 1})
	var rate := float(actor.stats.get("attack_rate_per_sec", 0.85))
	actor.primary_timer = (1.0 / maxf(rate, 0.05)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _escape(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var summary := String(q.get("summary", ""))
	var dash_units := KitHelpers.first_number(summary, 3.0)
	var front_reach_units := KitHelpers.nth_number(summary, 1, 1.0)
	var smack_damage := KitHelpers.nth_number(summary, 2, 20.0)
	var aim: Vector2 = actor.get_aim_direction()
	if actor.has_method("begin_render_escape_curl"):
		actor.begin_render_escape_curl()
	MeleeHit.hit(actor, front_reach_units * SimConstants.UNIT_PX, smack_damage, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Caridoid Escape", {"max_hits": 1, "allow_harvest": false})
	Dash.start(actor, -aim, dash_units * SimConstants.UNIT_PX, 0.22)
	escape_charges.spend()
	actor.q_charges = escape_charges.charges

func _start_meral(actor: Node) -> void:
	var e := KitHelpers.ability(actor.creature_data, "E")
	meral_timer = KitHelpers.first_number(String(e.get("summary", "")), 10.0)
	base_body_radius = actor.body_radius
	actor.body_radius = base_body_radius * MERAL_SIZE_MULT
	actor.state = CreatureStateScript.State.STANCE
	actor.add_modifier("Meral Display", {
		"forward_back_only": 2.0,
		"move_speed_mult": MERAL_SPEED_MULT,
		"damage_taken_mult": MERAL_DAMAGE_TAKEN_MULT
	}, meral_timer)
	actor.e_timer = KitHelpers.cooldown_seconds(e)

func _tick_meral(actor: Node, delta: float) -> void:
	if meral_timer <= 0.0:
		return
	meral_timer = maxf(meral_timer - delta, 0.0)
	if meral_timer <= 0.0:
		_restore_meral(actor)

func _restore_meral(actor: Node) -> void:
	if base_body_radius > 0.0:
		actor.body_radius = base_body_radius
	if actor.state == CreatureStateScript.State.STANCE:
		actor.state = CreatureStateScript.State.NORMAL
	meral_timer = 0.0

func _tick_molting(actor: Node, delta: float) -> void:
	if molt_stacks >= MOLT_MAX_STACKS:
		return
	if molt_window_timer > 0.0:
		molt_window_timer = maxf(molt_window_timer - delta, 0.0)
		if molt_window_timer <= 0.0:
			molt_stacks += 1
			actor.add_modifier("Molting", {"damage_taken_mult": MOLT_DR_MULT}, 999999.0)
			molt_timer = MOLT_INTERVAL_SEC
		return
	molt_timer = maxf(molt_timer - delta, 0.0)
	if molt_timer <= 0.0:
		molt_window_timer = MOLT_WINDOW_SEC
		actor.add_modifier("Molt Vulnerable", {"damage_taken_mult": MOLT_VULNERABLE_MULT}, MOLT_WINDOW_SEC)
