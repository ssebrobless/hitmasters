extends SceneTree
## BB-BOSS-4: a downed side boss is won through a CONTESTED presence window, not last-hit.
## Owner-controlled -> claimed; enemy-controlled -> stolen; both teams present -> contesting
## (frozen); a team seizing the point from another restarts progress (no carry-over).

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("boss_claim_steal check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_claim_steal check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []

	# Down the blue boss -> claimable.
	_activate_and_down_boss(arena, 0)
	var zone := _real_boss_zone(arena, "blue")
	if String(zone.get("objective_state", "")) != "claimable":
		failures.append("downed boss should be claimable; state=%s" % String(zone.get("objective_state", "")))

	# Contested: both teams present -> contesting, progress frozen.
	zone["contested"] = true
	zone["control_team"] = -1
	var frozen_progress := float(zone.get("claim_progress", 0.0))
	arena._advance_boss_claim(zone, 1.0)
	if String(zone.get("objective_state", "")) != "contesting":
		failures.append("both-team presence should read contesting; state=%s" % String(zone.get("objective_state", "")))
	if not is_equal_approx(float(zone.get("claim_progress", 0.0)), frozen_progress):
		failures.append("contested claim must not accrue progress; %f -> %f" % [frozen_progress, float(zone.get("claim_progress", 0.0))])

	# A partial red hold, then blue seizes the point: progress restarts under blue.
	zone["contested"] = false
	zone["control_team"] = 1
	arena._advance_boss_claim(zone, 2.0)  # red holds 2s
	if int(zone.get("claim_team", -1)) != 1 or float(zone.get("claim_progress", 0.0)) <= 0.0:
		failures.append("red partial hold should own progress; claim_team=%d progress=%f" % [int(zone.get("claim_team", -1)), float(zone.get("claim_progress", 0.0))])
	zone["control_team"] = 0
	arena._advance_boss_claim(zone, 1.0)  # blue seizes -> restart at this step
	if int(zone.get("claim_team", -1)) != 0 or float(zone.get("claim_progress", 0.0)) > 1.01:
		failures.append("blue seizing should restart progress (no carry-over); claim_team=%d progress=%f" % [int(zone.get("claim_team", -1)), float(zone.get("claim_progress", 0.0))])

	# Blue holds to completion -> claimed (owner).
	_drive_claim(arena, zone, 0)
	if String(zone.get("objective_state", "")) != "claimed":
		failures.append("blue holding its own boss to completion should be claimed; state=%s" % String(zone.get("objective_state", "")))
	if int(zone.get("claimed_team", -1)) != 0:
		failures.append("claimed_team should be blue; got %d" % int(zone.get("claimed_team", -1)))

	# Fresh red boss stolen by blue -> stolen (enemy).
	_activate_and_down_boss(arena, 1)
	var red_zone := _real_boss_zone(arena, "red")
	_drive_claim(arena, red_zone, 0)
	if String(red_zone.get("objective_state", "")) != "stolen":
		failures.append("blue completing on red's boss should be stolen; state=%s" % String(red_zone.get("objective_state", "")))
	if int(red_zone.get("claimed_team", -1)) != 0:
		failures.append("stolen claimed_team should be blue (thief); got %d" % int(red_zone.get("claimed_team", -1)))

	print("boss_claim_steal failures=%d" % failures.size())
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
	var guard := 0
	while arena._is_boss_claim_phase(zone) and guard < 100:
		zone["contested"] = false
		zone["control_team"] = control_team
		arena._advance_boss_claim(zone, 1.0)
		guard += 1
