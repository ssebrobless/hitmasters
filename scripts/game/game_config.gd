extends Node

const DEFAULT_SQUAD_IDS := ["snapping_turtle", "chorus_frog", "mink"]
const PLAYABLE_SQUAD_POOL := ["snapping_turtle", "chorus_frog", "mink", "beaver", "owl", "duck", "bullfrog", "cane_toad", "crayfish", "water_shrew", "newt"]

var selected_mode := "1v1"
var selected_creature_id := "snapping_turtle"
var selected_squad_ids: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]

func _ready() -> void:
	var perf_requested := false
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--mode="):
			selected_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--creature="):
			set_selected_creature(argument.trim_prefix("--creature="))
		elif argument == "--bb-perf" or argument.begins_with("--bb-perf-frames="):
			perf_requested = true
	if perf_requested:
		add_child(preload("res://scripts/game/perf_harness.gd").new())

func set_selected_creature(creature_id: String) -> void:
	var playable_id := _playable_or_default(creature_id)
	selected_creature_id = playable_id
	selected_squad_ids = _build_squad_around(playable_id)

func get_selected_squad_ids() -> Array[String]:
	return _normalize_squad_ids(selected_squad_ids)

func set_selected_squad_ids(creature_ids: Array) -> void:
	selected_squad_ids = _normalize_squad_ids(creature_ids)
	if not selected_squad_ids.is_empty():
		selected_creature_id = selected_squad_ids[0]

func _build_squad_around(creature_id: String) -> Array[String]:
	var output: Array[String] = []
	if not creature_id.is_empty():
		output.append(creature_id)
	for candidate in PLAYABLE_SQUAD_POOL:
		if output.size() >= 3:
			break
		if not output.has(candidate):
			output.append(candidate)
	return _normalize_squad_ids(output)

func _normalize_squad_ids(creature_ids: Array) -> Array[String]:
	var output: Array[String] = []
	for creature_id in creature_ids:
		var normalized_id := String(creature_id)
		if normalized_id.is_empty() or output.has(normalized_id) or not PLAYABLE_SQUAD_POOL.has(normalized_id):
			continue
		output.append(normalized_id)
	for fallback in DEFAULT_SQUAD_IDS:
		if output.size() >= 3:
			break
		if not output.has(fallback):
			output.append(fallback)
	var normalized: Array[String] = []
	for i in mini(output.size(), 3):
		normalized.append(output[i])
	return normalized

func _playable_or_default(creature_id: String) -> String:
	return creature_id if PLAYABLE_SQUAD_POOL.has(creature_id) else DEFAULT_SQUAD_IDS[0]
