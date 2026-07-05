extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const BLUE := 0
const RED := 1
const REQUIRED_ROW_KEYS := ["team", "slot_index", "creature_id", "name", "active", "hp_ratio", "stocks", "max_stocks", "state"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	var arena := await _boot_trio_arena(failures)
	if arena == null:
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	if not _check_arena_spawned_trio(arena, failures):
		print("m5_trio_ux stock=false rows=false switch=false stock_state=false prompt=false rail=false hud=false")
		for failure in failures:
			push_error(failure)
		quit(1)
		return

	var stock_ok := _check_stock_manager_slots(arena, failures)
	var rows_ok := _check_hud_rows(arena, failures)
	var switch_ok := _check_switch_feedback(arena, failures)
	var stock_state_ok := _check_stock_state_row(arena, failures)
	var prompt_ok := _check_deposit_prompt(arena, failures)
	var rail_ok := _check_dense_rail_removed(arena, failures)
	var hud_node_ok := arena.get("squad_hud") != null
	if not hud_node_ok:
		failures.append("Arena expected squad_hud node to be wired for trio UI.")

	var passed := stock_ok and rows_ok and switch_ok and stock_state_ok and prompt_ok and rail_ok and hud_node_ok
	print("m5_trio_ux stock=%s rows=%s switch=%s stock_state=%s prompt=%s rail=%s hud=%s" % [
		str(stock_ok),
		str(rows_ok),
		str(switch_ok),
		str(stock_state_ok),
		str(prompt_ok),
		str(rail_ok),
		str(hud_node_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_arena_spawned_trio(arena: Node, failures: Array[String]) -> bool:
	var squad: Array = arena.get("player_squad")
	var bots: Array = arena.get("bots")
	var player: Node = arena.get("player")
	var ok := squad.size() == 3 and bots.size() == 3 and player != null
	if not ok:
		failures.append("Arena did not finish trio spawn before UX checks; squad=%d bots=%d player=%s" % [
			squad.size(),
			bots.size(),
			str(player != null)
		])
	return ok

func _boot_trio_arena(failures: Array[String]) -> Node:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		var squad_ids: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
		config.set_selected_squad_ids(squad_ids)

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		failures.append("failed to boot Arena scene for M5 trio UX check: error=%d" % error)
		return null
	await process_frame
	await process_frame
	if current_scene == null:
		failures.append("Arena scene did not become current_scene for M5 trio UX check.")
	return current_scene

func _check_stock_manager_slots(arena: Node, failures: Array[String]) -> bool:
	if arena.get("stock_manager") == null or not arena.stock_manager.has_method("get_team_slots"):
		failures.append("StockManager expected get_team_slots(team).")
		return false
	var blue_slots: Array = arena.stock_manager.get_team_slots(BLUE)
	var red_slots: Array = arena.stock_manager.get_team_slots(RED)
	var ok := blue_slots.size() == 3 and red_slots.size() == 3 and _slot_indices(blue_slots) == [0, 1, 2] and _slot_indices(red_slots) == [0, 1, 2]
	if not ok:
		failures.append("get_team_slots expected 3 sorted blue/red slots; blue=%s red=%s" % [str(_slot_indices(blue_slots)), str(_slot_indices(red_slots))])
	return ok

func _check_hud_rows(arena: Node, failures: Array[String]) -> bool:
	if not arena.has_method("get_squad_hud_data") or not arena.has_method("get_trio_hud_rows"):
		failures.append("Arena expected get_squad_hud_data() and get_trio_hud_rows(team).")
		return false
	var data: Dictionary = arena.get_squad_hud_data()
	var own_rows: Array = data.get("own", [])
	var enemy_rows: Array = data.get("enemy", [])
	var ok := bool(data.get("enabled", false)) and own_rows.size() == 3 and enemy_rows.size() == 3
	ok = ok and _rows_have_shape(own_rows, true, failures)
	ok = ok and _rows_have_shape(enemy_rows, false, failures)
	ok = ok and _active_slot(own_rows) == 0
	ok = ok and _enemy_has_no_active_slot(enemy_rows)
	if not ok:
		failures.append("trio HUD data expected enabled own/enemy rows with blue slot 1 active.")
	return ok

func _check_switch_feedback(arena: Node, failures: Array[String]) -> bool:
	arena._set_active_squad_index(1, false)
	var feedback: Dictionary = arena.get_squad_switch_feedback_state()
	var own_rows: Array = arena.get_trio_hud_rows(BLUE)
	var ok := String(feedback.get("state", "")) == "active" and int(feedback.get("slot_index", -1)) == 1 and float(feedback.get("timer", 0.0)) > 0.0 and _active_slot(own_rows) == 1
	if not ok:
		failures.append("switch feedback expected active slot 2 with timer; feedback=%s active_slot=%d" % [str(feedback), _active_slot(own_rows)])
	return ok

func _check_stock_state_row(arena: Node, failures: Array[String]) -> bool:
	var actor: Node = arena.player_squad[1]
	arena.stock_manager.record_ko(actor, 4.0)
	var own_rows: Array = arena.get_trio_hud_rows(BLUE)
	var row: Dictionary = own_rows[1]
	var ok := int(row.get("stocks", -1)) == 2 and int(row.get("max_stocks", -1)) == 3 and String(row.get("state", "")) == "respawning"
	if not ok:
		failures.append("row expected stock state to reflect StockManager KO; row=%s" % str(row))
	return ok

func _check_deposit_prompt(arena: Node, failures: Array[String]) -> bool:
	var rect: Rect2 = arena.terrain_map.get_team_habitat_rect(BLUE)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		failures.append("blue habitat rect missing; cannot check deposit prompt state.")
		return false
	arena.player.global_position = rect.position + rect.size * 0.5
	var ready: Dictionary = arena.get_deposit_prompt_state()
	var accepted_result: bool = arena._try_manual_habitat_deposit(arena.player)
	var accepted: Dictionary = arena.get_deposit_prompt_state()
	var ok := bool(ready.get("visible", false)) and String(ready.get("state", "")) == "ready" and bool(ready.get("in_home_habitat", false))
	ok = ok and accepted_result and String(accepted.get("state", "")) == "accepted" and float(accepted.get("timer", 0.0)) > 0.0
	if not ok:
		failures.append("deposit prompt expected ready then accepted states; ready=%s accepted=%s result=%s" % [str(ready), str(accepted), str(accepted_result)])
	return ok

func _check_dense_rail_removed(arena: Node, failures: Array[String]) -> bool:
	arena._update_ui()
	var cooldown_text := String(arena.cooldown_label.text)
	var ok := not cooldown_text.contains("Squad ") and not cooldown_text.contains("stocks")
	if not ok:
		failures.append("cooldown label should no longer contain dense trio stock rail; text=%s" % cooldown_text)
	return ok

func _rows_have_shape(rows: Array, own_team: bool, failures: Array[String]) -> bool:
	var ok := true
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			failures.append("row expected Dictionary; got %s" % str(row_value))
			ok = false
			continue
		var row: Dictionary = row_value
		for key in REQUIRED_ROW_KEYS:
			if not row.has(key):
				failures.append("row missing key '%s': %s" % [key, str(row)])
				ok = false
		var hp_ratio := float(row.get("hp_ratio", -1.0))
		if hp_ratio < 0.0 or hp_ratio > 1.0:
			failures.append("row hp_ratio expected 0..1: %s" % str(row))
			ok = false
		if String(row.get("creature_id", "")).is_empty() or String(row.get("name", "")).is_empty():
			failures.append("row expected non-empty name/id: %s" % str(row))
			ok = false
		if int(row.get("stocks", -1)) < 0 or int(row.get("max_stocks", -1)) < int(row.get("stocks", 0)):
			failures.append("row expected valid stocks/max_stocks: %s" % str(row))
			ok = false
		if own_team and typeof(row.get("active", null)) != TYPE_BOOL:
			failures.append("own row expected boolean active flag: %s" % str(row))
			ok = false
	return ok

func _enemy_has_no_active_slot(rows: Array) -> bool:
	for row: Dictionary in rows:
		if bool(row.get("active", false)):
			return false
	return true

func _active_slot(rows: Array) -> int:
	for row: Dictionary in rows:
		if bool(row.get("active", false)):
			return int(row.get("slot_index", -1))
	return -1

func _slot_indices(slots: Array) -> Array[int]:
	var output: Array[int] = []
	for slot: Dictionary in slots:
		output.append(int(slot.get("slot_index", -1)))
	return output
