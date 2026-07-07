extends Node

const DEFAULT_SQUAD_IDS := ["snapping_turtle", "chorus_frog", "mink"]
const PLAYABLE_SQUAD_POOL := ["snapping_turtle", "chorus_frog", "mink", "beaver", "otter", "leech", "owl", "duck", "bullfrog", "cane_toad", "crayfish", "bog_turtle", "water_shrew", "newt", "great_blue_heron", "kingfisher", "water_snake", "alligator", "wolf_spider", "firefly", "mosquito_swarm"]

var selected_mode := "1v1"
var selected_creature_id := "snapping_turtle"
var selected_squad_ids: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
var blue_draft_bans: Array[String] = []
var red_draft_bans: Array[String] = []

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

func clear_draft_bans() -> void:
	blue_draft_bans.clear()
	red_draft_bans.clear()

func set_draft_bans(blue_bans: Array, red_bans: Array) -> void:
	blue_draft_bans = _normalize_ban_ids(blue_bans, 1)
	red_draft_bans = _normalize_ban_ids(red_bans, 1)
	if is_creature_banned(selected_creature_id):
		set_selected_creature(_playable_or_default(""))
	else:
		selected_squad_ids = _normalize_squad_ids(selected_squad_ids)

func is_ranked_draft_stub_enabled() -> bool:
	return selected_mode == "1v1"

func is_creature_banned(creature_id: String) -> bool:
	var normalized_id := String(creature_id)
	return blue_draft_bans.has(normalized_id) or red_draft_bans.has(normalized_id)

func get_draft_stub_state() -> Dictionary:
	return {
		"enabled": is_ranked_draft_stub_enabled(),
		"phase": "pick",
		"ban_slots_per_team": 1,
		"pick_slots_per_team": 3 if selected_mode == "1v1" else 1,
		"enforced": true,
		"blue_bans": blue_draft_bans.duplicate(),
		"red_bans": red_draft_bans.duplicate()
	}

func _build_squad_around(creature_id: String) -> Array[String]:
	var output: Array[String] = []
	if not creature_id.is_empty() and not is_creature_banned(creature_id):
		output.append(creature_id)
	for candidate in PLAYABLE_SQUAD_POOL:
		if output.size() >= 3:
			break
		if not output.has(candidate) and not is_creature_banned(candidate):
			output.append(candidate)
	return _normalize_squad_ids(output)

func _normalize_squad_ids(creature_ids: Array) -> Array[String]:
	var output: Array[String] = []
	for creature_id in creature_ids:
		var normalized_id := String(creature_id)
		if normalized_id.is_empty() or output.has(normalized_id) or not PLAYABLE_SQUAD_POOL.has(normalized_id) or is_creature_banned(normalized_id):
			continue
		output.append(normalized_id)
	for fallback in DEFAULT_SQUAD_IDS:
		if output.size() >= 3:
			break
		if not output.has(fallback) and not is_creature_banned(fallback):
			output.append(fallback)
	for fallback in PLAYABLE_SQUAD_POOL:
		if output.size() >= 3:
			break
		if not output.has(fallback) and not is_creature_banned(fallback):
			output.append(fallback)
	var normalized: Array[String] = []
	for i in mini(output.size(), 3):
		normalized.append(output[i])
	return normalized

func _playable_or_default(creature_id: String) -> String:
	if PLAYABLE_SQUAD_POOL.has(creature_id) and not is_creature_banned(creature_id):
		return creature_id
	for fallback in DEFAULT_SQUAD_IDS:
		if not is_creature_banned(fallback):
			return fallback
	for fallback in PLAYABLE_SQUAD_POOL:
		if not is_creature_banned(fallback):
			return fallback
	return DEFAULT_SQUAD_IDS[0]

func _normalize_ban_ids(creature_ids: Array, limit: int) -> Array[String]:
	var output: Array[String] = []
	for creature_id in creature_ids:
		if output.size() >= limit:
			break
		var normalized_id := String(creature_id)
		if normalized_id.is_empty() or output.has(normalized_id) or not PLAYABLE_SQUAD_POOL.has(normalized_id):
			continue
		output.append(normalized_id)
	return output
