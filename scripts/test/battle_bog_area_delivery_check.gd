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
	var hit_position := Vector2.ZERO
	var hit_normal := Vector2.ZERO

	func is_alive() -> bool:
		return health > 0.0

	func take_damage_event(event: Resource) -> void:
		last_delivery = int(event.delivery)
		hit_position = event.hit_position
		hit_normal = event.hit_normal
		health = maxf(health - float(event.amount), 0.0)

class DeliveryProbeKit:
	extends RefCounted
	var deliveries: Array[int] = []
	var abilities: Array[String] = []

	func on_damage_taken(_actor: Node, event: Resource, _amount: float, _before_health: float) -> void:
		deliveries.append(int(event.delivery))
		abilities.append(String(event.source_ability))

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
	_check_environment_delivery(arena, failures)
	_check_region_hit_feedback(arena, failures)
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
	var probe_meta: bool = probe.hit_position != Vector2.ZERO and probe.hit_normal.length() > 0.9
	var owl_hit_not_spiked: bool = owl.health < owl_start and owl.state == CreatureStateScript.State.AIRBORNE
	var no_melee_retaliation: bool = source.damage_ticks.size() == source_ticks_before
	if not probe_event or not probe_meta or not owl_hit_not_spiked or not no_melee_retaliation:
		failures.append("area damage should use DELIVERY_AREA with metadata, hit airborne targets without ranged spike, and avoid melee retaliation; probe=%s/%d meta=%s/%s/%s owl=%s state=%d retaliated=%s toad=%.2f" % [
			str(probe_event),
			probe.last_delivery,
			str(probe_meta),
			str(probe.hit_position),
			str(probe.hit_normal),
			str(owl_hit_not_spiked),
			owl.state,
			str(not no_melee_retaliation),
			toad.health
		])

func _check_environment_delivery(arena: Node, failures: Array[String]) -> void:
	var water_point := Vector2.ZERO
	var terrain_victim := _creature(arena, "bullfrog", 1, water_point)
	var terrain_probe := DeliveryProbeKit.new()
	terrain_victim.kit = terrain_probe
	terrain_victim._update_terrain(1.0)
	var terrain_area: bool = terrain_probe.deliveries.has(DamageEventScript.DELIVERY_AREA)

	var hungry := _creature(arena, "chorus_frog", 1, Vector2(5000.0, 5200.0))
	var hunger_probe := DeliveryProbeKit.new()
	hungry.kit = hunger_probe
	hungry.hunger = 0.01
	hungry.hunger_satiated = false
	hungry._tick_hunger(1.0)
	var starvation_area: bool = hunger_probe.deliveries.has(DamageEventScript.DELIVERY_AREA) and hunger_probe.abilities.has("Starvation")
	if not terrain_area or not starvation_area:
		failures.append("environment damage should use DELIVERY_AREA for wrong-terrain and starvation; terrain=%s deliveries=%s starvation=%s deliveries=%s abilities=%s" % [
			str(terrain_area),
			str(terrain_probe.deliveries),
			str(starvation_area),
			str(hunger_probe.deliveries),
			str(hunger_probe.abilities)
		])

func _check_region_hit_feedback(arena: Node, failures: Array[String]) -> void:
	var target_position := Vector2(100.0, 100.0)
	var hit_position := Vector2(124.0, 100.0)
	var target: Node = arena.player
	arena.record_vfx_event({
		"type": "hit_landed",
		"position": target_position,
		"hit_position": hit_position,
		"target": target,
		"region": "head",
		"region_mult": 1.35,
		"amount": 10.0,
		"heavy": false
	})
	var spark := _last_circle_telegraph(arena)
	var centered_on_hit: bool = spark.get("center", Vector2.ZERO) == hit_position
	var scaled_by_region: bool = absf(float(spark.get("radius", 0.0)) - 13.5) < 0.01
	var flashed_by_region: bool = target != null and target.render_flash_timer > 0.0 and absf(float(target.get("render_flash_region_mult")) - 1.35) < 0.001
	if not centered_on_hit or not scaled_by_region or not flashed_by_region:
		failures.append("region hit feedback should use hit_position/region_mult for spark and target flash; spark=%s flash=%.2f timer=%.2f" % [
			str(spark),
			float(target.get("render_flash_region_mult")) if target != null else -1.0,
			float(target.get("render_flash_timer")) if target != null else -1.0
		])

func _last_circle_telegraph(arena: Node) -> Dictionary:
	var telegraphs: Array = arena.get("telegraphs")
	for i in range(telegraphs.size() - 1, -1, -1):
		if String(telegraphs[i].get("type", "")) == "circle":
			return telegraphs[i]
	return {}

func _creature(arena: Node, creature_id: String, team: int, position: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_child(creature)
	creature.setup(arena, team, position, creature_id, arena.terrain_map)
	creature.global_position = position
	arena.register_entity(creature)
	return creature
