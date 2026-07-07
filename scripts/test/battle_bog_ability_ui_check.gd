extends SceneTree

# UI pass acceptance: ability bar carries roster-designated ability names
# and live cooldown state; the hold-P info panel assembles the controlled
# creature's full kit text from the roster JSON.

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "3v3"
		config.set_selected_creature("snapping_turtle")
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("ability ui check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	_check_ability_bar(arena, failures)
	_check_info_panel(arena, failures)
	print("ability_ui failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_ability_bar(arena: Node, failures: Array[String]) -> void:
	if arena.ability_bar == null:
		failures.append("arena should build an ability bar")
		return
	var slots: Array = arena.ability_bar.get_ability_slots()
	if slots.size() != 3:
		failures.append("ability bar expected 3 slots (LMB/Q/E), got %d" % slots.size())
		return
	var names: Array[String] = []
	for slot in slots:
		names.append(String(slot.name))
	# Snapping Turtle's designated names straight from the roster.
	if not names.has("Grab") or not names.has("Lingual Lure"):
		failures.append("ability bar should carry roster ability names, got %s" % str(names))
	# Live cooldown state: force Q onto cooldown and re-read.
	arena.player.q_timer = 3.0
	var refreshed: Array = arena.ability_bar.get_ability_slots()
	for slot in refreshed:
		if String(slot.key) == "Q" and absf(float(slot.remaining) - 3.0) > 0.001:
			failures.append("ability bar Q remaining should read the live timer, got %f" % float(slot.remaining))
	arena.player.q_timer = 0.0

func _check_info_panel(arena: Node, failures: Array[String]) -> void:
	if arena.info_panel == null:
		failures.append("arena should build the hold-P info panel")
		return
	if arena.info_panel.visible:
		failures.append("info panel should start hidden (shown only while P is held)")
	var text := "\n".join(arena.info_panel.get_info_lines())
	for expected in ["Snapping Turtle", "Footprint circle", "Height Body Heavy Low", "Grab", "Lingual Lure", "Protective Shell", "Controls:"]:
		if not text.contains(expected):
			failures.append("info panel text missing '%s'" % expected)
