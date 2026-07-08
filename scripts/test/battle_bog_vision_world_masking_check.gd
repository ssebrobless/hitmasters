extends SceneTree
## BB-VIS-4: world-space enemy masking. Exact enemy mobile positions are rendered only
## when visible/revealed to the local player's team; remembered/heard/suspected/hidden
## states remain logic/minimap information, not live world sprites.

const ARENA_SCENE := "res://scenes/Arena.tscn"
const MinionScript := preload("res://scripts/game/minion.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("vision_world_masking check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame

	var arena := current_scene
	var failures: Array[String] = []
	if arena == null:
		push_error("vision_world_masking check: Arena scene did not load")
		quit(1)
		return

	arena.cover_rects.clear()
	arena.day_timer = 120.0 * 0.30
	var player: Node = arena.player
	var enemy: Node = _first_enemy_creature(arena)
	if player == null or enemy == null:
		push_error("vision_world_masking check: need player/enemy; player=%s enemy=%s" % [str(player), str(enemy)])
		quit(1)
		return

	var blue := int(player.get("team"))
	var origin: Vector2 = player.global_position

	enemy.global_position = origin + Vector2(12.0, 0.0)
	arena._apply_world_vision_masking()
	if not bool(enemy.visible) or not arena.is_world_entity_rendered(enemy):
		failures.append("visible enemy creature should render in world; state=%s visible=%s" % [arena.get_world_entity_info_state(enemy), str(enemy.visible)])
	if not _marker_for(arena, enemy, "visible").is_empty():
		failures.append("directly visible enemy should not need a degraded info marker")

	arena._tick_team_vision(0.2)
	var seen_point: Vector2 = enemy.global_position
	enemy.global_position = origin + Vector2(5000.0, 0.0)
	arena._apply_world_vision_masking()
	if bool(enemy.visible) or arena.is_world_entity_rendered(enemy):
		failures.append("last-known enemy creature should not render exact world sprite; state=%s visible=%s" % [arena.get_world_entity_info_state(enemy), str(enemy.visible)])
	var last_marker := _marker_for(arena, enemy, "last_known")
	if last_marker.is_empty() or (last_marker.get("point", Vector2.INF) as Vector2).distance_to(seen_point) > 1.0:
		failures.append("last-known enemy should expose a stale world info marker at %s; marker=%s" % [str(seen_point), str(last_marker)])

	arena.reveal_entity_to_team(enemy, blue, 5.0)
	arena._apply_world_vision_masking()
	if not bool(enemy.visible) or not arena.is_world_entity_rendered(enemy):
		failures.append("revealed enemy creature should render again; state=%s visible=%s" % [arena.get_world_entity_info_state(enemy), str(enemy.visible)])
	var reveal_marker := _marker_for(arena, enemy, "revealed")
	if reveal_marker.is_empty() or (reveal_marker.get("point", Vector2.INF) as Vector2).distance_to(enemy.global_position) > 1.0:
		failures.append("revealed enemy should expose an exact reveal marker; marker=%s enemy=%s" % [str(reveal_marker), str(enemy.global_position)])

	arena._tick_team_vision(6.0)
	arena.elapsed += 100.0
	arena._apply_world_vision_masking()
	if bool(enemy.visible):
		failures.append("hidden enemy creature should stay masked after reveal expires; state=%s" % arena.get_world_entity_info_state(enemy))
	if not _marker_for(arena, enemy, "hidden").is_empty():
		failures.append("hidden enemy should not expose a world info marker")

	arena.team_vision[blue].clear()
	arena.team_reveals[blue].clear()
	enemy.global_position = origin + Vector2(arena.get_team_vision_range(blue) + 40.0, 0.0)
	arena._apply_world_vision_masking()
	var heard_marker := _marker_for(arena, enemy, "heard")
	if bool(enemy.visible) or arena.get_world_entity_info_state(enemy) != "heard":
		failures.append("heard-only enemy should remain masked in world; state=%s visible=%s" % [arena.get_world_entity_info_state(enemy), str(enemy.visible)])
	if heard_marker.is_empty():
		failures.append("heard-only enemy should expose a coarse world info marker")
	elif (heard_marker.get("point", Vector2.INF) as Vector2).distance_to(enemy.global_position) <= 1.0:
		failures.append("heard-only world marker should be coarse, not exact; marker=%s enemy=%s" % [str(heard_marker), str(enemy.global_position)])

	var minion := MinionScript.new()
	arena.add_child(minion)
	minion.setup(arena, 1, origin + Vector2(16.0, 0.0), "lane", Vector2.ZERO)
	arena.register_entity(minion)
	arena._apply_world_vision_masking()
	if not bool(minion.visible):
		failures.append("visible enemy minion should render in world")
	minion.global_position = origin + Vector2(5000.0, 80.0)
	arena._apply_world_vision_masking()
	if bool(minion.visible):
		failures.append("hidden enemy minion should be world-masked")

	if not bool(player.visible) or arena.get_world_entity_info_state(player) != "visible":
		failures.append("own player should never be world-masked")

	print("vision_world_masking failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _first_enemy_creature(arena: Node) -> Node:
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

func _marker_for(arena: Node, entity: Node, state: String) -> Dictionary:
	var id := entity.get_instance_id()
	for marker: Dictionary in arena.get_world_info_markers(int(arena.player.get("team"))):
		if int(marker.get("entity_id", -1)) != id:
			continue
		if state == "hidden" or state == "visible":
			return marker
		if String(marker.get("state", "")) == state:
			return marker
	return {}
