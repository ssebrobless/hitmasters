extends SceneTree
## BB-BOSS-6: all five boss families spawn through the shared boss_actor framework as
## side bosses and as 50% larger center bosses.

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("boss_shared_framework check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame

	var arena := current_scene
	var failures: Array[String] = []
	if arena == null:
		push_error("boss_shared_framework check: Arena scene did not load")
		quit(1)
		return

	var side_radii := _check_side_families(arena, failures)
	_check_center_families(arena, side_radii, failures)

	print("boss_shared_framework failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_side_families(arena: Node, failures: Array[String]) -> Dictionary:
	var radii := {}
	for idx in range(arena.SIDE_BOSS_ORDER.size()):
		var family := String(arena.SIDE_BOSS_ORDER[idx])
		_reset_side_boss(arena, 0)
		arena.side_boss_index[0] = idx
		arena._activate_side_boss_for_team(0)
		var boss := _boss_actor(arena, "blue:Boss")
		if boss == null:
			failures.append("side family %s did not spawn a boss actor" % family)
			continue
		var family_ok: bool = boss.has_method("is_boss_actor") \
			and boss.is_boss_actor() \
			and String(boss.get("boss_family")) == family \
			and not boss.is_center_boss()
		if not family_ok:
			failures.append("side family %s spawned wrong actor/state: %s" % [family, _boss_debug(boss)])
		if not boss.has_method("within_leash") or not boss.within_leash(boss.global_position):
			failures.append("side family %s should spawn inside its leash" % family)
		radii[family] = float(boss.get("body_radius"))
	return radii

func _check_center_families(arena: Node, side_radii: Dictionary, failures: Array[String]) -> void:
	for family in arena.SIDE_BOSS_ORDER:
		family = String(family)
		_clear_center_bosses(arena)
		arena._spawn_center_boss(family)
		var boss := _center_actor(arena)
		if boss == null:
			failures.append("center family %s did not spawn a boss actor" % family)
			continue
		var family_ok: bool = boss.has_method("is_boss_actor") \
			and boss.is_boss_actor() \
			and boss.is_center_boss() \
			and String(boss.get("boss_family")) == family
		if not family_ok:
			failures.append("center family %s spawned wrong actor/state: %s" % [family, _boss_debug(boss)])
		var expected_radius := float(side_radii.get(family, 0.0)) * 1.5
		if expected_radius <= 0.0 or not is_equal_approx(float(boss.get("body_radius")), expected_radius):
			failures.append("center family %s should be 50%% larger; radius=%s expected=%s" % [
				family,
				str(boss.get("body_radius")),
				str(expected_radius)
			])

func _reset_side_boss(arena: Node, team: int) -> void:
	var idx := _side_zone_index(arena, "blue" if team == 0 else "red")
	if idx < 0:
		return
	var zone: Dictionary = arena.animal_zone_states[idx]
	arena._clear_wildlife_for_zone(String(zone.get("id", "")))
	zone["active"] = false
	zone["objective_state"] = "dormant"
	zone["occupants"] = []
	zone["alive_occupants"] = []
	zone["alive_count"] = 0
	zone["wildlife_count"] = 0
	arena.animal_zone_states[idx] = zone

func _clear_center_bosses(arena: Node) -> void:
	for i in range(arena.animal_zone_states.size() - 1, -1, -1):
		var zone: Dictionary = arena.animal_zone_states[i]
		if not bool(zone.get("center_boss", false)):
			continue
		arena._clear_wildlife_for_zone(String(zone.get("id", "")))
		arena.animal_zone_states.remove_at(i)

func _side_zone_index(arena: Node, side: String) -> int:
	for i in arena.animal_zone_states.size():
		var zone: Dictionary = arena.animal_zone_states[i]
		if bool(zone.get("boss", false)) and String(zone.get("side", "")) == side:
			return i
	return -1

func _boss_actor(arena: Node, zone_id: String) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == zone_id:
			return enc
	return null

func _center_actor(arena: Node) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and enc.has_method("is_center_boss") and enc.is_center_boss():
			return enc
	return null

func _boss_debug(boss: Node) -> String:
	if boss == null:
		return "<null>"
	return "family=%s center=%s script=%s" % [
		str(boss.get("boss_family")),
		str(boss.is_center_boss() if boss.has_method("is_center_boss") else false),
		str(boss.get_script().resource_path if boss.get_script() != null else "")
	]
