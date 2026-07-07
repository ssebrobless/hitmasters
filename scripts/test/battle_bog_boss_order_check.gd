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
		push_error("boss_order check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_order check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_boss_order(arena, failures)

	print("boss_order failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_boss_order(arena: Node, failures: Array[String]) -> void:
	# Fresh arena starts pointed at the first family in the fixed order.
	var initial_family := String(arena.get_side_boss_state(0).get("next_family", ""))
	if initial_family != "champsosaurus":
		failures.append("initial blue next_family should be champsosaurus; got %s" % initial_family)

	# Directly activate the blue boss to isolate the family-advance order from
	# the meter/freeze logic. Record next_family after each activation.
	var observed: Array[String] = []
	for _i in range(6):
		arena._activate_side_boss_for_team(0)
		observed.append(String(arena.get_side_boss_state(0).get("next_family", "")))

	var expected: Array[String] = ["platyhystrix", "american_mastodon", "arthropleura", "teratornis", "champsosaurus", "platyhystrix"]
	if observed != expected:
		failures.append("family cycle should wrap through the fixed 5-family order; expected %s got %s" % [str(expected), str(observed)])
