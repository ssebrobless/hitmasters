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
	var preview := scene.get_node("Root/Content/Details/HeroPreview")
	var select_text_ok := identity_label != null \
		and matchup_label != null \
		and not identity_label.text.is_empty() \
		and matchup_label.text.begins_with("Wins:") \
		and matchup_label.text.contains("\nFears:")
	var preview_ok := _check_preview_scale_read(preview)
	var roster_identity_ok := true
	for creature_id in ["snapping_turtle", "chorus_frog", "mink", "beaver", "owl", "duck"]:
		var creature: Dictionary = catalog.get_creature(creature_id)
		roster_identity_ok = roster_identity_ok \
			and not String(creature.get("identity_blurb", "")).is_empty() \
			and creature.get("wins", []) is Array \
			and not Array(creature.get("wins", [])).is_empty() \
			and creature.get("fears", []) is Array \
			and not Array(creature.get("fears", [])).is_empty()
	print("select_creatures=%d selectable=%d remembered=%s selected=%s select_text=%s preview=%s roster_identity=%s" % [
		creature_buttons,
		selectable_buttons,
		str(remembered),
		config.selected_creature_id,
		str(select_text_ok),
		str(preview_ok),
		str(roster_identity_ok)
	])
	quit(0 if creature_buttons == 21 and selectable_buttons == 21 and remembered and select_text_ok and preview_ok and roster_identity_ok else 1)

func _check_preview_scale_read(preview: Node) -> bool:
	if preview == null or not preview.has_method("set_creature"):
		return false
	preview.set_creature("great_blue_heron", 0)
	var heron: Dictionary = preview.call("_preview_motion_state")
	preview.set_creature("bog_turtle", 0)
	var bog: Dictionary = preview.call("_preview_motion_state")
	preview.set_creature("firefly", 0)
	var firefly: Dictionary = preview.call("_preview_motion_state")
	preview.set_creature("alligator", 0)
	var gator_footprint: Dictionary = preview.call("_preview_footprint")
	return float(heron.get("model_scale", 1.0)) > 1.2 \
		and String(heron.get("height_class", "")) == "tall_wader" \
		and String(heron.get("height_band", "")) == "high" \
		and not bool(heron.get("airborne_preview", true)) \
		and float(bog.get("model_scale", 1.0)) < 0.9 \
		and String(bog.get("height_band", "")) == "low" \
		and bool(firefly.get("airborne_preview", false)) \
		and float(firefly.get("height_units", 0.0)) >= 0.9 \
		and String(firefly.get("height_class", "")) == "tiny_hoverer" \
		and String(gator_footprint.get("shape", "")) == "capsule" \
		and float(gator_footprint.get("length_px", 0.0)) > float(gator_footprint.get("radius_px", 0.0)) * 2.5
