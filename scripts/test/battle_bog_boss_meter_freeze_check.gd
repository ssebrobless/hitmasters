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
		push_error("boss_meter_freeze check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_meter_freeze check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_meter_freeze(arena, failures)

	print("boss_meter_freeze failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_meter_freeze(arena: Node, failures: Array[String]) -> void:
	# Fill the blue meter to activate the blue side boss.
	for _i in range(5):
		arena._record_bred_animal(0)
	var activated: Dictionary = arena.get_side_boss_state(0)
	if not bool(activated.get("active", false)) or int(activated.get("meter", -1)) != 0:
		failures.append("blue boss should be active with meter 0 after 5 breeds; state=%s" % str(activated))

	# While the blue boss is active, further blue breeds are frozen out.
	arena._record_bred_animal(0)
	arena._record_bred_animal(0)
	var frozen: Dictionary = arena.get_side_boss_state(0)
	if int(frozen.get("meter", -1)) != 0 or int(frozen.get("activations", -1)) != 1:
		failures.append("blue meter/activations should stay frozen while boss active; state=%s" % str(frozen))

	# Clear the blue boss by defeating its wildlife occupant(s).
	var cleared_any := false
	for enc in arena.wildlife_encounters.duplicate():
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == "blue:Boss":
			arena.on_wildlife_defeated(enc, arena.player)
			cleared_any = true
	if not cleared_any:
		failures.append("expected a blue:Boss wildlife encounter to defeat")
	if bool(arena.get_side_boss_state(0).get("active", true)):
		failures.append("blue boss should be inactive after its wildlife is defeated; state=%s" % str(arena.get_side_boss_state(0)))

	# With the boss cleared, the meter resumes counting on the next breed.
	arena._record_bred_animal(0)
	var resumed := int(arena.get_side_boss_state(0).get("meter", -1))
	if resumed != 1:
		failures.append("blue meter should resume to 1 after the boss is cleared; meter=%d" % resumed)
