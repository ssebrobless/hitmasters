extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null or not catalog.load_catalog():
		push_error("CreatureCatalog failed before draft stub check.")
		quit(1)
		return

	var config := get_root().get_node_or_null("GameConfig")
	config.selected_mode = "1v1"
	config.clear_draft_bans()
	config.set_draft_bans(["mink"], ["owl"])
	config.set_selected_squad_ids(["mink", "owl", "duck"])

	var draft_state: Dictionary = config.get_draft_stub_state()
	var squad: Array[String] = config.get_selected_squad_ids()
	var state_ok := bool(draft_state.get("enabled", false)) \
		and bool(draft_state.get("enforced", false)) \
		and int(draft_state.get("ban_slots_per_team", 0)) == 1 \
		and int(draft_state.get("pick_slots_per_team", 0)) == 3 \
		and Array(draft_state.get("blue_bans", [])).has("mink") \
		and Array(draft_state.get("red_bans", [])).has("owl") \
		and not squad.has("mink") \
		and not squad.has("owl") \
		and squad.has("duck")

	var error := change_scene_to_file("res://scenes/CharacterSelect.tscn")
	if error != OK:
		push_error("draft stub check failed to boot CharacterSelect: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame

	var scene := current_scene
	var list := scene.get_node("Root/Content/HeroScroll/HeroList")
	var squad_hint := scene.get_node("Root/Header/SquadPanel/SquadHint") as Label
	var mink_button := _button_for_creature(scene, list, "mink")
	var owl_button := _button_for_creature(scene, list, "owl")
	var duck_button := _button_for_creature(scene, list, "duck")
	var ui_ok := mink_button != null \
		and owl_button != null \
		and duck_button != null \
		and bool(mink_button.disabled) \
		and bool(owl_button.disabled) \
		and not bool(duck_button.disabled) \
		and bool(mink_button.get_meta("banned", false)) \
		and bool(owl_button.get_meta("banned", false)) \
		and String(mink_button.text).contains("banned") \
		and String(owl_button.text).contains("banned") \
		and squad_hint != null \
		and squad_hint.text.contains("Draft bans:") \
		and squad_hint.text.contains("Mink") \
		and squad_hint.text.contains("Owl")

	print("m8_draft_stub state=%s ui=%s squad=%s" % [str(state_ok), str(ui_ok), str(squad)])
	quit(0 if state_ok and ui_ok else 1)

func _button_for_creature(scene: Node, list: Node, creature_id: String) -> Button:
	for child in list.get_children():
		var button := child as Button
		if button == null or not button.has_meta("creature_index"):
			continue
		var index := int(button.get_meta("creature_index"))
		var creatures: Array = scene.get("creatures")
		if index >= 0 and index < creatures.size() and String(creatures[index].get("id", "")) == creature_id:
			return button
	return null
