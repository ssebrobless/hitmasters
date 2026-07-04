extends Node

var selected_mode := "1v1"
var selected_creature_id := "snapping_turtle"
var selected_hero_id := "burst_rifle"

func _ready() -> void:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--mode="):
			selected_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--creature="):
			set_selected_creature(argument.trim_prefix("--creature="))
		elif argument.begins_with("--hero="):
			selected_hero_id = argument.trim_prefix("--hero=")

func set_selected_creature(creature_id: String) -> void:
	selected_creature_id = creature_id
	selected_hero_id = get_legacy_hero_id(creature_id)

func get_legacy_hero_id(creature_id: String) -> String:
	match creature_id:
		"snapping_turtle":
			return "iron_vanguard"
		"chorus_frog":
			return "chorus"
		"mink":
			return "blinkblade"
		"beaver":
			return "lifewarden"
		"owl":
			return "longshot"
		"duck":
			return "burst_rifle"
		_:
			return selected_hero_id
