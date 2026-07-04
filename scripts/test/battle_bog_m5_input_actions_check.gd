extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"

const REQUIRED_ACTIONS := {
	"squad_slot_1": "select squad slot 1",
	"squad_slot_2": "select squad slot 2",
	"squad_slot_3": "select squad slot 3",
	"squad_regroup": "regroup squad around the active creature",
	"squad_farm": "send inactive squad members to farm/survive"
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	var actions_ok := _check_input_actions_exist(failures)
	var arena_ok := false
	if actions_ok:
		arena_ok = await _check_action_events_drive_arena(failures)

	print("m5_input_actions actions=%s arena=%s" % [str(actions_ok), str(arena_ok)])
	for failure in failures:
		push_error(failure)
	quit(0 if actions_ok and arena_ok else 1)

func _check_input_actions_exist(failures: Array[String]) -> bool:
	var missing: Array[String] = []
	for action_name in REQUIRED_ACTIONS.keys():
		if not InputMap.has_action(action_name):
			missing.append("%s (%s)" % [action_name, REQUIRED_ACTIONS[action_name]])

	if not missing.is_empty():
		failures.append("missing squad InputMap actions in project.godot: %s" % ", ".join(missing))
		return false
	return true

func _check_action_events_drive_arena(failures: Array[String]) -> bool:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		var squad_ids: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
		config.set_selected_squad_ids(squad_ids)

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		failures.append("failed to boot Arena scene for input action check: error=%d" % error)
		return false
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		failures.append("Arena scene did not become current_scene for input action check.")
		return false

	var slot_2_ok := _press_action_and_expect_slot(arena, "squad_slot_2", 1, failures)
	var slot_3_ok := _press_action_and_expect_slot(arena, "squad_slot_3", 2, failures)
	arena._set_active_squad_index(2, false)
	var slot_1_ok := _press_action_and_expect_slot(arena, "squad_slot_1", 0, failures)
	var regroup_ok := _press_action_and_expect_command(arena, "squad_regroup", "follow", failures)
	arena._issue_squad_follow(false)
	var farm_ok := _press_action_and_expect_command(arena, "squad_farm", "farm", failures)

	if not (slot_1_ok and slot_2_ok and slot_3_ok and regroup_ok and farm_ok):
		failures.append("squad action events did not drive Arena._input; update Arena to use event.is_action_pressed('squad_slot_1/2/3', 'squad_regroup', 'squad_farm') instead of raw keycode-only handling")
		return false
	return true

func _press_action_and_expect_slot(arena: Node, action_name: String, expected_index: int, failures: Array[String]) -> bool:
	_dispatch_action(arena, action_name)
	var ok: bool = arena.active_squad_index == expected_index and arena.player == arena.player_squad[expected_index]
	if not ok:
		failures.append("%s expected active squad slot %d; got index=%d player_match=%s" % [
			action_name,
			expected_index + 1,
			arena.active_squad_index,
			str(arena.player == arena.player_squad[expected_index])
		])
	return ok

func _press_action_and_expect_command(arena: Node, action_name: String, expected_command: String, failures: Array[String]) -> bool:
	_dispatch_action(arena, action_name)
	var ok := false
	if expected_command == "follow":
		ok = arena.squad_command == "follow" and arena.squad_command_timer > 9.9
	elif expected_command == "farm":
		ok = arena.squad_command == "farm" and arena.squad_command_timer == 0.0 and arena.squad_aggro_target == null

	if not ok:
		failures.append("%s expected command=%s; got command=%s timer=%.2f target=%s" % [
			action_name,
			expected_command,
			arena.squad_command,
			arena.squad_command_timer,
			str(arena.squad_aggro_target)
		])
	return ok

func _dispatch_action(arena: Node, action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	event.strength = 1.0
	arena._input(event)
