extends SceneTree
## BB-BOSS-4: an OWNER claim grants the habitat-stock buff AND sends the boss's terrain
## disruption to the enemy side; an ENEMY steal grants the buff only (no disruption). The
## boss-stock buff is a separate channel from the capped breeding buffs.

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("boss_reward_routing check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_reward_routing check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []

	# --- Owner claim: blue claims the blue side boss -------------------------------
	_activate_and_down_boss(arena, 0)
	var blue_zone := _real_boss_zone(arena, "blue")
	_drive_claim(arena, blue_zone, 0)
	if String(blue_zone.get("objective_state", "")) != "claimed":
		failures.append("owner blue claim should reach claimed; state=%s" % String(blue_zone.get("objective_state", "")))
	# Buff went to blue (champsosaurus -> move_speed), and red got none.
	if arena.get_team_boss_stock_summary(0).get("total_stacks", 0) < 1:
		failures.append("blue owner claim should grant a boss-stock stack; summary=%s" % str(arena.get_team_boss_stock_summary(0)))
	if arena.get_team_boss_stock_effect(0, "move_speed") <= 0.0:
		failures.append("blue owner claim should grant a move_speed effect; got %f" % arena.get_team_boss_stock_effect(0, "move_speed"))
	if arena.get_team_boss_stock_summary(1).get("total_stacks", 0) != 0:
		failures.append("red should have no boss-stock buff from blue's claim; summary=%s" % str(arena.get_team_boss_stock_summary(1)))
	# Owner claim sent a terrain disruption to the ENEMY (red) side.
	var owner_events: Array = arena.get_active_terrain_events()
	var enemy_side_event := false
	for event: Dictionary in owner_events:
		if int(event.get("team", -1)) == 1:
			enemy_side_event = true
	if not enemy_side_event:
		failures.append("owner claim should fire an enemy-side (red) terrain event; events=%s" % str(owner_events))

	# --- Enemy steal: blue steals the red side boss -------------------------------
	var events_before_steal: int = arena.get_active_terrain_events().size()
	var blue_stacks_before: int = arena.get_team_boss_stock_summary(0).get("total_stacks", 0)
	_activate_and_down_boss(arena, 1)
	var red_zone := _real_boss_zone(arena, "red")
	_drive_claim(arena, red_zone, 0)  # BLUE controls RED's zone -> steal
	if String(red_zone.get("objective_state", "")) != "stolen":
		failures.append("blue steal of red boss should reach stolen; state=%s" % String(red_zone.get("objective_state", "")))
	if arena.get_team_boss_stock_summary(0).get("total_stacks", 0) <= blue_stacks_before:
		failures.append("steal should still grant the thief (blue) a buff stack; before=%d after=%d" % [blue_stacks_before, arena.get_team_boss_stock_summary(0).get("total_stacks", 0)])
	# A steal grants NO terrain disruption -> no new terrain event added.
	if arena.get_active_terrain_events().size() != events_before_steal:
		failures.append("steal must not fire a terrain event; before=%d after=%d" % [events_before_steal, arena.get_active_terrain_events().size()])

	print("boss_reward_routing failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _real_boss_zone(arena: Node, side: String) -> Dictionary:
	for zone: Dictionary in arena.animal_zone_states:
		if String(zone.get("side", "")) == side and String(zone.get("group", "")) == "Boss":
			return zone
	return {}

func _activate_and_down_boss(arena: Node, team: int) -> void:
	for _i in range(5):
		arena._record_bred_animal(team)
	for enc in arena.wildlife_encounters.duplicate():
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == "%s:Boss" % ("blue" if team == 0 else "red"):
			arena.on_wildlife_defeated(enc, arena.player)

func _drive_claim(arena: Node, zone: Dictionary, control_team: int) -> void:
	zone["contested"] = false
	zone["control_team"] = control_team
	var guard := 0
	while arena._is_boss_claim_phase(zone) and guard < 100:
		zone["contested"] = false
		zone["control_team"] = control_team
		arena._advance_boss_claim(zone, 1.0)
		guard += 1
