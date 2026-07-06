extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const PLUNGE_MOVE_UNITS := 2.0
const PLUNGE_BONUS_MULT := 1.3
const LOW_WINDOW_SEC := 0.7
const HOVER_SOURCE := "Hover"
const NEST_SOURCE := "Nest Chamber"

var moved_since_attack_px := 0.0
var hover_timer := 0.0
var nest_timer := 0.0

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	moved_since_attack_px = 0.0
	hover_timer = 0.0
	nest_timer = 0.0

func reset_for_respawn(actor: Node) -> void:
	moved_since_attack_px = 0.0
	hover_timer = 0.0
	nest_timer = 0.0
	actor.remove_modifiers_from_source(HOVER_SOURCE)
	actor.remove_modifiers_from_source(NEST_SOURCE)

func tick(actor: Node, delta: float) -> void:
	moved_since_attack_px += maxf(actor.last_move_displacement_px, 0.0)
	_tick_hover(actor, delta)
	_tick_nest(actor, delta)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.state == CreatureStateScript.State.BURROWED:
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_peck(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_start_hover(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		_start_nest(actor)

func _peck(actor: Node) -> void:
	var primary_data: Variant = actor.stats.get("primary_damage", {})
	var grounded_damage := 25.0
	var flying_damage := 35.0
	if primary_data is Dictionary:
		grounded_damage = float(primary_data.get("ground", grounded_damage))
		flying_damage = float(primary_data.get("flying", flying_damage))
	var airborne: bool = actor.state == CreatureStateScript.State.AIRBORNE or actor.state == CreatureStateScript.State.PERCHED
	var damage: float = flying_damage if airborne else grounded_damage
	var plunging := moved_since_attack_px >= PLUNGE_MOVE_UNITS * SimConstants.UNIT_PX
	if plunging:
		damage *= PLUNGE_BONUS_MULT
		if actor.has_method("begin_render_plunge"):
			actor.begin_render_plunge()
	MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX, damage, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_AIR if airborne else DamageEventScript.PLANE_GROUND, "Plunge" if plunging else "Peck", {"max_hits": 1})
	actor.open_low_window(LOW_WINDOW_SEC)
	moved_since_attack_px = 0.0
	var rate := float(actor.stats.get("attack_rate_per_sec", 0.85))
	actor.primary_timer = (1.0 / maxf(rate, 0.05)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _start_hover(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	hover_timer = KitHelpers.first_number(String(q.get("summary", "")), 4.0)
	actor.remove_modifiers_from_source(HOVER_SOURCE)
	actor.add_modifier(HOVER_SOURCE, {"move_speed_mult": 0.0}, hover_timer)
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.flight_time_remaining = actor.flight_time_max
	actor.q_timer = KitHelpers.cooldown_seconds(q)

func _tick_hover(actor: Node, delta: float) -> void:
	if hover_timer <= 0.0:
		return
	hover_timer = maxf(hover_timer - delta, 0.0)
	var moving: bool = actor.input_frame != null and actor.input_frame.move.length() > 0.05
	if moving:
		hover_timer = 0.0
		actor.remove_modifiers_from_source(HOVER_SOURCE)
		return
	if hover_timer <= 0.0:
		actor.remove_modifiers_from_source(HOVER_SOURCE)
		if actor.state == CreatureStateScript.State.AIRBORNE:
			actor.state = CreatureStateScript.State.NORMAL

func _start_nest(actor: Node) -> void:
	var e := KitHelpers.ability(actor.creature_data, "E")
	nest_timer = KitHelpers.first_number(String(e.get("summary", "")), 7.0)
	actor.remove_modifiers_from_source(HOVER_SOURCE)
	actor.remove_modifiers_from_source(NEST_SOURCE)
	hover_timer = 0.0
	actor.add_modifier(NEST_SOURCE, {
		"invulnerable": 2.0,
		"untargetable": 2.0,
		"move_speed_mult": 0.0
	}, nest_timer)
	actor.state = CreatureStateScript.State.BURROWED
	actor.velocity = Vector2.ZERO
	actor.e_timer = KitHelpers.cooldown_seconds(e)

func _tick_nest(actor: Node, delta: float) -> void:
	if nest_timer <= 0.0:
		return
	nest_timer = maxf(nest_timer - delta, 0.0)
	if nest_timer <= 0.0:
		actor.remove_modifiers_from_source(NEST_SOURCE)
		if actor.state == CreatureStateScript.State.BURROWED:
			actor.state = CreatureStateScript.State.NORMAL
