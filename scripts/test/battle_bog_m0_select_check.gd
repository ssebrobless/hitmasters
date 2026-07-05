extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null or not catalog.load_catalog():
		push_error("CreatureCatalog failed before select check.")
		quit(1)
		return

	var config := get_root().get_node_or_null("GameConfig")
	config.selected_mode = "3v3"
	config.set_selected_creature("snapping_turtle")

	change_scene_to_file("res://scenes/CharacterSelect.tscn")
	await process_frame
	await process_frame

	var scene := current_scene
	var list := scene.get_node("Root/Content/HeroScroll/HeroList")
	var creature_buttons := 0
	var selectable_buttons := 0
	var second_selectable: Button = null
	for child in list.get_children():
		var button := child as Button
		if button == null or not button.has_meta("creature_index"):
			continue
		creature_buttons += 1
		if bool(button.get_meta("selectable")):
			selectable_buttons += 1
			if second_selectable == null and int(button.get_meta("creature_index")) != 4:
				second_selectable = button

	if second_selectable != null:
		second_selectable.pressed.emit()

	var remembered: bool = config.selected_creature_id != "snapping_turtle" and not config.selected_creature_id.is_empty()
	var identity_label := scene.get_node("Root/Content/Details/IdentityLabel") as Label
	var matchup_label := scene.get_node("Root/Content/Details/MatchupLabel") as Label
	var select_text_ok := identity_label != null \
		and matchup_label != null \
		and not identity_label.text.is_empty() \
		and matchup_label.text.begins_with("Wins:") \
		and matchup_label.text.contains("\nFears:")
	var roster_identity_ok := true
	for creature_id in ["snapping_turtle", "chorus_frog", "mink", "beaver", "owl", "duck"]:
		var creature: Dictionary = catalog.get_creature(creature_id)
		roster_identity_ok = roster_identity_ok \
			and not String(creature.get("identity_blurb", "")).is_empty() \
			and creature.get("wins", []) is Array \
			and not Array(creature.get("wins", [])).is_empty() \
			and creature.get("fears", []) is Array \
			and not Array(creature.get("fears", [])).is_empty()
	print("select_creatures=%d selectable=%d remembered=%s selected=%s select_text=%s roster_identity=%s" % [
		creature_buttons,
		selectable_buttons,
		str(remembered),
		config.selected_creature_id,
		str(select_text_ok),
		str(roster_identity_ok)
	])
	quit(0 if creature_buttons == 21 and selectable_buttons == 14 and remembered and select_text_ok and roster_identity_ok else 1)
