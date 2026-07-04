extends Node

var selected_mode := "1v1"
var selected_hero_id := "burst_rifle"

func _ready() -> void:
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--mode="):
			selected_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--hero="):
			selected_hero_id = argument.trim_prefix("--hero=")
