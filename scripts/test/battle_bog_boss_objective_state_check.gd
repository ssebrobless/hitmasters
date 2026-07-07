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

	print("boss_objective_state failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _boss_zone(arena: Node, side: String) -> Dictionary:
	for zone: Dictionary in arena.get_animal_zone_state():
		if String(zone.get("side", "")) == side and String(zone.get("group", "")) == "Boss":
			return zone
	return {}

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

	# Defeat the boss occupant: objective_state -> claimable (public downed broadcast).
	for enc in arena.wildlife_encounters.duplicate():
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == "blue:Boss":
			arena.on_wildlife_defeated(enc, arena.player)
	if String(arena.get_side_boss_state(0).get("objective_state", "")) != "claimable":
		failures.append("downed blue boss should be claimable; state=%s" % str(arena.get_side_boss_state(0)))

	# Red never bred, so its objective stays dormant throughout.
	if String(arena.get_side_boss_state(1).get("objective_state", "")) != "dormant":
		failures.append("red boss should remain dormant; state=%s" % str(arena.get_side_boss_state(1)))
