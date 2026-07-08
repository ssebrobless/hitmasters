extends SceneTree
## BB-BOSS-4: the boss's timed terrain disruption fires on OWNER claim only, lands on the
## ENEMY side, and expires after its window (a timed overlay, never a permanent mutation).

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("boss_terrain_event check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_terrain_event check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []

	# No terrain events at match start.
	if not arena.get_active_terrain_events().is_empty():
		failures.append("fresh match should have no terrain events; got %s" % str(arena.get_active_terrain_events()))

	# A steal (enemy controls the zone) fires NO terrain event.
	_activate_and_down_boss(arena, 1)  # red boss
	var red_zone := _real_boss_zone(arena, "red")
	_drive_claim(arena, red_zone, 0)   # blue steals red's boss
	if not arena.get_active_terrain_events().is_empty():
		failures.append("a steal must not fire a terrain event; got %s" % str(arena.get_active_terrain_events()))

	# An owner claim fires exactly one enemy-side timed event.
	_activate_and_down_boss(arena, 0)  # blue boss
	var blue_zone := _real_boss_zone(arena, "blue")
	_drive_claim(arena, blue_zone, 0)  # blue claims its own boss
	var events: Array = arena.get_active_terrain_events()
	if events.size() != 1:
		failures.append("owner claim should fire exactly one terrain event; got %d" % events.size())
	else:
		var event: Dictionary = events[0]
		if int(event.get("team", -1)) != 1:
			failures.append("terrain event should target the enemy (red) side; team=%d" % int(event.get("team", -1)))
		if float(event.get("remaining", 0.0)) <= 0.0:
			failures.append("terrain event should start with time remaining; got %f" % float(event.get("remaining", 0.0)))
		if String(event.get("kind", "")) != "flood_scar":
			failures.append("champsosaurus event should be flood_scar; kind=%s" % String(event.get("kind", "")))

	# The event expires after its window (timed overlay, not a permanent mutation).
	arena._tick_boss_terrain_events(999.0)
	if not arena.get_active_terrain_events().is_empty():
		failures.append("terrain event should expire after its duration; got %s" % str(arena.get_active_terrain_events()))

	print("boss_terrain_event failures=%d" % failures.size())
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
