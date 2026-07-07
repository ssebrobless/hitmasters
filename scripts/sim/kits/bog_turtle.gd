extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Charges := preload("res://scripts/sim/abilities/charges.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const BogTurtleFlowerScript := preload("res://scripts/sim/entities/bog_turtle_flower.gd")

const PRIMARY_SELF_DAMAGE := 2.0
const BASKING_RADIUS_UNITS := 1.5
const BASKING_REFRESH_SEC := 0.24
const BASKING_DAMAGE_BUFF := 1.02
const BASKING_ALLY_HEAL := 20.0
const DEFAULT_ATTACK_INTERVAL_SEC := 1.0
const MAX_FLOWERS := 3

var q_charges := Charges.new()
var e_charges := Charges.new()
var basking_ally: Node = null
var flowers: Array[Node] = []

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var e := KitHelpers.ability(actor.creature_data, "E")
	q_charges.setup(int(q.get("charges", 2)), KitHelpers.cooldown_seconds(q))
	e_charges.setup(int(e.get("charges", 2)), KitHelpers.cooldown_seconds(e))
	actor.q_charges = q_charges.charges
	actor.e_charges = e_charges.charges
	basking_ally = null
	flowers.clear()

func reset_for_respawn(actor: Node) -> void:
	_retire_all()
	q_charges.setup(q_charges.max_charges, q_charges.recharge_seconds)
	e_charges.setup(e_charges.max_charges, e_charges.recharge_seconds)
	actor.q_charges = q_charges.charges
	actor.e_charges = e_charges.charges
	basking_ally = null

func tick(actor: Node, delta: float) -> void:
	_prune()
	q_charges.tick(actor.get_ability_delta(delta) if actor.has_method("get_ability_delta") else delta)
	e_charges.tick(actor.get_ability_delta(delta) if actor.has_method("get_ability_delta") else delta)
	actor.q_charges = q_charges.charges
	actor.e_charges = e_charges.charges
	_update_basking(actor)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_CONTEXT_ACTION):
		_try_start_basking(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_headbutt(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and q_charges.can_spend():
		_launch_flower(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and e_charges.can_spend() and _is_basking():
		_umbrella_effect(actor)

func _headbutt(actor: Node) -> void:
	var reach_px := KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX
	MeleeHit.hit(actor, reach_px, float(actor.stats.get("primary_damage", 2.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Headbutt", {"max_hits": 1})
	actor.take_damage_event(actor.make_damage_event(PRIMARY_SELF_DAMAGE, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Headbutt Recoil"))
	if _is_basking():
		basking_ally.heal(BASKING_ALLY_HEAL)
		basking_ally.add_modifier("Basking", {"damage_dealt_mult": BASKING_DAMAGE_BUFF}, 2.0)
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", DEFAULT_ATTACK_INTERVAL_SEC)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _launch_flower(actor: Node) -> void:
	if actor.arena == null or not q_charges.spend():
		return
	actor.q_charges = q_charges.charges
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var range_px := KitHelpers.first_number(String(q.get("summary", "")), 6.0) * SimConstants.UNIT_PX
	var aim_point: Vector2 = actor.input_frame.aim if actor.input_frame != null else actor.global_position + actor.get_aim_direction() * range_px
	var offset: Vector2 = aim_point - actor.global_position
	var position: Vector2 = actor.global_position + (offset.normalized() * minf(offset.length(), range_px) if offset != Vector2.ZERO else actor.get_aim_direction() * range_px)
	_prune()
	while flowers.size() >= MAX_FLOWERS:
		var old: Node = flowers.pop_front()
		if old != null and is_instance_valid(old) and old.has_method("retire"):
			old.retire()
	var flower: Node = BogTurtleFlowerScript.new()
	actor.arena.add_child(flower)
	flower.setup(actor.arena, actor, position)
	flowers.append(flower)

func _umbrella_effect(actor: Node) -> void:
	if not e_charges.spend():
		return
	actor.e_charges = e_charges.charges
	var missing: float = actor.max_health - actor.health
	actor.heal(missing)
	if _is_basking() and missing > 0.0:
		basking_ally.heal(missing)

func _try_start_basking(actor: Node) -> void:
	var ally := _nearest_large_ally(actor)
	if ally == null:
		return
	basking_ally = ally
	_update_basking(actor)

func _update_basking(actor: Node) -> void:
	if not _is_basking():
		basking_ally = null
		return
	var radius_px := BASKING_RADIUS_UNITS * SimConstants.UNIT_PX
	if basking_ally.global_position.distance_to(actor.global_position) > radius_px + actor.body_radius + basking_ally.body_radius:
		basking_ally = null
		return
	actor.add_modifier("Basking", {"damage_taken_mult": 0.05}, BASKING_REFRESH_SEC)

func _nearest_large_ally(actor: Node) -> Node:
	if actor.arena == null:
		return null
	var radius_px := BASKING_RADIUS_UNITS * SimConstants.UNIT_PX
	var best: Node = null
	var best_distance := INF
	for entity in actor.arena.entities:
		if entity == actor or not TargetFilter.is_live_ally_target(actor, entity, {"allow_self": false, "require_method": "heal"}):
			continue
		if float(entity.max_health) <= actor.max_health:
			continue
		var distance: float = entity.global_position.distance_to(actor.global_position)
		if distance <= radius_px + actor.body_radius + entity.body_radius and distance < best_distance:
			best = entity
			best_distance = distance
	return best

func _is_basking() -> bool:
	return basking_ally != null and is_instance_valid(basking_ally) and basking_ally.has_method("is_alive") and basking_ally.is_alive()

func _prune() -> void:
	for i in range(flowers.size() - 1, -1, -1):
		if flowers[i] == null or not is_instance_valid(flowers[i]):
			flowers.remove_at(i)
		elif flowers[i].has_method("is_alive") and not flowers[i].is_alive():
			flowers.remove_at(i)

func _retire_all() -> void:
	for flower in flowers:
		if flower != null and is_instance_valid(flower):
			if flower.has_method("retire"):
				flower.retire()
			else:
				flower.queue_free()
	flowers.clear()
