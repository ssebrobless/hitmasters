extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Dash := preload("res://scripts/sim/abilities/dash.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const SpiderlingScript := preload("res://scripts/sim/pets/spiderling.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const BURROW_SOURCE := "Silk-lined Burrow"
const MAX_BURROWS := 4
const BURROW_CHARGE_UNITS := 4.0
const LUNGE_UNITS := 2.0
const BITE_REACH_UNITS := 1.0
const LUNGE_SEC := 0.16
const LATCH_REFRESH_SEC := 0.45
const LATCH_MAX_SEC := 3.0
const LATCH_SLOW_MULT := 0.55
const EGG_HATCH_SEC := 10.0
const MAX_SPIDERLINGS := 12
const BURROW_TRIGGER_UNITS := 2.0

var burrows: Array[Dictionary] = []
var active_burrow_index := -1
var lunge_active := false
var lunge_damage := 20.0
var latch_hold_remaining := 0.0
var egg_timer := 0.0
var spiderlings: Array[Node] = []
var trap_hatches: Array[Dictionary] = []

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	burrows.clear()
	trap_hatches.clear()
	spiderlings.clear()
	active_burrow_index = -1
	lunge_active = false
	latch_hold_remaining = 0.0
	egg_timer = 0.0

func reset_for_respawn(actor: Node) -> void:
	_exit_burrow(actor)
	_retire_spiderlings()
	burrows.clear()
	trap_hatches.clear()
	active_burrow_index = -1
	lunge_active = false
	latch_hold_remaining = 0.0
	egg_timer = 0.0

func tick(actor: Node, delta: float) -> void:
	_prune_spiderlings()
	_tick_latch(actor, delta)
	_tick_lunge(actor)
	_tick_eggs(actor, delta)
	_tick_traps(actor)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.state == CreatureStateScript.State.BURROWED:
		if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY):
			_charge_from_burrow(actor)
		elif actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0 and egg_timer <= 0.0:
			_start_eggs(actor)
		elif actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q):
			_exit_burrow(actor)
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0 and not lunge_active:
		_start_lunge(actor, actor.get_aim_direction(), "Bite")
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_enter_burrow(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0 and egg_timer <= 0.0:
		_start_eggs(actor)

func _start_lunge(actor: Node, direction: Vector2, source: String) -> void:
	lunge_active = true
	lunge_damage = float(actor.stats.get("primary_damage", 20.0))
	Dash.start(actor, direction, LUNGE_UNITS * SimConstants.UNIT_PX, LUNGE_SEC)
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.7)) / actor.get_modifier_value("attack_speed_mult", 1.0)
	if actor.has_method("emit_vfx_event"):
		actor.emit_vfx_event("windup_started", {"actor": actor, "position": actor.global_position, "aim": direction, "reach_px": BITE_REACH_UNITS * SimConstants.UNIT_PX, "duration": LUNGE_SEC, "source_ability": source})

func _tick_lunge(actor: Node) -> void:
	if not lunge_active or actor.dash_timer > 0.0:
		return
	lunge_active = false
	var hits := MeleeHit.hit(actor, BITE_REACH_UNITS * SimConstants.UNIT_PX, lunge_damage, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite", {"max_hits": 1})
	for hit in hits:
		if hit != null and is_instance_valid(hit) and hit.has_method("receive_latch"):
			Latch.start(actor, hit, LATCH_REFRESH_SEC, "Bite")
			latch_hold_remaining = LATCH_MAX_SEC
			_apply_latch_slow(hit)
			break

func _tick_latch(actor: Node, delta: float) -> void:
	if actor.latch_victim == null or not is_instance_valid(actor.latch_victim) or actor.latch_source != "Bite":
		return
	var held: bool = actor.input_frame != null and actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY)
	latch_hold_remaining = maxf(latch_hold_remaining - delta, 0.0)
	if held and latch_hold_remaining > 0.0:
		actor.latch_timer = maxf(actor.latch_timer, LATCH_REFRESH_SEC)
		actor.latch_victim.latch_timer = actor.latch_timer
		_apply_latch_slow(actor.latch_victim)
	else:
		actor.release_latch("primary_release")

func _apply_latch_slow(victim: Node) -> void:
	if victim != null and is_instance_valid(victim) and victim.has_method("add_modifier"):
		victim.remove_modifiers_from_source("Spider Latch Slow")
		victim.add_modifier("Spider Latch Slow", {"move_speed_mult": LATCH_SLOW_MULT}, LATCH_REFRESH_SEC + 0.05)

func _enter_burrow(actor: Node) -> void:
	_add_burrow(actor.global_position)
	active_burrow_index = burrows.size() - 1
	actor.add_modifier(BURROW_SOURCE, {"untargetable": 2.0, "invulnerable": 2.0, "move_speed_mult": 0.0}, 9999.0)
	actor.state = CreatureStateScript.State.BURROWED
	actor.velocity = Vector2.ZERO
	actor.q_timer = KitHelpers.cooldown_seconds(KitHelpers.ability(actor.creature_data, "Q"))

func _add_burrow(position: Vector2) -> void:
	burrows.append({"position": position})
	while burrows.size() > MAX_BURROWS:
		burrows.remove_at(0)
	active_burrow_index = clampi(active_burrow_index, -1, burrows.size() - 1)

func _exit_burrow(actor: Node) -> void:
	actor.remove_modifiers_from_source(BURROW_SOURCE)
	if actor.state == CreatureStateScript.State.BURROWED:
		actor.state = CreatureStateScript.State.NORMAL
	active_burrow_index = -1

func _charge_from_burrow(actor: Node) -> void:
	var origin := _active_burrow_position(actor)
	var target := _find_enemy_near(actor, origin, BURROW_CHARGE_UNITS * SimConstants.UNIT_PX)
	_exit_burrow(actor)
	actor.global_position = origin
	if target == null:
		return
	var direction: Vector2 = target.global_position - actor.global_position
	_start_lunge(actor, direction.normalized(), "Burrow Charge")

func _active_burrow_position(actor: Node) -> Vector2:
	if active_burrow_index >= 0 and active_burrow_index < burrows.size():
		return burrows[active_burrow_index].get("position", actor.global_position)
	return actor.global_position

func _find_enemy_near(actor: Node, point: Vector2, radius_px: float) -> Node:
	if actor.arena == null:
		return null
	var closest: Node = null
	var closest_distance := radius_px
	for entity in actor.arena.entities:
		if not TargetFilter.is_live_damage_target(actor, entity, {"require_damage_api": false}):
			continue
		var distance: float = point.distance_to(entity.global_position)
		if distance <= closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _start_eggs(actor: Node) -> void:
	egg_timer = EGG_HATCH_SEC
	if actor.has_method("emit_vfx_event"):
		actor.emit_vfx_event("windup_started", {"actor": actor, "position": actor.global_position, "aim": actor.get_aim_direction(), "reach_px": actor.body_radius, "duration": EGG_HATCH_SEC, "source_ability": "Epigamic Carrying"})

func _tick_eggs(actor: Node, delta: float) -> void:
	if egg_timer <= 0.0:
		return
	egg_timer = maxf(egg_timer - delta, 0.0)
	if egg_timer > 0.0:
		return
	var e := KitHelpers.ability(actor.creature_data, "E")
	actor.e_timer = float(e.get("cooldown_after_hatch_sec", 20.0))
	if actor.state == CreatureStateScript.State.BURROWED:
		trap_hatches.append({"position": _active_burrow_position(actor), "count": MAX_SPIDERLINGS})
	else:
		_hatch_spiderlings(actor, actor.global_position, MAX_SPIDERLINGS)

func _tick_traps(actor: Node) -> void:
	if trap_hatches.is_empty():
		return
	for i in range(trap_hatches.size() - 1, -1, -1):
		var trap: Dictionary = trap_hatches[i]
		var position: Vector2 = trap.get("position", actor.global_position)
		if _find_enemy_near(actor, position, BURROW_TRIGGER_UNITS * SimConstants.UNIT_PX) != null:
			_hatch_spiderlings(actor, position, int(trap.get("count", MAX_SPIDERLINGS)))
			trap_hatches.remove_at(i)

func _hatch_spiderlings(actor: Node, position: Vector2, requested_count: int) -> void:
	if actor.arena == null:
		return
	_prune_spiderlings()
	var to_hatch := mini(requested_count, MAX_SPIDERLINGS - spiderlings.size())
	for i in to_hatch:
		var spiderling = SpiderlingScript.new()
		actor.arena.add_child(spiderling)
		var angle := TAU * float(i) / maxf(float(to_hatch), 1.0)
		spiderling.setup(actor.arena, actor, actor.team, position + Vector2(cos(angle), sin(angle)) * 14.0)
		actor.arena.register_entity(spiderling)
		spiderlings.append(spiderling)

func _prune_spiderlings() -> void:
	for i in range(spiderlings.size() - 1, -1, -1):
		if spiderlings[i] == null or not is_instance_valid(spiderlings[i]):
			spiderlings.remove_at(i)
		elif spiderlings[i].has_method("is_alive") and not spiderlings[i].is_alive():
			spiderlings.remove_at(i)

func _retire_spiderlings() -> void:
	for spiderling in spiderlings:
		if spiderling != null and is_instance_valid(spiderling) and spiderling.has_method("retire"):
			spiderling.retire()
	spiderlings.clear()
