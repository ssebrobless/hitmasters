extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("m6 animal zone check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or not arena.has_method("get_animal_zone_state"):
		push_error("Arena scene did not expose animal zone state; current_scene=%s" % str(arena))
		quit(1)
		return

	_check_zone_spawn_state(arena, failures)
	_check_zone_occupancy(arena, failures)
	_check_boss_activation(arena, failures)

	print("m6_animal_zones failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_zone_spawn_state(arena: Node, failures: Array[String]) -> void:
	var zones: Array = arena.get_animal_zone_state()
	var blue_a := _zone(zones, "blue", "A")
	var blue_boss := _zone(zones, "blue", "Boss")
	var red_boss := _zone(zones, "red", "Boss")
	var nonboss_active := 0
	for zone: Dictionary in zones:
		if not bool(zone.get("boss", false)) and bool(zone.get("active", false)):
			nonboss_active += 1
	var blue_a_ok := blue_a.size() > 0 and bool(blue_a.get("active", false)) and (blue_a.get("occupants", []) as Array).size() == 5
	var boss_dormant := blue_boss.size() > 0 and red_boss.size() > 0 \
		and not bool(blue_boss.get("active", true)) \
		and not bool(red_boss.get("active", true)) \
		and (blue_boss.get("occupants", []) as Array).is_empty() \
		and (red_boss.get("occupants", []) as Array).is_empty()
	if zones.size() != 10 or nonboss_active != 8 or not blue_a_ok or not boss_dormant:
		failures.append("animal zones should spawn 8 active side zones and 2 dormant boss zones; count=%d active=%d blue_a=%s boss=%s/%s" % [
			zones.size(),
			nonboss_active,
			str(blue_a),
			str(blue_boss),
			str(red_boss)
		])

func _check_zone_occupancy(arena: Node, failures: Array[String]) -> void:
	var blue_a := _zone(arena.get_animal_zone_state(), "blue", "A")
	if blue_a.is_empty():
		failures.append("cannot check occupancy without blue A zone")
		return
	var center: Vector2 = blue_a.get("center", Vector2.ZERO)
	var player: Node = arena.player
	var red_bot: Node = arena.bots[0] if not arena.bots.is_empty() else null
	if player == null or red_bot == null:
		failures.append("cannot check occupancy without player and red bot")
		return
	player.global_position = center
	red_bot.global_position = center + Vector2(8.0, 0.0)
	arena._tick_animal_zones(0.25)
	var contested_zone := _zone(arena.get_animal_zone_state(), "blue", "A")
	var contested_ok := bool(contested_zone.get("contested", false)) \
		and int(contested_zone.get("blue_count", 0)) >= 1 \
		and int(contested_zone.get("red_count", 0)) >= 1 \
		and int(contested_zone.get("control_team", -2)) == -1
	red_bot.global_position = center + Vector2(4000.0, 0.0)
	arena._tick_animal_zones(0.25)
	var controlled_zone := _zone(arena.get_animal_zone_state(), "blue", "A")
	var controlled_ok := not bool(controlled_zone.get("contested", true)) \
		and int(controlled_zone.get("blue_count", 0)) >= 1 \
		and int(controlled_zone.get("red_count", 1)) == 0 \
		and int(controlled_zone.get("control_team", -1)) == 0
	if not contested_ok or not controlled_ok:
		failures.append("animal zones should track contest/control from live scored actors; contested=%s controlled=%s" % [
			str(contested_zone),
			str(controlled_zone)
		])

func _check_boss_activation(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(actor.team)
	actor.global_position = habitat.get_center()
	var accepted := 0
	for _i in 5:
		arena.habitat_deposit_feedback_timer = 0.0
		actor.hunger = 100.0
		actor.hunger_satiated = true
		if arena._try_manual_habitat_deposit(actor):
			accepted += 1
	var progress: Dictionary = arena.get_boss_progress_state()
	var blue_boss := _zone(arena.get_animal_zone_state(), "blue", "Boss")
	var red_boss := _zone(arena.get_animal_zone_state(), "red", "Boss")
	var bosses_active := bool(blue_boss.get("active", false)) and bool(red_boss.get("active", false))
	var occupants_spawned := not (blue_boss.get("occupants", []) as Array).is_empty() and not (red_boss.get("occupants", []) as Array).is_empty()
	var progress_ok := accepted == 5 \
		and int(progress.get("bred_count", 0)) == 5 \
		and int(progress.get("activations", 0)) == 1 \
		and bool(progress.get("boss_active", false))
	if not progress_ok or not bosses_active or not occupants_spawned:
		failures.append("five breeding deposits should activate boss animal zones; accepted=%d progress=%s blue=%s red=%s" % [
			accepted,
			str(progress),
			str(blue_boss),
			str(red_boss)
		])

func _zone(zones: Array, side: String, group: String) -> Dictionary:
	for zone: Dictionary in zones:
		if String(zone.get("side", "")) == side and String(zone.get("group", "")) == group:
			return zone
	return {}
