extends SceneTree
## On-demand LIVE integration smoke for the side boss (NOT a *_check.gd, so the
## run_all suite does not auto-run it). Boots a real 1v1 arena, wakes the boss,
## and lets the ENGINE drive _physics_process for a few sim-seconds with a target
## nearby -- catching runtime/interaction bugs the unit checks (which drive the AI
## by hand) can miss. Run:
##   godot --headless --path . --script scripts/test/bb_boss_live_smoke.gd
## Prints "bb_boss_live_smoke RESULT=PASS ..." / "...RESULT=FAIL" and exits 0/1.

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		print("bb_boss_live_smoke RESULT=FAIL reason=arena_boot")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		print("bb_boss_live_smoke RESULT=FAIL reason=no_arena")
		quit(1)
		return

	arena.debug_wake_boss(0)
	var boss: Node = _boss_actor(arena, "blue:Boss")
	if boss == null:
		print("bb_boss_live_smoke RESULT=FAIL reason=no_boss_spawned")
		quit(1)
		return

	var phases := {}
	var min_x: float = boss.global_position.x
	var max_x: float = boss.global_position.x
	# Let the engine tick everything live; keep a target planted next to the boss.
	for _i in range(240):
		if is_instance_valid(arena.player) and arena.player.has_method("is_alive") and arena.player.is_alive():
			arena.player.global_position = boss.global_position + Vector2(48.0, 0.0)
		await physics_frame
		if is_instance_valid(boss) and boss.is_alive():
			phases[String(boss.get("phase"))] = true
			min_x = minf(min_x, boss.global_position.x)
			max_x = maxf(max_x, boss.global_position.x)

	var leash_end: float = boss.leash_rect.end.x if is_instance_valid(boss) else 0.0
	var attacked: bool = phases.has("tel") and phases.has("hit")
	var leashed: bool = (not is_instance_valid(boss)) or boss.within_leash(boss.global_position)

	# Kill the boss and confirm defeat routes to the claimable objective state live.
	if is_instance_valid(boss) and boss.is_alive():
		boss.take_damage(9999.0, 0, arena.player)
	await physics_frame
	var claimable: bool = String(arena.get_side_boss_state(0).get("objective_state", "")) == "claimable"

	var problems: Array[String] = []
	if not attacked:
		problems.append("boss did not run TEL/HIT over live frames; phases=%s" % str(phases.keys()))
	if not leashed:
		problems.append("boss left its leash live; max_x=%.1f end=%.1f" % [max_x, leash_end])
	if not claimable:
		problems.append("boss defeat did not set claimable; state=%s" % str(arena.get_side_boss_state(0)))

	if problems.is_empty():
		print("bb_boss_live_smoke RESULT=PASS phases=%s x_range=[%.0f,%.0f] leash_end=%.0f claimable=%s" % [
			str(phases.keys()), min_x, max_x, leash_end, str(claimable)])
		quit(0)
	else:
		print("bb_boss_live_smoke RESULT=FAIL")
		for p in problems:
			print("  - " + p)
		quit(1)

func _boss_actor(arena: Node, zone_id: String) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == zone_id:
			return enc
	return null
