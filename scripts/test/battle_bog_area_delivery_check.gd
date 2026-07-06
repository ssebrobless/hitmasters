extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const CreatureScript := preload("res://scripts/sim/creature.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")

class AreaProbe:
	extends Node2D
	var team := 1
	var health := 100.0
	var max_health := 100.0
	var body_radius := 10.0
	var last_delivery := -1

	func is_alive() -> bool:
		return health > 0.0

	func take_damage_event(event: Resource) -> void:
		last_delivery = int(event.delivery)
		health = maxf(health - float(event.amount), 0.0)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("area delivery check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("area delivery check missing Arena scene")
		quit(1)
		return

	var failures: Array[String] = []
	_check_area_delivery(arena, failures)
	print("area_delivery failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_area_delivery(arena: Node, failures: Array[String]) -> void:
	arena.cover_rects = []
	var center := Vector2(5000.0, 5000.0)
	var source := _creature(arena, "bullfrog", 0, center + Vector2.LEFT * 80.0)
	var owl := _creature(arena, "owl", 1, center)
	owl.state = CreatureStateScript.State.AIRBORNE
	var owl_start: float = owl.health
	var toad := _creature(arena, "cane_toad", 1, center + Vector2.RIGHT * 8.0)
	var source_ticks_before: int = source.damage_ticks.size()
	var probe := AreaProbe.new()
	arena.add_child(probe)
	probe.global_position = center + Vector2.RIGHT * 12.0
	arena.register_entity(probe)

	arena.damage_enemies_in_radius(0, center, 48.0, 35.0, source, "Area Probe")

	var probe_event: bool = probe.last_delivery == DamageEventScript.DELIVERY_AREA and probe.health < probe.max_health
	var owl_hit_not_spiked: bool = owl.health < owl_start and owl.state == CreatureStateScript.State.AIRBORNE
	var no_melee_retaliation: bool = source.damage_ticks.size() == source_ticks_before
	if not probe_event or not owl_hit_not_spiked or not no_melee_retaliation:
		failures.append("area damage should use DELIVERY_AREA, hit airborne targets without ranged spike, and avoid melee retaliation; probe=%s/%d owl=%s state=%d retaliated=%s toad=%.2f" % [
			str(probe_event),
			probe.last_delivery,
			str(owl_hit_not_spiked),
			owl.state,
			str(not no_melee_retaliation),
			toad.health
		])

func _creature(arena: Node, creature_id: String, team: int, position: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_child(creature)
	creature.setup(arena, team, position, creature_id, arena.terrain_map)
	creature.global_position = position
	arena.register_entity(creature)
	return creature
