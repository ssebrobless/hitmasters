extends Node

var selected_mode := "1v1"
var selected_creature_id := "snapping_turtle"

func _ready() -> void:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--mode="):
			selected_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--creature="):
			set_selected_creature(argument.trim_prefix("--creature="))

func set_selected_creature(creature_id: String) -> void:
	selected_creature_id = creature_id
