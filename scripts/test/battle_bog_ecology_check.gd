extends SceneTree

# Pass 4 ecology acceptance: deterministic day refresh, diet-gated wild food,
# hunger/deposit loop, and visible habitat reserve/cue data.

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["chorus_frog", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("ecology check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or not arena.has_method("get_day_state"):
		push_error("Arena scene did not load ecology methods; current_scene=%s" % str(arena))
		quit(1)
		return

	_check_day_and_spawns(arena, failures)
	_check_diet_gates(arena, failures)
	_check_deposit_cue(arena, failures)
	_check_starvation(arena, failures)

	print("ecology failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_day_and_spawns(arena: Node, failures: Array[String]) -> void:
	var expected_count: int = arena.terrain_map.get_food_spawn_points().size()
	var day: Dictionary = arena.get_day_state()
	if int(day.get("day", 0)) != 1 or float(day.get("length", 0.0)) != 120.0:
		failures.append("day state expected day 1 / 120s, got %s" % str(day))
	if arena.food_sources.size() != expected_count:
		failures.append("food spawn count expected %d got %d" % [expected_count, arena.food_sources.size()])

	var before_day: int = int(arena.day_index)
	if not arena.food_sources.is_empty():
		var food = arena.food_sources.pop_back()
		if food != null and is_instance_valid(food):
			food.queue_free()
	arena._tick_day_cycle(120.0)
	if arena.day_index != before_day + 1 or arena.food_sources.size() != expected_count:
		failures.append("dawn refresh expected day %d and %d food sources, got day %d count %d" % [
			before_day + 1,
			expected_count,
			arena.day_index,
			arena.food_sources.size()
		])

func _check_diet_gates(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.hunger = 60.0
	actor.hunger_satiated = false
	var plant := _first_food(arena, "plant")
	if plant == null:
		failures.append("expected at least one plant food source")
		return
	actor.global_position = plant.global_position
	if arena.try_eat_nearby_food(actor):
		failures.append("carnivore chorus frog should not eat plants")

	var critter := _first_food(arena, "critter")
	if critter == null:
		failures.append("expected at least one critter food source")
		return
	actor.global_position = critter.global_position
	var ate: bool = arena.try_eat_nearby_food(actor)
	if not ate or actor.hunger <= 60.0:
		failures.append("carnivore should eat critter and gain hunger; ate=%s hunger=%.2f" % [str(ate), actor.hunger])

func _check_deposit_cue(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var reserve_visuals: Array = arena.get_habitat_stock_visuals(0)
	if reserve_visuals.size() < 6:
		failures.append("expected visible reserve stock data for blue trio, got %d" % reserve_visuals.size())

	actor.global_position = arena.terrain_map.get_team_habitat_rect(actor.team).get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true
	var before_cues: int = arena.stock_manager.get_breeding_cues(actor.team).size()
	var deposited: bool = arena._try_manual_habitat_deposit(actor)
	var after_cues: int = arena.stock_manager.get_breeding_cues(actor.team).size()
	if not deposited or after_cues != before_cues + 1 or actor.hunger_satiated:
		failures.append("satiated habitat deposit expected cue+reset, deposited=%s cues %d->%d satiated=%s" % [
			str(deposited),
			before_cues,
			after_cues,
			str(actor.hunger_satiated)
		])

func _check_starvation(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.hunger = 0.01
	actor.hunger_satiated = false
	actor._tick_hunger(1.0)
	if actor.is_alive():
		failures.append("starvation should eliminate a creature at 0 hunger")

func _first_food(arena: Node, kind: String) -> Node:
	for food in arena.food_sources:
		if food != null and is_instance_valid(food) and String(food.kind) == kind:
			return food
	return null
