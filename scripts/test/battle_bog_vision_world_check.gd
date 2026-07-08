extends SceneTree
## BB-VIS-1: per-team six-state info model. Drives an enemy through visible -> last_known ->
## hidden, forced reveal, stealth (heard-not-seen), suspected-on-own-turf, and confirms
## get_visible_enemy_targets tracks live visibility. Cover is cleared so sight depends purely
## on range (LOS is exercised separately by other checks).

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("vision_world check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("vision_world check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	arena.cover_rects.clear()          # deterministic sight: range only, no occlusion
	arena.day_timer = 120.0 * 0.30     # "day" phase (vision 220, hearing 340)

	var player: Node = arena.player
	var enemy: Node = _first_enemy(arena)
	if player == null or enemy == null:
		push_error("vision_world check: need a blue player and a red enemy; player=%s enemy=%s" % [str(player), str(enemy)])
		quit(1)
		return
	var blue := int(player.get("team"))
	var origin: Vector2 = player.global_position

	# 1) Adjacent enemy in daylight -> visible.
	enemy.global_position = origin + Vector2(12.0, 0.0)
	if arena.get_entity_info_state(enemy, blue) != "visible":
		failures.append("adjacent enemy should be visible; got %s" % arena.get_entity_info_state(enemy, blue))
	if not arena.is_entity_visible_to_team(enemy, blue):
		failures.append("is_entity_visible_to_team should be true when visible")

	# 2) Record the sighting, then break sight -> last_known within the ghost window.
	arena._tick_team_vision(VISION_TICK())
	enemy.global_position = origin + Vector2(5000.0, 0.0)  # far, into red territory
	if arena.get_entity_info_state(enemy, blue) != "last_known":
		failures.append("recently-seen enemy out of range should be last_known; got %s" % arena.get_entity_info_state(enemy, blue))

	# 3) Let the ghost fade -> hidden (enemy sits in red territory, so no suspicion).
	arena.elapsed += 100.0
	if arena.get_entity_info_state(enemy, blue) != "hidden":
		failures.append("stale enemy in enemy territory should be hidden; got %s" % arena.get_entity_info_state(enemy, blue))

	# 4) Forced reveal overrides range -> revealed.
	arena.reveal_entity_to_team(enemy, blue, 5.0)
	if arena.get_entity_info_state(enemy, blue) != "revealed":
		failures.append("revealed enemy should read revealed even out of range; got %s" % arena.get_entity_info_state(enemy, blue))
	if not arena.is_entity_visible_to_team(enemy, blue):
		failures.append("revealed enemy should count as visible-to-team")

	# 5) Reveal expires.
	arena._tick_team_vision(6.0)
	if arena.get_entity_info_state(enemy, blue) == "revealed":
		failures.append("reveal should expire after its duration")

	# 6) Heard: a never-seen enemy in hearing range gives a coarse marker, not exact position.
	arena.team_vision[blue].clear()
	enemy.global_position = origin + Vector2(arena.get_team_vision_range(blue) + 40.0, 0.0)
	if arena.get_entity_info_state(enemy, blue) != "heard":
		failures.append("enemy outside sight but inside hearing should be heard; got %s" % arena.get_entity_info_state(enemy, blue))
	var heard_marker: Vector2 = arena.get_info_marker_point(blue, enemy)
	if heard_marker == Vector2.INF:
		failures.append("heard enemy should expose a coarse marker point")
	if heard_marker.distance_to(enemy.global_position) <= 1.0:
		failures.append("heard marker should be coarse, not exact; marker=%s enemy=%s" % [str(heard_marker), str(enemy.global_position)])
	if arena.get_last_known_point(blue, enemy) != Vector2.INF:
		failures.append("never-seen heard enemy should not create a last-known ghost")

	# 7) Stealth: adjacent but unseen -> heard, not visible.
	enemy.global_position = origin + Vector2(12.0, 0.0)
	if arena.get_entity_info_state(enemy, blue) != "visible":
		failures.append("pre-stealth adjacency should be visible; got %s" % arena.get_entity_info_state(enemy, blue))
	enemy.begin_stealth(5.0, "test")
	if arena.get_entity_info_state(enemy, blue) != "heard":
		failures.append("stealthed adjacent enemy should be heard-not-seen; got %s" % arena.get_entity_info_state(enemy, blue))
	if arena.is_entity_visible_to_team(enemy, blue):
		failures.append("stealthed enemy must not be visible-to-team")

	# 8) get_visible_enemy_targets tracks live visibility.
	enemy.break_stealth()
	if not arena.get_visible_enemy_targets(player).has(enemy):
		failures.append("un-stealthed adjacent enemy should be in get_visible_enemy_targets")

	# 9) Suspected: an unseen intruder on our own turf.
	arena.team_vision[blue].clear()
	arena.team_reveals[blue].clear()
	for member in arena._team_vision_members(blue):
		member.global_position = Vector2(4000.0, 0.0)  # pull all our eyes to the far side
	enemy.global_position = Vector2(-3000.0, 0.0)       # deep in blue territory, beyond hearing
	if arena.get_entity_info_state(enemy, blue) != "suspected":
		failures.append("unseen enemy on own turf should be suspected; got %s" % arena.get_entity_info_state(enemy, blue))

	print("vision_world failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func VISION_TICK() -> float:
	return 0.2

func _first_enemy(arena: Node) -> Node:
	var blue := int(arena.player.get("team")) if arena.player != null else 0
	for entity: Node in arena.entities:
		if entity == null or not is_instance_valid(entity) or not ("team" in entity):
			continue
		if int(entity.get("team")) == blue:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		return entity
	return null
