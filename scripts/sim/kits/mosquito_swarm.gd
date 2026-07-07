extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const MosquitoProjectileScript := preload("res://scripts/sim/entities/mosquito_projectile.gd")
const MosquitoFieldScript := preload("res://scripts/sim/entities/mosquito_field.gd")

const BLOOD_MAX := 100.0
const DEPOSIT_FULL_HEAL := 50.0
const DEPOSIT_RANGE_UNITS := 1.0
const CONTACT_DPS := 10.0
const CONTACT_BLOOD_MULT := 1.0
const CONTACT_HUNGER_MULT := 0.5
const TRAIL_SEC := 6.0
const TRAIL_FIELD_SEC := 3.0
const TRAIL_DROP_INTERVAL := 0.35
const TRAIL_FIELD_CAP := 14
const TOTAL_FIELD_CAP := 20
const MISS_CHANCE := 0.09

var trail_timer := 0.0
var trail_drop_timer := 0.0
var base_body_radius := 0.0
var fields: Array[Node] = []
var projectiles: Array[Node] = []

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.secondary_resource_label = "BLOOD"
	actor.secondary_resource_max = BLOOD_MAX
	actor.secondary_resource = 0.0
	base_body_radius = actor.body_radius
	trail_timer = 0.0
	trail_drop_timer = 0.0
	fields.clear()
	projectiles.clear()

func reset_for_respawn(actor: Node) -> void:
	_retire_all()
	actor.secondary_resource = 0.0
	if base_body_radius > 0.0:
		actor.body_radius = base_body_radius
	trail_timer = 0.0
	trail_drop_timer = 0.0

func tick(actor: Node, delta: float) -> void:
	_prune()
	_update_body_radius(actor)
	_tick_contact(actor, delta)
	_tick_trail(actor, delta)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_fire_primary(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0 and trail_timer <= 0.0:
		_start_trail(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		_deposit(actor)

func modify_incoming_damage(actor: Node, event: Resource, amount: float) -> float:
	if event.delivery != DamageEventScript.DELIVERY_RANGED:
		return amount
	if event.source_actor == actor:
		return amount
	if _miss_roll(actor):
		if actor.has_method("emit_vfx_event"):
			actor.emit_vfx_event("attack_dodged", {"target": actor, "position": actor.global_position, "source_ability": "Unswattable"})
		return 0.0
	return amount

func record_blood_gain(actor: Node, amount: float) -> void:
	if amount <= 0.0:
		return
	actor.secondary_resource = minf(actor.secondary_resource + amount, actor.secondary_resource_max)

func spawn_mosquito_field(actor: Node, position: Vector2, duration: float) -> void:
	if actor == null or actor.arena == null:
		return
	_prune()
	while fields.size() >= TOTAL_FIELD_CAP:
		var old: Node = fields.pop_front()
		if old != null and is_instance_valid(old) and old.has_method("retire"):
			old.retire()
	var field = MosquitoFieldScript.new()
	actor.arena.add_child(field)
	field.setup(actor.arena, actor, self, position, duration)
	fields.append(field)

func _fire_primary(actor: Node) -> void:
	if actor.arena == null:
		return
	var projectile = MosquitoProjectileScript.new()
	actor.arena.add_child(projectile)
	var range_px := KitHelpers.range_units(actor.stats, 7.0) * SimConstants.UNIT_PX
	actor.emit_vfx_event("attack_swung", {"actor": actor, "position": actor.global_position, "aim": actor.get_aim_direction(), "reach_px": range_px, "source_ability": "Piercing Swarm"})
	projectile.setup(actor.arena, actor, self, actor.global_position + actor.get_aim_direction() * (actor.body_radius + 4.0), actor.get_aim_direction(), range_px)
	projectiles.append(projectile)
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 1.1)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _start_trail(actor: Node) -> void:
	trail_timer = TRAIL_SEC
	trail_drop_timer = 0.0

func _tick_trail(actor: Node, delta: float) -> void:
	if trail_timer <= 0.0:
		return
	trail_timer = maxf(trail_timer - delta, 0.0)
	if actor.last_move_displacement_px <= 0.1:
		if trail_timer <= 0.0:
			_finish_trail(actor)
		return
	trail_drop_timer = maxf(trail_drop_timer - delta, 0.0)
	if trail_drop_timer <= 0.0:
		spawn_mosquito_field(actor, actor.global_position, TRAIL_FIELD_SEC)
		trail_drop_timer = TRAIL_DROP_INTERVAL
		_cap_trail_fields()
	if trail_timer <= 0.0:
		_finish_trail(actor)

func _finish_trail(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	actor.q_timer = float(q.get("cooldown_after_trail_ends_sec", 10.0))

func _cap_trail_fields() -> void:
	while fields.size() > TRAIL_FIELD_CAP:
		var old: Node = fields.pop_front()
		if old != null and is_instance_valid(old) and old.has_method("retire"):
			old.retire()

func _tick_contact(actor: Node, delta: float) -> void:
	if actor.arena == null:
		return
	for entity in actor.arena.entities:
		if not TargetFilter.is_live_damage_target(actor, entity, {"require_damage_api": true}):
			continue
		if entity.global_position.distance_to(actor.global_position) > actor.body_radius + entity.body_radius:
			continue
		var before: float = entity.health if "health" in entity else 0.0
		entity.take_damage_event(actor.make_damage_event(CONTACT_DPS * delta, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Unswattable Contact"))
		var dealt: float = maxf(before - float(entity.health if "health" in entity else before), 0.0)
		if dealt > 0.0:
			record_blood_gain(actor, dealt * CONTACT_BLOOD_MULT)
			actor.hunger = minf(actor.hunger + dealt * CONTACT_HUNGER_MULT, 100.0)

func _deposit(actor: Node) -> void:
	if actor.secondary_resource <= 0.0 or actor.arena == null:
		return
	var ally := _deposit_ally(actor)
	if ally == null:
		return
	var ratio := clampf(actor.secondary_resource / maxf(actor.secondary_resource_max, 1.0), 0.0, 1.0)
	ally.heal(DEPOSIT_FULL_HEAL * ratio)
	actor.secondary_resource = 0.0
	actor.e_timer = KitHelpers.cooldown_seconds(KitHelpers.ability(actor.creature_data, "E"))

func _deposit_ally(actor: Node) -> Node:
	var radius_px := DEPOSIT_RANGE_UNITS * SimConstants.UNIT_PX
	var best: Node = null
	var best_missing := 0.0
	for entity in actor.arena.entities:
		if entity == actor or not TargetFilter.is_live_ally_target(actor, entity, {"require_method": "heal", "allow_self": false}):
			continue
		if entity.global_position.distance_to(actor.global_position) > radius_px + entity.body_radius:
			continue
		var missing := float(entity.max_health) - float(entity.health) if "max_health" in entity and "health" in entity else 0.0
		if missing > best_missing:
			best = entity
			best_missing = missing
	return best

func _miss_roll(actor: Node) -> bool:
	if actor.arena != null and "match_rng" in actor.arena:
		return actor.arena.match_rng.randf() < MISS_CHANCE
	var fallback := RandomNumberGenerator.new()
	fallback.seed = int(actor.global_position.length_squared()) + 17
	return fallback.randf() < MISS_CHANCE

func _update_body_radius(actor: Node) -> void:
	if base_body_radius <= 0.0:
		base_body_radius = actor.body_radius
	var health_ratio := clampf(actor.health / maxf(actor.max_health, 1.0), 0.0, 1.0)
	actor.body_radius = base_body_radius * lerpf(0.78, 1.0, health_ratio)

func _prune() -> void:
	_prune_list(fields)
	_prune_list(projectiles)

func _prune_list(list: Array[Node]) -> void:
	for i in range(list.size() - 1, -1, -1):
		if list[i] == null or not is_instance_valid(list[i]):
			list.remove_at(i)
		elif list[i].has_method("is_alive") and not list[i].is_alive():
			list.remove_at(i)

func _retire_all() -> void:
	for list in [fields, projectiles]:
		for node in list:
			if node != null and is_instance_valid(node):
				if node.has_method("retire"):
					node.retire()
				else:
					node.queue_free()
		list.clear()
