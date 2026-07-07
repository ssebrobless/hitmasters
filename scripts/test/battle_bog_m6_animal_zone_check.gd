extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const StockManagerScript := preload("res://scripts/game/stock_manager.gd")

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
	_check_wildlife_encounters(arena, failures)
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
	blue_a_ok = blue_a_ok and int(blue_a.get("alive_count", 0)) == 5 and (blue_a.get("alive_occupants", []) as Array).size() == 5
	var boss_dormant := blue_boss.size() > 0 and red_boss.size() > 0 \
		and not bool(blue_boss.get("active", true)) \
		and not bool(red_boss.get("active", true)) \
		and (blue_boss.get("occupants", []) as Array).is_empty() \
		and (red_boss.get("occupants", []) as Array).is_empty()
	var water_sources_ok := _zone_water_sources_ok(arena, zones)
	if zones.size() != 10 or nonboss_active != 8 or not blue_a_ok or not boss_dormant or not water_sources_ok:
		failures.append("animal zones should spawn 8 active side zones, 2 dormant boss zones, and water-source metadata inside each zone; count=%d active=%d blue_a=%s boss=%s/%s water=%s" % [
			zones.size(),
			nonboss_active,
			str(blue_a),
			str(blue_boss),
			str(red_boss),
			str(water_sources_ok)
		])

func _check_wildlife_encounters(arena: Node, failures: Array[String]) -> void:
	var before_count: int = arena.wildlife_encounters.size()
	var blue_a := _zone(arena.get_animal_zone_state(), "blue", "A")
	var wildlife: Node = _wildlife_for_zone(arena, "blue:A")
	var actor: Node = arena.player
	if before_count != 40 or wildlife == null or actor == null:
		failures.append("active side zones should spawn 40 wildlife encounters; count=%d wildlife=%s actor=%s" % [
			before_count,
			str(wildlife),
			str(actor)
		])
		return
	var filtered_by_default := not TargetFilter.is_live_damage_target(actor, wildlife, {"require_damage_api": false})
	var targetable_by_attack := TargetFilter.is_live_damage_target(actor, wildlife, {"require_damage_api": false, "allow_wildlife": true})
	actor.hunger = 40.0
	actor.hunger_satiated = false
	var before_hunger := float(actor.get("hunger"))
	actor.global_position = wildlife.global_position - Vector2(float(actor.get("body_radius")) + float(wildlife.get("body_radius")) + 6.0, 0.0)
	actor.input_frame = null
	actor.last_aim_direction = Vector2.RIGHT
	var hits := MeleeHit.hit(actor, 42.0, float(wildlife.get("health")) + 10.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Wildlife Probe")
	var after_zone := _zone(arena.get_animal_zone_state(), "blue", "A")
	var defeated: bool = not arena.wildlife_encounters.has(wildlife)
	var state_updated: bool = int(after_zone.get("alive_count", -1)) == int(blue_a.get("alive_count", 0)) - 1 \
		and int(after_zone.get("defeated_count", 0)) == 1 \
		and (after_zone.get("alive_occupants", []) as Array).size() == 4
	var rewarded: bool = float(actor.get("hunger")) > before_hunger \
		and int(after_zone.get("blue_defeats", 0)) == 1 \
		and int(after_zone.get("last_defeat_team", -1)) == 0
	for _i in 4:
		var next_wildlife: Node = _wildlife_for_zone(arena, "blue:A")
		if next_wildlife == null:
			break
		next_wildlife.take_damage(float(next_wildlife.get("health")) + 10.0, actor.team, actor)
	var clear_zone := _zone(arena.get_animal_zone_state(), "blue", "A")
	var cleared: bool = int(clear_zone.get("alive_count", -1)) == 0 \
		and int(clear_zone.get("cleared_team", -1)) == 0 \
		and int(clear_zone.get("blue_defeats", 0)) == 5 \
		and int(clear_zone.get("defeated_count", 0)) == 5
	if not filtered_by_default or not targetable_by_attack or hits.is_empty() or not defeated or not state_updated or not rewarded or not cleared:
		failures.append("wildlife should be attack-interactable, reward compatible diets, and track team clears; filtered=%s targetable=%s hits=%d defeated=%s rewarded=%s cleared=%s before=%s after=%s clear=%s hunger %.2f->%.2f" % [
			str(filtered_by_default),
			str(targetable_by_attack),
			hits.size(),
			str(defeated),
			str(rewarded),
			str(cleared),
			str(blue_a),
			str(after_zone),
			str(clear_zone),
			before_hunger,
			float(actor.get("hunger"))
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
		arena._tick_breeding(StockManagerScript.BREEDING_DURATION_SEC + 0.1)
	var progress: Dictionary = arena.get_boss_progress_state()
	var blue_boss := _zone(arena.get_animal_zone_state(), "blue", "Boss")
	var red_boss := _zone(arena.get_animal_zone_state(), "red", "Boss")
	var bosses_active := bool(blue_boss.get("active", false)) and bool(red_boss.get("active", false))
	var occupants_spawned := not (blue_boss.get("occupants", []) as Array).is_empty() and not (red_boss.get("occupants", []) as Array).is_empty()
	var boss_wildlife_spawned := _wildlife_for_zone(arena, "blue:Boss") != null and _wildlife_for_zone(arena, "red:Boss") != null
	var progress_ok := accepted == 5 \
		and int(progress.get("bred_count", 0)) == 5 \
		and int(progress.get("activations", 0)) == 1 \
		and bool(progress.get("boss_active", false))
	if not progress_ok or not bosses_active or not occupants_spawned or not boss_wildlife_spawned:
		failures.append("five breeding deposits should activate boss animal zones; accepted=%d progress=%s blue=%s red=%s boss_wildlife=%s" % [
			accepted,
			str(progress),
			str(blue_boss),
			str(red_boss),
			str(boss_wildlife_spawned)
		])

func _zone(zones: Array, side: String, group: String) -> Dictionary:
	for zone: Dictionary in zones:
		if String(zone.get("side", "")) == side and String(zone.get("group", "")) == group:
			return zone
	return {}

func _zone_water_sources_ok(arena: Node, zones: Array) -> bool:
	for zone: Dictionary in zones:
		var center: Vector2 = zone.get("center", Vector2.ZERO)
		var radius: Vector2 = zone.get("radius", Vector2.ZERO)
		var water_center: Vector2 = zone.get("water_center", Vector2(1.0e20, 1.0e20))
		var water_radius: Vector2 = zone.get("water_radius", Vector2.ZERO)
		if water_radius.x <= 0.0 or water_radius.y <= 0.0:
			return false
		var normalized := Vector2((water_center.x - center.x) / maxf(radius.x, 1.0), (water_center.y - center.y) / maxf(radius.y, 1.0))
		if normalized.length() > 1.0:
			return false
		if arena.terrain_map.get_zone_at(water_center) != arena.terrain_map.WATER:
			return false
	return true

func _wildlife_for_zone(arena: Node, zone_id: String) -> Node:
	for encounter in arena.wildlife_encounters:
		if encounter != null and is_instance_valid(encounter) and String(encounter.get("zone_id")) == zone_id:
			return encounter
	return null
