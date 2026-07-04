extends SceneTree

const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

class FakeEntity extends Node2D:
	var team := 0
	var health := 100.0
	var max_health := 100.0
	var body_radius := 12.0
	var creature_id := "chorus_frog"
	var q_timer := 10.0
	var e_timer := 10.0
	var primary_timer := 0.0
	var arena: Node = null

	func is_alive() -> bool:
		return health > 0.0

	func is_stealthed() -> bool:
		return false

class FakeCore extends Node2D:
	var team := 1
	var health := 1000.0
	var max_health := 1000.0
	var radius := 64.0

class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var huts: Array[Node] = []
	var cores := {}
	var core_open := false
	var spawns := {
		0: Vector2(-500.0, 0.0),
		1: Vector2(500.0, 0.0)
	}

	func add_entity(entity: Node) -> Node:
		add_child(entity)
		entity.arena = self
		entities.append(entity)
		return entity

	func add_hut(team: int, position: Vector2, health := 800.0) -> Node:
		var hut := FakeEntity.new()
		hut.team = team
		hut.global_position = position
		hut.health = health
		hut.max_health = 800.0
		hut.body_radius = 30.0
		add_entity(hut)
		huts.append(hut)
		return hut

	func add_creature(team: int, position: Vector2, health := 100.0) -> Node:
		var creature := FakeEntity.new()
		creature.team = team
		creature.global_position = position
		creature.health = health
		add_entity(creature)
		return creature

	func add_core(team: int, position: Vector2) -> Node:
		var core := FakeCore.new()
		core.team = team
		core.global_position = position
		add_child(core)
		cores[team] = core
		return core

	func get_closest_enemy(source: Node, max_distance: float) -> Node:
		var closest: Node = null
		var closest_distance := max_distance
		for entity in entities:
			if entity == source or entity.team == source.team or not entity.is_alive():
				continue
			var distance: float = source.global_position.distance_to(entity.global_position)
			if distance < closest_distance:
				closest = entity
				closest_distance = distance
		return closest

	func get_enemy_core(team: int) -> Node:
		return cores.get(1 - team)

	func can_damage_core(_defending_team: int) -> bool:
		return core_open

	func get_team_spawn(team: int) -> Vector2:
		return spawns.get(team, Vector2.ZERO)

func _initialize() -> void:
	var failures: Array[String] = []
	var retreat_ok := _check_low_health_retreat(failures)
	var defend_ok := _check_hut_defense(failures)
	var hut_push_ok := _check_push_hut_before_shielded_core(failures)
	var core_push_ok := _check_push_core_after_hut_open(failures)
	var passed := retreat_ok and defend_ok and hut_push_ok and core_push_ok
	print("bot_brain retreat=%s defend=%s hut_push=%s core_push=%s" % [
		str(retreat_ok),
		str(defend_ok),
		str(hut_push_ok),
		str(core_push_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_low_health_retreat(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	arena.add_hut(0, Vector2(-220.0, 0.0))
	var bot := arena.add_creature(0, Vector2(0.0, 0.0), 20.0)
	var enemy := arena.add_creature(1, Vector2(90.0, 0.0))
	var brain := BotBrainScript.new()
	var threat: Node = arena.get_closest_enemy(bot, 360.0)
	var ratio: float = brain._health_ratio(bot)
	var frame := brain.build_frame(bot)
	var moving_home: bool = frame.move.dot((Vector2(-220.0, 0.0) - bot.global_position).normalized()) > 0.9
	var aiming_threat: bool = frame.aim.distance_to(enemy.global_position) < 0.001
	var not_attacking: bool = not frame.is_pressed(InputFrameScript.BUTTON_PRIMARY)
	var ok: bool = moving_home and aiming_threat and not_attacking
	if not ok:
		failures.append("retreat expected low-health bot to move home, aim threat, and not attack; ratio=%.3f threat=%s move=%s aim=%s buttons=%d" % [
			ratio, str(threat), str(frame.move), str(frame.aim), frame.buttons
		])
	return ok

func _check_hut_defense(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	arena.add_hut(0, Vector2(-180.0, 80.0), 280.0)
	var bot := arena.add_creature(0, Vector2(-260.0, 40.0))
	var invader := arena.add_creature(1, Vector2(-160.0, 92.0))
	var frame := BotBrainScript.new().build_frame(bot)
	var to_invader: Vector2 = (invader.global_position - bot.global_position).normalized()
	var ok: bool = frame.move.dot(to_invader) > 0.88 and frame.aim.distance_to(invader.global_position) < 0.001
	if not ok:
		failures.append("defend expected bot to rotate toward enemy pressuring own hut; move=%s aim=%s" % [str(frame.move), str(frame.aim)])
	return ok

func _check_push_hut_before_shielded_core(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var bot := arena.add_creature(0, Vector2(-200.0, 0.0))
	var enemy_hut := arena.add_hut(1, Vector2(80.0, 0.0), 400.0)
	arena.add_core(1, Vector2(360.0, 0.0))
	arena.core_open = false
	var frame := BotBrainScript.new().build_frame(bot)
	var ok: bool = frame.aim.distance_to(enemy_hut.global_position) < 0.001 and frame.move.dot(Vector2.RIGHT) > 0.9
	if not ok:
		failures.append("hut_push expected shielded-core bot to pressure enemy hut first; move=%s aim=%s" % [str(frame.move), str(frame.aim)])
	return ok

func _check_push_core_after_hut_open(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var bot := arena.add_creature(0, Vector2(220.0, 0.0))
	arena.add_hut(1, Vector2(120.0, 160.0), 800.0)
	var core := arena.add_core(1, Vector2(360.0, 0.0))
	arena.core_open = true
	var frame := BotBrainScript.new().build_frame(bot)
	var ok: bool = frame.aim.distance_to(core.global_position) < 0.001 and frame.move.dot(Vector2.RIGHT) > 0.9
	if not ok:
		failures.append("core_push expected opened-core bot to pressure core; move=%s aim=%s" % [str(frame.move), str(frame.aim)])
	return ok
