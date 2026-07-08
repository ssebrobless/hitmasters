extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const LeechProjectileScript := preload("res://scripts/sim/entities/leech_projectile.gd")

const CLUSTER_MAX := 20.0
const ATTACH_DPS := 10.0
const PRIMARY_LATCH_SEC := 3.0
const CRYPT_LATCH_SEC := 6.0
const COPULATION_MAX_CHANNEL_SEC := 5.0
const COPULATION_SPAWN_INTERVAL_SEC := 1.0
const DEFAULT_ATTACK_INTERVAL_SEC := 0.7

var copulation_timer := 0.0
var copulation_spawn_timer := 0.0
var projectiles: Array[Node] = []

func setup(actor: Node) -> void:
	actor.max_health = CLUSTER_MAX
	actor.health = CLUSTER_MAX
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.secondary_resource_label = "LEECHES"
	actor.secondary_resource_max = CLUSTER_MAX
	_sync_cluster_resource(actor)
	copulation_timer = 0.0
	copulation_spawn_timer = 0.0
	projectiles.clear()

func reset_for_respawn(actor: Node) -> void:
	_retire_all()
	actor.max_health = CLUSTER_MAX
	actor.health = CLUSTER_MAX
	_sync_cluster_resource(actor)
	copulation_timer = 0.0
	copulation_spawn_timer = 0.0

func tick(actor: Node, delta: float) -> void:
	_prune()
	_sync_cluster_resource(actor)
	_tick_copulation(actor, delta)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_fire_primary(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0 and copulation_timer <= 0.0:
		_start_copulation(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		_sensory_crypt(actor)

func modify_incoming_damage(_actor: Node, _event: Resource, amount: float) -> float:
	return 1.0 if amount > 0.0 else 0.0

func on_damage_taken(actor: Node, _event: Resource, _amount: float, _before_health: float) -> void:
	_sync_cluster_resource(actor)

func attach_leech(actor: Node, target: Node, duration: float, source_ability: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_dot"):
		target.apply_dot(actor, source_ability, ATTACH_DPS * duration, duration)
	if target.has_method("add_modifier"):
		target.add_modifier(source_ability, {"revealed": 2.0}, duration)
	if actor.arena != null and actor.arena.has_method("reveal_entity_to_team"):
		actor.arena.reveal_entity_to_team(target, int(actor.team), duration)
	if actor.has_method("emit_vfx_event"):
		actor.emit_vfx_event("latch_started", {"attacker": actor, "victim": target, "duration": duration, "source_ability": source_ability})

func _fire_primary(actor: Node) -> void:
	if actor.arena == null or not _spend_leeches(actor, 1.0):
		return
	var projectile: Node = LeechProjectileScript.new()
	actor.arena.add_child(projectile)
	var range_px := KitHelpers.range_units(actor.stats, 7.0) * SimConstants.UNIT_PX
	var start: Vector2 = actor.global_position + actor.get_aim_direction() * (actor.body_radius + 4.0)
	actor.emit_vfx_event("attack_swung", {"actor": actor, "position": actor.global_position, "aim": actor.get_aim_direction(), "reach_px": range_px, "source_ability": "Leech Projectile"})
	projectile.setup(actor.arena, actor, self, start, actor.get_aim_direction(), range_px)
	projectiles.append(projectile)
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", DEFAULT_ATTACK_INTERVAL_SEC)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _start_copulation(actor: Node) -> void:
	copulation_timer = COPULATION_MAX_CHANNEL_SEC
	copulation_spawn_timer = 0.0
	actor.q_timer = 0.2

func _tick_copulation(actor: Node, delta: float) -> void:
	if copulation_timer <= 0.0:
		return
	var has_action: bool = actor.input_frame != null and (
		actor.input_frame.move.length() > 0.05
		or actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY)
		or actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E)
	)
	if has_action or actor.health >= actor.max_health:
		_finish_copulation(actor)
		return
	copulation_timer = maxf(copulation_timer - delta, 0.0)
	copulation_spawn_timer -= delta
	if copulation_spawn_timer <= 0.0:
		actor.heal(1.0)
		_sync_cluster_resource(actor)
		copulation_spawn_timer = COPULATION_SPAWN_INTERVAL_SEC
	if copulation_timer <= 0.0:
		_finish_copulation(actor)

func _finish_copulation(actor: Node) -> void:
	copulation_timer = 0.0
	copulation_spawn_timer = 0.0
	actor.q_timer = KitHelpers.cooldown_seconds(KitHelpers.ability(actor.creature_data, "Q"))

func _sensory_crypt(actor: Node) -> void:
	if actor.arena == null or not _is_in_water(actor):
		return
	var actor_water_body: int = _water_body_id(actor)
	if actor_water_body < 0:
		return
	var hits := 0
	for entity in actor.arena.entities:
		if not TargetFilter.is_live_damage_target(actor, entity, {"allow_stealthed": true, "require_damage_api": true}):
			continue
		if _water_body_id(entity) != actor_water_body:
			continue
		if not _spend_leeches(actor, 1.0):
			break
		attach_leech(actor, entity, CRYPT_LATCH_SEC, "Sensory Crypt")
		hits += 1
	if hits > 0:
		actor.e_timer = KitHelpers.cooldown_seconds(KitHelpers.ability(actor.creature_data, "E"))

func _is_in_water(actor: Node) -> bool:
	return _water_body_id(actor) >= 0

func _water_body_id(actor: Node) -> int:
	if actor == null or actor.get("terrain_map") == null:
		return -1
	var terrain_map: RefCounted = actor.get("terrain_map")
	if terrain_map.has_method("get_water_body_id_at"):
		return int(terrain_map.get_water_body_id_at(actor.global_position))
	if terrain_map.has_method("get_zone_at") and terrain_map.get_zone_at(actor.global_position) == TerrainMapScript.WATER:
		return 0
	return -1

func _spend_leeches(actor: Node, amount: float) -> bool:
	if actor.health <= amount:
		return false
	actor.health = maxf(actor.health - amount, 1.0)
	_sync_cluster_resource(actor)
	return true

func _sync_cluster_resource(actor: Node) -> void:
	actor.secondary_resource_max = actor.max_health
	actor.secondary_resource = clampf(actor.health, 0.0, actor.max_health)

func _prune() -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		if projectiles[i] == null or not is_instance_valid(projectiles[i]):
			projectiles.remove_at(i)
		elif projectiles[i].has_method("is_alive") and not projectiles[i].is_alive():
			projectiles.remove_at(i)

func _retire_all() -> void:
	for projectile in projectiles:
		if projectile != null and is_instance_valid(projectile):
			if projectile.has_method("retire"):
				projectile.retire()
			else:
				projectile.queue_free()
	projectiles.clear()
