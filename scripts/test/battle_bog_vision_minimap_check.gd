extends SceneTree
## BB-VIS-2: the minimap fog-gates ENEMY mobile units to the view team (own units, neutral
## objectives, huts/cores stay public), and surfaces out-of-sight enemies only from their
## stored last-known point. Verifies the classifier + the info-state data the draw consumes.

const ARENA_SCENE := "res://scenes/Arena.tscn"
const MinimapScript := preload("res://scripts/ui/minimap.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("vision_minimap check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("vision_minimap check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	arena.cover_rects.clear()
	arena.day_timer = 120.0 * 0.30  # day phase

	var minimap = MinimapScript.new()
	minimap.arena = arena
	minimap.view_team = 0

	var player: Node = arena.player
	var enemy: Node = _first_enemy(arena)
	if player == null or enemy == null:
		push_error("vision_minimap check: need player + enemy; player=%s enemy=%s" % [str(player), str(enemy)])
		quit(1)
		return

	# Classifier: enemy mobile unit is fog-gated; own units are not.
	if not minimap._is_fog_gated_enemy(enemy):
		failures.append("enemy creature should be fog-gated on the minimap")
	if minimap._is_fog_gated_enemy(player):
		failures.append("own-team unit must never be fog-gated")

	# Visible adjacent enemy -> the minimap draws it live.
	enemy.global_position = player.global_position + Vector2(12.0, 0.0)
	if not arena.is_entity_visible_to_team(enemy, 0):
		failures.append("adjacent enemy should be visible to view team (drawn live)")

	# Record the sighting, then break sight -> a last-known ghost anchored to the stored point.
	arena._tick_team_vision(0.2)
	var seen_point: Vector2 = enemy.global_position
	enemy.global_position = player.global_position + Vector2(5000.0, 0.0)
	if arena.get_entity_info_state(enemy, 0) != "last_known":
		failures.append("out-of-sight recently-seen enemy should be last_known; got %s" % arena.get_entity_info_state(enemy, 0))
	var ghost_point: Vector2 = arena.get_last_known_point(0, enemy)
	if ghost_point == Vector2.INF or ghost_point.distance_to(seen_point) > 1.0:
		failures.append("ghost should anchor to the last-known point %s; got %s" % [str(seen_point), str(ghost_point)])
	if arena.is_entity_visible_to_team(enemy, 0):
		failures.append("far enemy must not be drawn as a live pip")

	# A never-seen enemy in hearing range should draw a coarse sound/rustle pulse,
	# even though there is no last-known ghost to reuse.
	arena.team_vision[0].clear()
	enemy.global_position = player.global_position + Vector2(arena.get_team_vision_range(0) + 40.0, 0.0)
	if arena.get_entity_info_state(enemy, 0) != "heard":
		failures.append("enemy outside sight but inside hearing should be heard; got %s" % arena.get_entity_info_state(enemy, 0))
	if arena.get_last_known_point(0, enemy) != Vector2.INF:
		failures.append("heard-only enemy should not have a last-known point")
	var heard_marker: Vector2 = arena.get_info_marker_point(0, enemy)
	if heard_marker == Vector2.INF:
		failures.append("heard-only enemy should expose a coarse minimap marker")
	if heard_marker.distance_to(enemy.global_position) <= 1.0:
		failures.append("heard-only marker should not expose exact enemy position; marker=%s enemy=%s" % [str(heard_marker), str(enemy.global_position)])

	_check_food_minimap_memory(arena, player, failures)

	minimap.free()
	print("vision_minimap failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _first_enemy(arena: Node) -> Node:
	for entity: Node in arena.entities:
		if entity == null or not is_instance_valid(entity) or not ("team" in entity):
			continue
		if int(entity.get("team")) != 1:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		return entity
	return null

func _check_food_minimap_memory(arena: Node, player: Node, failures: Array[String]) -> void:
	var food := _first_non_habitat_food(arena, 0)
	if food == null:
		failures.append("vision minimap food check expected a food source outside blue habitat")
		return
	arena.team_food_vision[0].clear()
	player.global_position = food.global_position + Vector2(5000.0, 0.0)
	var hidden: Dictionary = arena.get_food_minimap_state(food, 0)
	if bool(hidden.get("visible", true)):
		failures.append("never-seen distant food should be hidden on minimap; state=%s" % str(hidden))

	player.global_position = food.global_position + Vector2(12.0, 0.0)
	var visible: Dictionary = arena.get_food_minimap_state(food, 0)
	if not bool(visible.get("visible", false)) or String(visible.get("state", "")) != "visible":
		failures.append("nearby food should be exact-visible on minimap; state=%s" % str(visible))
	arena.vision_tick_timer = 0.0
	arena._tick_team_vision(0.2)
	var seen_point: Vector2 = food.global_position

	player.global_position = food.global_position + Vector2(5000.0, 0.0)
	arena.elapsed += 2.0
	var remembered: Dictionary = arena.get_food_minimap_state(food, 0)
	var remembered_point: Vector2 = remembered.get("point", Vector2.INF)
	if not bool(remembered.get("visible", false)) or String(remembered.get("state", "")) != "last_known" or remembered_point.distance_to(seen_point) > 1.0:
		failures.append("scouted food should leave a last-known minimap marker; state=%s seen=%s" % [str(remembered), str(seen_point)])

	arena.elapsed += 50.0
	var expired: Dictionary = arena.get_food_minimap_state(food, 0)
	if bool(expired.get("visible", false)):
		failures.append("food minimap memory should expire; state=%s" % str(expired))

func _first_non_habitat_food(arena: Node, team: int) -> Node:
	var habitat_rect: Rect2 = arena.terrain_map.get_team_habitat_rect(team)
	for food: Node in arena.food_sources:
		if food == null or not is_instance_valid(food):
			continue
		if habitat_rect.has_point(food.global_position):
			continue
		return food
	return null
