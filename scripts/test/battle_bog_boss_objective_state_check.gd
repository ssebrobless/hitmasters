extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const MinimapScript := preload("res://scripts/ui/minimap.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("boss_objective_state check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_objective_state check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_objective_lifecycle(arena, failures)
	_check_objective_brief(arena, failures)

	print("boss_objective_state failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _boss_zone(arena: Node, side: String) -> Dictionary:
	for zone: Dictionary in arena.get_animal_zone_state():
		if String(zone.get("side", "")) == side and String(zone.get("group", "")) == "Boss":
			return zone
	return {}

func _center_boss_zone(arena: Node) -> Dictionary:
	for zone: Dictionary in arena.get_animal_zone_state():
		if bool(zone.get("center_boss", false)):
			return zone
	return {}

func _real_center_boss_zone(arena: Node) -> Dictionary:
	for zone: Dictionary in arena.animal_zone_states:
		if bool(zone.get("center_boss", false)):
			return zone
	return {}

func _has_objective_event(arena: Node, action: String, fragment: String) -> bool:
	for entry: Dictionary in arena.kill_feed:
		if String(entry.get("kind", "")) != "objective":
			continue
		if String(entry.get("action", "")) != action:
			continue
		if String(entry.get("message", "")).contains(fragment):
			return true
	return false

func _check_objective_lifecycle(arena: Node, failures: Array[String]) -> void:
	# Fresh: the side boss objective is dormant, and the minimap surfaces the
	# dormant state as a coarse public broadcast without showing progress pips.
	if String(arena.get_side_boss_state(0).get("objective_state", "")) != "dormant":
		failures.append("fresh blue boss should be dormant; state=%s" % str(arena.get_side_boss_state(0)))
	var dormant_mm: Dictionary = MinimapScript.animal_zone_minimap_state(_boss_zone(arena, "blue"))
	if String(dormant_mm.get("objective_state", "")) != "dormant" or bool(dormant_mm.get("visible", true)):
		failures.append("dormant boss minimap should report dormant and no pips; mm=%s" % str(dormant_mm))

	# Activate the blue side boss: objective_state -> active.
	for _i in range(5):
		arena._record_bred_animal(0)
	if String(arena.get_side_boss_state(0).get("objective_state", "")) != "active":
		failures.append("blue boss should be active after activation; state=%s" % str(arena.get_side_boss_state(0)))
	var active_mm: Dictionary = MinimapScript.animal_zone_minimap_state(_boss_zone(arena, "blue"))
	if String(active_mm.get("objective_state", "")) != "active":
		failures.append("active boss minimap should report active; mm=%s" % str(active_mm))
	if not bool(active_mm.get("visible", false)) or String(active_mm.get("action", "")) != "fight" or String(active_mm.get("label", "")) != "CH":
		failures.append("active boss minimap should expose fight label; mm=%s" % str(active_mm))
	if not _has_objective_event(arena, "fight", "Blue boss awakens"):
		failures.append("boss activation should emit a public fight objective event; feed=%s" % str(arena.kill_feed))

	# Defeat the boss occupant: objective_state -> claimable (public downed broadcast).
	for enc in arena.wildlife_encounters.duplicate():
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == "blue:Boss":
			arena.on_wildlife_defeated(enc, arena.player)
	if String(arena.get_side_boss_state(0).get("objective_state", "")) != "claimable":
		failures.append("downed blue boss should be claimable; state=%s" % str(arena.get_side_boss_state(0)))
	var claimable_mm: Dictionary = MinimapScript.animal_zone_minimap_state(_boss_zone(arena, "blue"))
	if not bool(claimable_mm.get("visible", false)) or String(claimable_mm.get("action", "")) != "claim":
		failures.append("claimable boss minimap should expose claim action; mm=%s" % str(claimable_mm))
	if not _has_objective_event(arena, "claim", "hold the boss zone"):
		failures.append("boss downed state should emit a public claim objective event; feed=%s" % str(arena.kill_feed))

	# Red never bred, so its objective stays dormant throughout.
	if String(arena.get_side_boss_state(1).get("objective_state", "")) != "dormant":
		failures.append("red boss should remain dormant; state=%s" % str(arena.get_side_boss_state(1)))

func _check_objective_brief(arena: Node, failures: Array[String]) -> void:
	var brief: Dictionary = arena.get_boss_objective_brief(0)
	var side: Dictionary = brief.get("side", {})
	var center: Dictionary = brief.get("center", {})
	if String(side.get("state", "")) != "claimable" or String(side.get("action", "")) != "claim":
		failures.append("objective brief should expose side claim action after lifecycle setup; side=%s" % str(side))
	if bool(side.get("meter_locked", false)) != true:
		failures.append("objective brief should mark active side boss meter locked; side=%s" % str(side))
	if String(side.get("family", "")) != "champsosaurus":
		failures.append("objective brief should expose current side boss family; side=%s" % str(side))
	if bool(center.get("active", true)) or int(center.get("next_spawn_index", -1)) != 0 or absf(float(center.get("next_spawn_time", 0.0)) - 600.0) > 0.01:
		failures.append("objective brief should expose first center spawn countdown while dormant; center=%s" % str(center))

	arena.elapsed = 590.0
	brief = arena.get_boss_objective_brief(0)
	center = brief.get("center", {})
	if absf(float(center.get("next_spawn_in", -1.0)) - 10.0) > 0.01:
		failures.append("objective brief should compute center spawn seconds remaining; center=%s" % str(center))

	arena.elapsed = 600.0
	arena._tick_center_boss_schedule()
	brief = arena.get_boss_objective_brief(0)
	center = brief.get("center", {})
	if not bool(center.get("active", false)) or String(center.get("action", "")) != "fight" or float(center.get("next_spawn_in", 0.0)) >= 0.0:
		failures.append("objective brief should switch center to active fight state; center=%s" % str(center))
	var center_mm: Dictionary = MinimapScript.animal_zone_minimap_state(_center_boss_zone(arena))
	if not bool(center_mm.get("visible", false)) or not bool(center_mm.get("center_boss", false)) or String(center_mm.get("action", "")) != "fight":
		failures.append("center boss minimap should expose center fight state; mm=%s" % str(center_mm))
	if not _has_objective_event(arena, "fight", "Center boss descends"):
		failures.append("center spawn should emit a public fight objective event; feed=%s" % str(arena.kill_feed))

	var real_center := _real_center_boss_zone(arena)
	real_center["active"] = false
	real_center["objective_state"] = "claimable"
	real_center["claim_team"] = 0
	real_center["claim_progress"] = 2.5
	brief = arena.get_boss_objective_brief(0)
	center = brief.get("center", {})
	if String(center.get("action", "")) != "claim" or String(center.get("claim_route", "")) != "center_combat_reward" or absf(float(center.get("claim_ratio", 0.0)) - 0.5) > 0.01:
		failures.append("center brief should expose downed claim progress/reward route; center=%s" % str(center))
	real_center["claim_team"] = -1
	real_center["claim_progress"] = 0.0
	real_center["control_team"] = 0
	arena._advance_boss_claim(real_center, 1.0)
	if not _has_objective_event(arena, "claim", "Blue claiming"):
		failures.append("center claim start should emit a public claiming objective event; feed=%s" % str(arena.kill_feed))
	real_center["objective_state"] = "contesting"
	real_center["contested"] = true
	brief = arena.get_boss_objective_brief(0)
	center = brief.get("center", {})
	if String(center.get("action", "")) != "contest" or not bool(center.get("contested", false)):
		failures.append("center brief should expose contested claim state; center=%s" % str(center))

	arena._grant_center_reward(0, "teratornis")
	brief = arena.get_boss_objective_brief(0)
	var rewards: Dictionary = brief.get("combat_rewards", {})
	if int(rewards.get("teratornis", {}).get("stack", 0)) != 1:
		failures.append("objective brief should include team center reward state; rewards=%s" % str(rewards))
	if not _has_objective_event(arena, "reward", "claims center reward"):
		failures.append("center reward should emit a public reward objective event; feed=%s" % str(arena.kill_feed))
