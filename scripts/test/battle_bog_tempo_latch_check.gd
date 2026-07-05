extends SceneTree

# Pass 1 acceptance — decisions #32 (global tempo, minion attack commit) and
# #33 (latch grip & struggle).

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const MinionScript := preload("res://scripts/game/minion.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")

class FakeArena:
	extends Node
	var entities: Array[Node] = []
	var cores := {}
	var terrain := TerrainMapScript.new()

	func _init() -> void:
		terrain.configure("3v3")

	func add_actor(actor: Node) -> void:
		add_child(actor)
		entities.append(actor)

	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)

	func get_terrain_zone(point: Vector2) -> String:
		return terrain.get_zone_at(point)

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func record_death(_victim: Node, _killer: Node = null) -> void:
		pass

	func get_closest_enemy(_source: Node, _max_distance: float) -> Node:
		return null

	func get_enemy_core(_team: int) -> Node:
		return null

	func get_steering_direction(from: Vector2, to: Vector2, _radius: float, _team: int) -> Vector2:
		return (to - from).normalized()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog != null:
		catalog.load_catalog()
	await process_frame
	await physics_frame

	var failures: Array[String] = []
	_check_tempo_constants(failures)
	_check_minion_commit(failures)
	_check_grip_struggle_drain(failures)
	_check_struggle_hit(failures)
	_check_third_party_dr(failures)
	_check_latch_speed(failures)
	print("tempo_latch failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_tempo_constants(failures: Array[String]) -> void:
	if SimConstants.SPEED_PX_PER_SEC != 91.0:
		failures.append("decision #32: SPEED_PX_PER_SEC expected 91.0 got %f" % SimConstants.SPEED_PX_PER_SEC)
	var lane := MinionScript.new()
	var arena := FakeArena.new()
	get_root().add_child(arena)
	arena.add_child(lane)
	lane.setup(arena, 0, Vector2.ZERO, "lane")
	var tank := MinionScript.new()
	arena.add_child(tank)
	tank.setup(arena, 0, Vector2.ZERO, "tank")
	var pebble := MinionScript.new()
	arena.add_child(pebble)
	pebble.setup(arena, 0, Vector2.ZERO, "pebble")
	if lane.speed != 87.0 or tank.speed != 63.0 or pebble.speed != 75.0:
		failures.append("decision #32: minion speeds expected 87/63/75 got %s/%s/%s" % [lane.speed, tank.speed, pebble.speed])
	arena.queue_free()

func _check_minion_commit(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var minion := MinionScript.new()
	arena.add_child(minion)
	minion.setup(arena, 0, Vector2.ZERO, "melee")
	var victim := _creature(arena, "snapping_turtle", 1, Vector2(20.0, 0.0))
	minion._attack(victim)
	if minion.attack_commit_timer != 0.25:
		failures.append("decision #32: _attack should set a 0.25 s commit, got %f" % minion.attack_commit_timer)
	minion._move_toward_point(Vector2(400.0, 0.0))
	if minion.velocity != Vector2.ZERO or minion.global_position != Vector2.ZERO:
		failures.append("decision #32: committed minion must not move (vel=%s pos=%s)" % [minion.velocity, minion.global_position])
	minion.attack_commit_timer = 0.0
	minion._move_toward_point(Vector2(400.0, 0.0))
	if minion.velocity == Vector2.ZERO:
		failures.append("decision #32: uncommitted minion should move again")
	arena.queue_free()

func _check_grip_struggle_drain(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var mink := _creature(arena, "mink", 0, Vector2.ZERO)
	var victim := _creature(arena, "snapping_turtle", 1, Vector2(20.0, 0.0))
	mink.attach_to_victim(victim, 4.0, "Choke", 99.0)
	victim.receive_latch(mink, 4.0, "Choke")
	if victim.latch_move_multiplier != 0.45:
		failures.append("decision #33: latch pair speed multiplier expected 0.45 got %f" % victim.latch_move_multiplier)
	# Idle victim: grip drains 1x.
	victim.velocity = Vector2.ZERO
	mink._tick_latch(1.0)
	if absf(mink.latch_timer - 3.0) > 0.001:
		failures.append("decision #33: idle victim should drain grip 1x (expected 3.0 got %f)" % mink.latch_timer)
	if absf(victim.latch_timer - mink.latch_timer) > 0.001:
		failures.append("decision #33: victim timer should mirror attacker grip")
	# Struggling victim (moving against the drag): 1.5x.
	var drag_direction: Vector2 = (mink.global_position - victim.global_position).normalized()
	victim.velocity = -drag_direction * 50.0
	mink._tick_latch(1.0)
	if absf(mink.latch_timer - 1.5) > 0.001:
		failures.append("decision #33: struggling victim should drain grip 1.5x (expected 1.5 got %f)" % mink.latch_timer)
	arena.queue_free()

func _check_struggle_hit(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var mink := _creature(arena, "mink", 0, Vector2.ZERO)
	var victim := _creature(arena, "snapping_turtle", 1, Vector2(20.0, 0.0))
	mink.attach_to_victim(victim, 6.0, "Choke", 99.0)
	victim.receive_latch(mink, 6.0, "Choke")
	# Place the latcher BEHIND the victim's aim so the normal arc would miss.
	mink.global_position = victim.global_position + Vector2(60.0, 0.0)
	victim.last_aim_direction = Vector2.LEFT
	var before_hp: float = mink.health
	var hits: Array = MeleeHit.hit(victim, 24.0, 15.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "bite")
	if not hits.has(mink) or mink.health >= before_hp:
		failures.append("decision #33: victim melee should auto-connect with its latcher regardless of facing")
	if absf(mink.latch_timer - (6.0 - 0.75)) > 0.001:
		failures.append("decision #33: struggle hit should chunk grip by 0.75 (expected 5.25 got %f)" % mink.latch_timer)
	if absf(victim.latch_timer - mink.latch_timer) > 0.001:
		failures.append("decision #33: grip chunk should mirror to the victim timer")
	arena.queue_free()

func _check_third_party_dr(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var mink := _creature(arena, "mink", 0, Vector2.ZERO)
	var victim := _creature(arena, "snapping_turtle", 1, Vector2(20.0, 0.0))
	var third := _creature(arena, "chorus_frog", 1, Vector2(-40.0, 0.0))
	mink.attach_to_victim(victim, 6.0, "Choke", 99.0)
	victim.receive_latch(mink, 6.0, "Choke")
	# Mink's Fearless passive scales both hits identically, so assert the
	# RATIO between third-party and victim damage is exactly 0.75.
	var start_hp: float = mink.health
	mink.take_damage_event(third.make_damage_event(40.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "tongue"))
	var third_party_damage: float = start_hp - mink.health
	start_hp = mink.health
	mink.take_damage_event(victim.make_damage_event(40.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "bite"))
	var victim_damage: float = start_hp - mink.health
	if victim_damage <= 0.0 or absf(third_party_damage / victim_damage - 0.75) > 0.01:
		failures.append("decision #33: third-party/victim damage ratio should be 0.75 (got %f/%f)" % [third_party_damage, victim_damage])
	arena.queue_free()

func _check_latch_speed(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var victim := _creature(arena, "snapping_turtle", 1, Vector2.ZERO)
	var free_speed: float = victim.get_speed_px() * victim.latch_move_multiplier
	var mink := _creature(arena, "mink", 0, Vector2(20.0, 0.0))
	mink.attach_to_victim(victim, 6.0, "Choke", 99.0)
	victim.receive_latch(mink, 6.0, "Choke")
	var latched_speed: float = victim.get_speed_px() * victim.latch_move_multiplier
	if latched_speed > free_speed * 0.45 + 0.01:
		failures.append("decision #33: latched pair speed should be capped at 45%% of base (free=%f latched=%f)" % [free_speed, latched_speed])
	arena.queue_free()

func _creature(arena: FakeArena, creature_id: String, team: int, spawn: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_actor(creature)
	creature.setup(arena, team, spawn, creature_id, arena.terrain)
	creature.global_position = spawn
	return creature
