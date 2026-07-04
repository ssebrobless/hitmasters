extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureCatalogScript := preload("res://scripts/data/creature_catalog.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")
const MinionScript := preload("res://scripts/game/minion.gd")
const CoreScript := preload("res://scripts/game/core.gd")

class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var cores := {}
	var dams: Array[Node] = []
	var core_damage_records: Array[Dictionary] = []
	var terrain := TerrainMapScript.new()
	var hut_counts := {0: 0, 1: 0}

	func _init() -> void:
		terrain.configure("3v3")

	func register_entity(entity: Node) -> void:
		if not entities.has(entity):
			entities.append(entity)

	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)

	func register_dam(dam: Node) -> void:
		if not dams.has(dam):
			dams.append(dam)
		register_entity(dam)

	func unregister_dam(dam: Node) -> void:
		dams.erase(dam)
		unregister_entity(dam)

	func get_terrain_zone(_point: Vector2) -> String:
		return TerrainMapScript.LAND

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func clamp_to_arena(point: Vector2) -> Vector2:
		return point

	func record_death(_victim: Node, _killer: Node = null) -> void:
		pass

	func record_vfx_event(_event: Dictionary) -> void:
		pass

	func get_closest_enemy(_source: Node, _max_distance: float) -> Node:
		return null

	func get_steering_direction(from: Vector2, to: Vector2, _radius: float, _team: int) -> Vector2:
		return (to - from).normalized()

	func get_enemy_core(attacking_team: int) -> Node:
		return cores.get(1 - attacking_team, null)

	func get_lane_destination(attacking_team: int, lane_anchor: Vector2) -> Vector2:
		var core: Node = get_enemy_core(attacking_team)
		return core.global_position if core != null and can_damage_core(core.team) else lane_anchor

	func can_damage_core(defending_team: int) -> bool:
		return int(hut_counts.get(defending_team, 0)) <= 0

	func get_core_damage_multiplier(_team: int) -> float:
		return 1.0

	func record_core_damage(source_team: int, amount: float, source_actor: Node = null) -> void:
		core_damage_records.append({"team": source_team, "amount": amount, "source": source_actor})

class ProjectileArena extends FakeArena:
	func is_inside_arena(_point: Vector2) -> bool:
		return true

	func resolve_projectile_hits(projectile: Node) -> void:
		for entity in entities:
			if entity == null or not is_instance_valid(entity):
				continue
			if entity.team == projectile.team or projectile.hit_entities.has(entity):
				continue
			if entity.global_position.distance_to(projectile.global_position) <= projectile.radius + entity.body_radius:
				if entity.has_method("take_damage_event"):
					var event := DamageEventScript.new()
					event.setup(projectile.damage, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, projectile.source_actor, "projectile")
					entity.take_damage_event(event)
				else:
					entity.take_damage(projectile.damage, projectile.team, projectile.source_actor)
				projectile.hit_entities.append(entity)
				if not projectile.pierce:
					projectile.queue_free()
					return

func _initialize() -> void:
	_ensure_catalog()

	var failures: Array[String] = []
	var beaver_ok: bool = _check_beaver_dam_hp(failures)
	var frog_ok: bool = _check_chorus_frog_cree_duration(failures)
	var projectile_ok: bool = _check_projectile_ranged_spike(failures)
	var lure_ok: bool = _check_turtle_lure_self_lock(failures)
	var choke_ok: bool = _check_mink_choke_once_and_cooldown(failures)
	var minion_ok: bool = _check_minion_core_damage_after_huts(failures)
	var passed: bool = beaver_ok and frog_ok and projectile_ok and lure_ok and choke_ok and minion_ok

	print("audit_fix beaver_dam=%s frog_cree=%s projectile_spike=%s turtle_lure=%s mink_choke=%s minion_core=%s" % [
		str(beaver_ok),
		str(frog_ok),
		str(projectile_ok),
		str(lure_ok),
		str(choke_ok),
		str(minion_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _ensure_catalog() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null:
		catalog = CreatureCatalogScript.new()
		catalog.name = "CreatureCatalog"
		get_root().add_child(catalog)
	catalog.load_catalog()

func _check_beaver_dam_hp(failures: Array[String]) -> bool:
	var arena := _arena()
	var beaver := _creature(arena, "beaver", 0, Vector2(-300.0, -120.0))
	beaver.set_input_frame(_frame(Vector2.ZERO, beaver.global_position + Vector2.RIGHT * 64.0, InputFrameScript.BUTTON_ABILITY_E))
	beaver.tick_sim(SimConstants.TICK_DELTA)

	var dam: Node = arena.dams[0] if arena.dams.size() > 0 else null
	var ok := dam != null and absf(dam.max_health - 200.0) < 0.001 and absf(dam.health - 200.0) < 0.001
	if not ok:
		failures.append("beaver_dam expected one 200 HP dam, got count=%d hp=%s max=%s" % [
			arena.dams.size(),
			str(dam.health if dam != null else null),
			str(dam.max_health if dam != null else null)
		])
	return ok

func _check_chorus_frog_cree_duration(failures: Array[String]) -> bool:
	var arena := _arena()
	var frog := _creature(arena, "chorus_frog", 0, Vector2(-200.0, -60.0))
	var enemy := _creature(arena, "mink", 1, Vector2(-170.0, -60.0))
	frog.set_input_frame(_frame(Vector2.ZERO, enemy.global_position, InputFrameScript.BUTTON_ABILITY_E))
	frog.tick_sim(SimConstants.TICK_DELTA)

	var duration: float = _modifier_remaining(enemy, "Cree")
	var damage_mult: float = enemy.get_modifier_value("damage_dealt_mult", 1.0)
	var speed_mult: float = enemy.get_modifier_value("move_speed_mult", 1.0)
	var ok: bool = absf(duration - 6.0) < 0.001 and absf(damage_mult - 0.9) < 0.001 and absf(speed_mult - 0.9) < 0.001
	if not ok:
		failures.append("frog_cree expected 6s 0.9/0.9 debuff, got duration=%.3f damage=%.3f speed=%.3f" % [
			duration,
			damage_mult,
			speed_mult
		])
	return ok

func _check_projectile_ranged_spike(failures: Array[String]) -> bool:
	var source_ok: bool = _arena_source_uses_ranged_projectile()
	var light_target := _projectile_target("owl", Vector2(320.0, 220.0))
	_fire_arena_projectile_at(light_target, 20.0)
	var light_hit: bool = absf(light_target.health - (light_target.max_health - 20.0)) < 0.001
	var light_not_spiked: bool = light_target.state == CreatureStateScript.State.AIRBORNE and light_target.flight_grounded_timer <= 0.0

	var heavy_target := _projectile_target("owl", Vector2(380.0, 220.0))
	_fire_arena_projectile_at(heavy_target, 35.0)
	var heavy_hit: bool = absf(heavy_target.health - (heavy_target.max_health - 35.0)) < 0.001
	var heavy_spiked: bool = heavy_target.state == CreatureStateScript.State.NORMAL and heavy_target.flight_grounded_timer > 2.9

	var always_target := _projectile_target("mosquito_swarm", Vector2(440.0, 220.0))
	_fire_arena_projectile_at(always_target, 35.0)
	var always_not_spiked: bool = always_target.state == CreatureStateScript.State.AIRBORNE and always_target.flight_grounded_timer <= 0.0

	var ok: bool = source_ok and light_hit and light_not_spiked and heavy_hit and heavy_spiked and always_not_spiked
	if not ok:
		failures.append("projectile_spike expected arena source plus ranged hits and only heavy non-always-flying spike; source=%s light hp/state=%s/%s heavy hp/state/timer=%s/%s/%.3f always state/timer=%s/%.3f" % [
			str(source_ok),
			str(light_target.health),
			str(light_target.state),
			str(heavy_target.health),
			str(heavy_target.state),
			heavy_target.flight_grounded_timer,
			str(always_target.state),
			always_target.flight_grounded_timer
		])
	return ok

func _check_turtle_lure_self_lock(failures: Array[String]) -> bool:
	var arena := _arena()
	var turtle := _creature(arena, "snapping_turtle", 0, Vector2(-260.0, 80.0))
	var enemy := _creature(arena, "mink", 1, Vector2(-244.0, 80.0))
	turtle.set_input_frame(_frame(Vector2.ZERO, enemy.global_position, InputFrameScript.BUTTON_ABILITY_E))
	turtle.tick_sim(SimConstants.TICK_DELTA)

	var self_locked: bool = not turtle.can_act()
	var enemy_stunned: bool = not enemy.can_act() and absf(enemy.get_modifier_value("move_speed_mult", 1.0)) < 0.001
	var speed_allowed: bool = absf(turtle.get_modifier_value("move_speed_mult", 1.0) - 1.0) < 0.001
	var start: Vector2 = turtle.global_position
	_tick(turtle, _frame(Vector2.RIGHT, enemy.global_position, InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_Q), 0.12)
	var moved: bool = turtle.global_position.distance_to(start) > 1.0
	var no_primary: bool = absf(turtle.kit.primary_windup_remaining) < 0.001 and turtle.primary_timer <= 0.001
	var no_q_arm: bool = not turtle.kit.grab_armed and turtle.q_timer <= 0.001

	var ok: bool = self_locked and enemy_stunned and speed_allowed and moved and no_primary and no_q_arm
	if not ok:
		failures.append("turtle_lure expected self action lock plus movement; self_locked=%s enemy_stunned=%s speed_allowed=%s moved=%s no_primary=%s no_q=%s" % [
			str(self_locked),
			str(enemy_stunned),
			str(speed_allowed),
			str(moved),
			str(no_primary),
			str(no_q_arm)
		])
	return ok

func _check_mink_choke_once_and_cooldown(failures: Array[String]) -> bool:
	var arena := _arena()
	var mink := _creature(arena, "mink", 0, Vector2(-120.0, 130.0))
	var victim := _creature(arena, "chorus_frog", 1, Vector2(-102.0, 130.0))
	var aim: Vector2 = mink.global_position + Vector2.RIGHT * 80.0
	mink.set_input_frame(_frame(Vector2.ZERO, aim, InputFrameScript.BUTTON_ABILITY_Q))
	mink.tick_sim(SimConstants.TICK_DELTA)
	mink.set_input_frame(_frame(Vector2.ZERO, aim, 0))
	mink.tick_sim(SimConstants.TICK_DELTA)

	var after_hit_health: float = victim.health
	var latched: bool = mink.latch_victim == victim and victim.latched_attacker == mink
	var one_hit: bool = absf(after_hit_health - (victim.max_health - 20.0)) < 0.001
	var q_after_hit: float = mink.q_timer
	var q_held_while_latched: bool = q_after_hit >= 0.19
	_tick(mink, _frame(Vector2.ZERO, aim, 0), 0.55)
	var no_aura_damage: bool = absf(victim.health - after_hit_health) < 0.001
	var q_later: float = mink.q_timer
	mink.release_latch("test_release")
	_tick(mink, _frame(Vector2.ZERO, aim, 0), SimConstants.TICK_DELTA)
	var q_after_release: float = mink.q_timer
	var release_cooldown: bool = q_after_release > 9.9 and q_after_release <= 10.0

	var ok: bool = latched and one_hit and q_held_while_latched and no_aura_damage and release_cooldown
	if not ok:
		failures.append("mink_choke expected one 20 damage latch and 10s release cooldown; latched=%s health=%.3f q_after_hit=%.3f no_aura=%s q_latched=%.3f q_after_release=%.3f" % [
			str(latched),
			after_hit_health,
			q_after_hit,
			str(no_aura_damage),
			q_later,
			q_after_release
		])
	return ok

func _check_minion_core_damage_after_huts(failures: Array[String]) -> bool:
	var arena := _arena()
	var red_core := CoreScript.new()
	arena.add_child(red_core)
	red_core.setup(1, Vector2(260.0, 0.0))
	arena.cores[1] = red_core
	arena.hut_counts[1] = 0

	var minion := MinionScript.new()
	arena.add_child(minion)
	minion.setup(arena, 0, red_core.global_position + Vector2.LEFT * (red_core.radius + minion.attack_range - 4.0), "lane", Vector2.ZERO)
	minion.attack_timer = 0.0
	minion._physics_process(SimConstants.TICK_DELTA)

	var expected_health := red_core.max_health - minion.damage
	var ok := absf(red_core.health - expected_health) < 0.001 and arena.core_damage_records.size() == 1
	if not ok:
		failures.append("minion_core expected core damage after huts gone, got core=%.3f records=%d" % [
			red_core.health,
			arena.core_damage_records.size()
		])
	return ok

func _arena() -> FakeArena:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	return arena

func _creature(arena: FakeArena, creature_id: String, team: int, position: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_child(creature)
	creature.setup(arena, team, position, creature_id, arena.terrain)
	arena.register_entity(creature)
	return creature

func _projectile_target(creature_id: String, position: Vector2) -> Node:
	var arena := ProjectileArena.new()
	get_root().add_child(arena)
	var target := CreatureScript.new()
	arena.add_child(target)
	target.setup(arena, 1, position, creature_id)
	target.state = CreatureStateScript.State.AIRBORNE
	target.flight_grounded_timer = 0.0
	arena.register_entity(target)
	return target

func _fire_arena_projectile_at(target: Node, damage: float) -> void:
	var arena: Node = target.arena
	var projectile := ProjectileScript.new()
	arena.add_child(projectile)
	projectile.setup(arena, 0, target.global_position, Vector2.RIGHT, damage, 0.0, Color.WHITE, false, 7.0, 1.0, null)
	projectile.previous_position = projectile.global_position
	projectile._physics_process(SimConstants.TICK_DELTA)

func _frame(move: Vector2, aim: Vector2, buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = move
	frame.aim = aim
	frame.buttons = buttons
	return frame

func _tick(creature: Node, frame: Resource, seconds: float) -> void:
	var ticks := int(ceil(seconds / SimConstants.TICK_DELTA))
	for _i in range(ticks):
		creature.set_input_frame(frame)
		creature.tick_sim(SimConstants.TICK_DELTA)

func _modifier_remaining(creature: Node, source: String) -> float:
	for modifier: Dictionary in creature.modifiers:
		if String(modifier.get("source", "")) == source:
			return float(modifier.get("remaining", -1.0))
	return -1.0

func _arena_source_uses_ranged_projectile() -> bool:
	var file := FileAccess.open("res://scripts/game/arena.gd", FileAccess.READ)
	if file == null:
		return false
	var source := file.get_as_text()
	var start := source.find("func resolve_projectile_hits")
	if start < 0:
		return false
	var end := source.find("\nfunc ", start + 1)
	if end < 0:
		end = source.length()
	var block := source.substr(start, end - start)
	return block.find("take_damage_event") >= 0 and block.find("DamageEventScript.DELIVERY_RANGED") >= 0
