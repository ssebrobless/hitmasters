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
		push_error("champsosaurus_leash check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("champsosaurus_leash check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_leash(arena, failures)

	print("boss_champsosaurus_leash failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _boss_actor(arena: Node, zone_id: String) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == zone_id:
			return enc
	return null

func _check_leash(arena: Node, failures: Array[String]) -> void:
	for _i in range(5):
		arena._record_bred_animal(0)
	var boss := _boss_actor(arena, "blue:Boss")
	if boss == null or not boss.has_method("within_leash"):
		failures.append("no blue boss actor to leash-test")
		return
	boss.set_physics_process(false)  # drive the AI manually for determinism
	var home: Vector2 = boss.get("home_center")

	# The leash includes home and the middle contest band, excludes deep enemy territory.
	if not boss.within_leash(home):
		failures.append("home should be within the leash; home=%s" % str(home))
	if not boss.within_leash(Vector2(120.0, home.y)):
		failures.append("middle band (near x=0) should be within the leash")
	if boss.within_leash(Vector2(760.0, home.y)):
		failures.append("deep enemy territory should be OUTSIDE the leash")

	# The soft leash clamps movement at its boundary (never past the map center reach).
	var clamped: Vector2 = boss._clamp_to_leash(Vector2(9999.0, home.y))
	if clamped.x > boss.leash_rect.end.x + 0.001:
		failures.append("clamp should cap at the leash edge; clamped=%s end=%s" % [str(clamped), str(boss.leash_rect.end)])

	# With an enemy planted DEEP in enemy territory (outside the leash), the boss
	# must not chase there: its x never exceeds the leash edge across many ticks.
	var enemy: Node = arena.player
	enemy.global_position = Vector2(760.0, home.y)
	var max_x_seen: float = boss.global_position.x
	for _i in range(120):
		boss._physics_process(0.05)
		max_x_seen = maxf(max_x_seen, boss.global_position.x)
	if max_x_seen > boss.leash_rect.end.x + 0.5:
		failures.append("boss chased past its leash toward the enemy; max_x=%.1f leash_end=%.1f" % [max_x_seen, boss.leash_rect.end.x])
	if not boss.within_leash(boss.global_position):
		failures.append("boss ended outside its leash; pos=%s" % str(boss.global_position))
