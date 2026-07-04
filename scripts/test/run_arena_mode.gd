extends SceneTree

func _initialize() -> void:
	var mode := "1v1"
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")

	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = mode
	change_scene_to_file("res://scenes/Arena.tscn")
	create_timer(8.0).timeout.connect(quit)
