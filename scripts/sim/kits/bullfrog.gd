extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Dash := preload("res://scripts/sim/abilities/dash.gd")
const Charges := preload("res://scripts/sim/abilities/charges.gd")
const Knockback := preload("res://scripts/sim/abilities/knockback.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const CAMOUFLAGE_IDLE_SEC := 3.0
const CAMOUFLAGE_STEALTH_SEC := 9999.0
const LUNGE_IMPACT_REACH_UNITS := 3.0
const LUNGE_IMPACT_KNOCKBACK_UNITS := 1.0

var idle_camouflage_timer := 0.0
var lunge_active := false
var lunge_hit_done := false
var lunge_button_was_pressed := false
var lunge_charges := Charges.new()

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var e := KitHelpers.ability(actor.creature_data, "E")
	lunge_charges.setup(int(e.get("charges", 3)), KitHelpers.cooldown_seconds(e))
	actor.e_charges = lunge_charges.charges

func reset_for_respawn(actor: Node) -> void:
	idle_camouflage_timer = 0.0
	lunge_active = false
	lunge_hit_done = false
	lunge_button_was_pressed = false
	lunge_charges.setup(lunge_charges.max_charges, lunge_charges.recharge_seconds)
	actor.e_charges = lunge_charges.charges

func tick(actor: Node, delta: float) -> void:
	lunge_charges.tick(actor.get_ability_delta(delta) if actor.has_method("get_ability_delta") else delta)
	actor.e_charges = lunge_charges.charges
	_update_lunge(actor)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	var has_action: bool = _input_has_action(actor)

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_leap(actor)

	var lunge_pressed: bool = actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E)
	if lunge_pressed and not lunge_button_was_pressed and lunge_charges.can_spend() and not lunge_active:
		_start_lunge(actor)
	lunge_button_was_pressed = lunge_pressed

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_bite(actor)
	if not has_action:
		_update_camouflage(actor, delta)

func _bite(actor: Node) -> void:
	_break_camouflage_for_action(actor)
	var hits := MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 2.0) * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite")
	_try_swallow(actor, hits)
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 1.6)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _leap(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var stealthed: bool = actor.is_stealthed()
	var summary := String(q.get("summary", ""))
	var normal_units := KitHelpers.first_number(summary, 4.0)
	var stealth_units := KitHelpers.nth_number(summary, 1, 10.0)
	var distance_units := stealth_units if stealthed else normal_units
	var direction: Vector2 = actor.get_aim_direction()
	if not stealthed and actor.input_frame.move != Vector2.ZERO:
		direction = actor.input_frame.move.normalized()
	_break_camouflage_for_action(actor)
	actor.pass_obstacles_timer = 0.24
	Dash.start(actor, direction, distance_units * SimConstants.UNIT_PX, 0.24)
	actor.q_timer = KitHelpers.cooldown_seconds(q)

func _start_lunge(actor: Node) -> void:
	var e := KitHelpers.ability(actor.creature_data, "E")
	var distance_units := KitHelpers.first_number(String(e.get("summary", "")), 3.0)
	_break_camouflage_for_action(actor)
	lunge_charges.spend()
	actor.e_charges = lunge_charges.charges
	lunge_active = true
	lunge_hit_done = false
	Dash.start(actor, actor.get_aim_direction(), distance_units * SimConstants.UNIT_PX, 0.18)

func _update_lunge(actor: Node) -> void:
	if not lunge_active:
		return
	if actor.dash_timer > 0.0:
		return
	lunge_active = false
	if lunge_hit_done:
		return
	lunge_hit_done = true
	var hits := MeleeHit.hit(actor, LUNGE_IMPACT_REACH_UNITS * SimConstants.UNIT_PX, 15.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Lunge", {"allow_harvest": false})
	var knock_dir: Vector2 = actor.get_aim_direction()
	for hit in hits:
		if hit != null and is_instance_valid(hit):
			Knockback.apply(actor, hit, knock_dir, LUNGE_IMPACT_KNOCKBACK_UNITS * SimConstants.UNIT_PX)

func _try_swallow(actor: Node, hits: Array) -> void:
	for hit in hits:
		if hit == null or not is_instance_valid(hit) or not ("max_health" in hit) or not ("health" in hit):
			continue
		if float(hit.max_health) >= actor.max_health:
			continue
		if float(hit.health) / maxf(float(hit.max_health), 1.0) > 0.10:
			continue
		hit.take_damage_event(actor.make_damage_event(float(hit.max_health) * 10.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Swallow"))
		actor.heal(actor.max_health * 0.25)
		break

func _update_camouflage(actor: Node, delta: float) -> void:
	if _input_has_action(actor) or actor.input_frame.move.length() > 0.05:
		_break_camouflage_for_action(actor)
		return
	idle_camouflage_timer += delta
	if idle_camouflage_timer >= CAMOUFLAGE_IDLE_SEC and not actor.is_stealthed():
		actor.begin_stealth(CAMOUFLAGE_STEALTH_SEC, "Camouflage")

func _break_camouflage_for_action(actor: Node) -> void:
	idle_camouflage_timer = 0.0
	if actor.is_stealthed():
		actor.break_stealth()

func _input_has_action(actor: Node) -> bool:
	return actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) \
		or actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) \
		or actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E)
