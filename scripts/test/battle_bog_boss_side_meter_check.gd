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
		push_error("boss_side_meter check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_side_meter check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_side_meter_independence(arena, failures)

	print("boss_side_meter failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_side_meter_independence(arena: Node, failures: Array[String]) -> void:
	# Fresh arena: both team meters start at zero.
	var blue_start := int(arena.get_side_boss_state(0).get("meter", -1))
	var red_start := int(arena.get_side_boss_state(1).get("meter", -1))
	if blue_start != 0 or red_start != 0:
		failures.append("fresh meters should be zero; blue=%d red=%d" % [blue_start, red_start])

	# One blue breed bumps only the blue meter.
	arena._record_bred_animal(0)
	var blue_after_blue := int(arena.get_side_boss_state(0).get("meter", -1))
	var red_after_blue := int(arena.get_side_boss_state(1).get("meter", -1))
	if blue_after_blue != 1 or red_after_blue != 0:
		failures.append("after one blue breed, blue meter should be 1 and red 0; blue=%d red=%d" % [blue_after_blue, red_after_blue])

	# One red breed bumps only the red meter; the blue meter is untouched.
	arena._record_bred_animal(1)
	var blue_after_red := int(arena.get_side_boss_state(0).get("meter", -1))
	var red_after_red := int(arena.get_side_boss_state(1).get("meter", -1))
	if blue_after_red != 1 or red_after_red != 1:
		failures.append("after one red breed, blue meter should stay 1 and red 1; blue=%d red=%d" % [blue_after_red, red_after_red])

	# Four more blue breeds (blue total 5) activate only the blue side boss.
	for _i in range(4):
		arena._record_bred_animal(0)
	var blue_state: Dictionary = arena.get_side_boss_state(0)
	var red_state: Dictionary = arena.get_side_boss_state(1)
	var blue_ok := int(blue_state.get("activations", -1)) == 1 \
		and int(blue_state.get("meter", -1)) == 0 \
		and bool(blue_state.get("active", false)) == true
	var red_ok := int(red_state.get("activations", -1)) == 0 \
		and int(red_state.get("meter", -1)) == 1 \
		and bool(red_state.get("active", true)) == false
	if not blue_ok or not red_ok:
		failures.append("blue should activate at meter 5 while red stays idle; blue=%s red=%s" % [str(blue_state), str(red_state)])
