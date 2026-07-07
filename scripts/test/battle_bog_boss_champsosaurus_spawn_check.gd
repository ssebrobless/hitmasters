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
		push_error("champsosaurus_spawn check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("champsosaurus_spawn check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_spawn(arena, failures)

	print("boss_champsosaurus_spawn failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _boss_actor(arena: Node, zone_id: String) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == zone_id:
			return enc
	return null

func _check_spawn(arena: Node, failures: Array[String]) -> void:
	# Activate the blue side boss (first family in the fixed order = Champsosaurus).
	for _i in range(5):
		arena._record_bred_animal(0)

	var blue := _boss_actor(arena, "blue:Boss")
	if blue == null or not blue.has_method("is_boss_actor") or not blue.is_boss_actor():
		failures.append("blue boss activation should spawn a boss actor in blue:Boss; got %s" % str(blue))
		return
	if String(blue.get("actor_name")) != "Champsosaurus":
		failures.append("blue boss should be a Champsosaurus; name=%s" % str(blue.get("actor_name")))
	if int(blue.get("team")) != -1:
		failures.append("side boss should be neutral (team -1); team=%s" % str(blue.get("team")))
	if float(blue.get("health")) != float(blue.get("max_health")):
		failures.append("fresh boss should be at full health; hp=%s/%s" % [str(blue.get("health")), str(blue.get("max_health"))])
	if not blue.within_leash(blue.global_position):
		failures.append("boss should spawn within its own leash region; pos=%s" % str(blue.global_position))
	# The boss is a valid combat target via the wildlife path (attackable), and
	# neutral so it is not counted as a scored actor for zone control.
	if bool(blue.is_scored_actor()):
		failures.append("neutral boss should not be a scored actor")

	# Red never bred: no boss actor should exist in red:Boss.
	if _boss_actor(arena, "red:Boss") != null:
		failures.append("red boss should not have spawned")
