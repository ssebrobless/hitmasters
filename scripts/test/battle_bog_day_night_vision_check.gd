extends SceneTree
## BB-VIS-1: get_day_state gains a light phase (dawn/day/dusk/night) and a phase-scaled
## vision range, without breaking the day/length contract ecology_check depends on.

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("day_night_vision check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("day_night_vision check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []

	# Preserve the existing ecology contract (day 1, 120s length) alongside the new keys.
	var day: Dictionary = arena.get_day_state()
	if int(day.get("day", 0)) != 1 or not is_equal_approx(float(day.get("length", 0.0)), 120.0):
		failures.append("day/length contract broken; day_state=%s" % str(day))

	# Drive each phase by setting day_timer and assert phase + vision range.
	var cases := [
		{"frac": 0.02, "phase": "dawn", "range": 200.0},
		{"frac": 0.30, "phase": "day", "range": 220.0},
		{"frac": 0.60, "phase": "dusk", "range": 170.0},
		{"frac": 0.85, "phase": "night", "range": 120.0}
	]
	for case: Dictionary in cases:
		arena.day_timer = 120.0 * float(case["frac"])
		var state: Dictionary = arena.get_day_state()
		if String(state.get("phase", "")) != String(case["phase"]):
			failures.append("frac %.2f expected phase %s got %s" % [float(case["frac"]), String(case["phase"]), String(state.get("phase", ""))])
		if not is_equal_approx(float(state.get("vision_range", -1.0)), float(case["range"])):
			failures.append("phase %s expected vision_range %.0f got %.1f" % [String(case["phase"]), float(case["range"]), float(state.get("vision_range", -1.0))])
		if String(arena.get_day_phase()) != String(case["phase"]):
			failures.append("get_day_phase mismatch at frac %.2f: %s" % [float(case["frac"]), String(arena.get_day_phase())])

	# Vision shrinks from day through night; multiplier is normalized to the day range.
	if not (arena.get_vision_range_for_phase("day") > arena.get_vision_range_for_phase("dusk")
			and arena.get_vision_range_for_phase("dusk") > arena.get_vision_range_for_phase("night")):
		failures.append("vision range should shrink day>dusk>night")
	arena.day_timer = 120.0 * 0.85
	var night: Dictionary = arena.get_day_state()
	if not is_equal_approx(float(night.get("vision_multiplier", -1.0)), 120.0 / 220.0):
		failures.append("night vision_multiplier expected %.3f got %.3f" % [120.0 / 220.0, float(night.get("vision_multiplier", -1.0))])

	print("day_night_vision failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
