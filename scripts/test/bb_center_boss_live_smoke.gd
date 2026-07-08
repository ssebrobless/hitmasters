extends SceneTree
## On-demand LIVE integration smoke for the Teratornis center boss (NOT a *_check.gd). Boots a
## real 1v1 arena, summons the center boss, and lets the ENGINE drive it for a few sim-seconds
## with a target planted nearby -- verifying it runs its attack grammar, reveals fighters
## through the vision service, and routes defeat to the claim window. Run:
##   godot --headless --path . --script scripts/test/bb_center_boss_live_smoke.gd

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		print("bb_center_boss_live_smoke RESULT=FAIL reason=arena_boot")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		print("bb_center_boss_live_smoke RESULT=FAIL reason=no_arena")
		quit(1)
		return

	# This smoke is specifically for Grand Hunt Shadow/reveal, so force Teratornis
	# instead of using the now-generic random center-boss debug roll.
	arena._spawn_center_boss("teratornis")
	var boss: Node = _center_actor(arena)
	if boss == null:
		print("bb_center_boss_live_smoke RESULT=FAIL reason=no_boss_spawned")
		quit(1)
		return

	var phases := {}
	var revealed_to_enemy := false
	for _i in range(360):
		if is_instance_valid(arena.player) and arena.player.has_method("is_alive") and arena.player.is_alive():
			arena.player.global_position = boss.global_position + Vector2(40.0, 0.0)
		await physics_frame
		if is_instance_valid(boss) and boss.is_alive():
			phases[String(boss.get("phase"))] = true
			# player is blue (team 0); Grand Hunt Shadow should reveal it to red (team 1)
			if is_instance_valid(arena.player) and arena.get_entity_info_state(arena.player, 1) == "revealed":
				revealed_to_enemy = true

	var attacked: bool = phases.has("tel") and phases.has("hit")

	if is_instance_valid(boss) and boss.is_alive():
		boss.take_damage(99999.0, 0, arena.player)
	await physics_frame
	var claimable_or_claimed := String(_center_zone_state(arena)) in ["claimable", "contesting", "claimed"]

	var problems: Array[String] = []
	if not attacked:
		problems.append("center boss did not run TEL/HIT; phases=%s" % str(phases.keys()))
	if not revealed_to_enemy:
		problems.append("Grand Hunt Shadow never revealed the player to the enemy team")
	if not claimable_or_claimed:
		problems.append("center boss defeat did not enter the claim window; state=%s" % _center_zone_state(arena))

	if problems.is_empty():
		print("bb_center_boss_live_smoke RESULT=PASS phases=%s revealed=%s state=%s" % [str(phases.keys()), str(revealed_to_enemy), _center_zone_state(arena)])
		quit(0)
	else:
		print("bb_center_boss_live_smoke RESULT=FAIL")
		for p in problems:
			print("  - " + p)
		quit(1)

func _center_actor(arena: Node) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and enc.has_method("is_center_boss") and enc.is_center_boss():
			return enc
	return null

func _center_zone_state(arena: Node) -> String:
	for zone: Dictionary in arena.animal_zone_states:
		if bool(zone.get("center_boss", false)):
			return String(zone.get("objective_state", ""))
	return ""
