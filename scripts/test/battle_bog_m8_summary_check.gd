extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const BLUE := 0
const RED := 1
const StockManagerScript := preload("res://scripts/game/stock_manager.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("m8 summary check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or not arena.has_method("get_match_summary_data"):
		push_error("Arena scene did not expose M8 summary data; current_scene=%s" % str(arena))
		quit(1)
		return

	_check_match_summary_telemetry(arena, failures)

	print("m8_summary failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_match_summary_telemetry(arena: Node, failures: Array[String]) -> void:
	arena.elapsed = 125.0
	var blue_actor: Node = arena.player
	var blue_second: Node = arena.player_squad[1]
	var red_actor: Node = arena.bots[0]
	var red_hut: Node = _first_hut(arena, RED)
	if blue_actor == null or blue_second == null or red_actor == null or red_hut == null:
		failures.append("summary check expected blue squad, red bot, and red hut to exist.")
		return

	arena.record_core_damage(BLUE, 123.0, blue_actor)
	red_hut.take_damage(red_hut.health, BLUE, blue_actor)
	arena._consume_stock_for_death(blue_actor)

	arena.habitat_deposit_feedback_timer = 0.0
	_satiate_in_habitat(blue_actor, arena)
	var deposited: bool = arena._try_manual_habitat_deposit(blue_actor)
	arena._tick_breeding(StockManagerScript.BREEDING_DURATION_SEC + 0.1)

	arena.habitat_deposit_feedback_timer = 0.0
	_satiate_in_habitat(blue_second, arena)
	var deny_deposit: bool = arena._try_manual_habitat_deposit(blue_second)
	var denied := false
	if deny_deposit and not arena.breeding_actors.is_empty():
		arena.on_breeding_actor_defeated(arena.breeding_actors[0], red_actor)
		denied = true

	var summary: Dictionary = arena.get_match_summary_data("Blue")
	var teams: Dictionary = summary.get("teams", {})
	var blue: Dictionary = teams.get("blue", {})
	var red: Dictionary = teams.get("red", {})
	var draft: Dictionary = summary.get("draft", {})
	var selected_squad: Array = summary.get("selected_squad_ids", [])
	var text: String = arena._get_match_summary("Blue")
	var scoreboard_text: String = arena._get_scoreboard_text()
	var player_rows: Array = summary.get("players", [])

	var data_ok := String(summary.get("winner", "")) == "Blue" \
		and String(summary.get("time", "")) == "02:05" \
		and int(blue.get("stock_losses", 0)) == 1 \
		and int(blue.get("deposits", 0)) == 2 \
		and int(blue.get("breeds_completed", 0)) == 1 \
		and int(red.get("breeds_denied", 0)) == 1 \
		and int(blue.get("huts_destroyed", 0)) == 1 \
		and float(blue.get("hut_damage", 0.0)) >= 799.0 \
		and int(blue.get("core_damage", 0)) == 123 \
		and int(blue.get("max_stocks", 0)) == 9 \
		and int(blue.get("stocks_remaining", 0)) == 8 \
		and String(summary.get("selected_creature_id", "")) == "duck" \
		and selected_squad.size() == 3 \
		and selected_squad.has("duck") \
		and bool(draft.get("enabled", false)) \
		and int(draft.get("ban_slots_per_team", 0)) == 1
	var text_ok: bool = text.contains("Stocks lost 1/9") \
		and text.contains("Deposits 2") \
		and text.contains("Breeds 1/0 denied") \
		and text.contains("Breeds 0/1 denied") \
		and text.contains("HutDmg") \
		and text.contains("CoreDmg 123") \
		and text.contains("Buffs") \
		and text.contains("Top Blue:") \
		and text.contains("Top Red:") \
		and text.contains("Dep 1") \
		and text.contains("deny")
	var player_rows_ok := _row_has_stat(player_rows, "Duck", "deposits", 1) \
		and _row_has_stat(player_rows, "Duck", "stock_losses", 1) \
		and _row_has_stat(player_rows, "Duck", "hut_damage", 799.0) \
		and _row_has_stat(player_rows, "Red", "breeds_denied", 1)
	var scoreboard_ok := scoreboard_text.contains("Flow") \
		and scoreboard_text.contains("Stocks 8/9") \
		and scoreboard_text.contains("Lost1") \
		and scoreboard_text.contains("Dep2") \
		and scoreboard_text.contains("Hut800") \
		and scoreboard_text.contains("Dep1")
	arena._finish_match("Blue", "test_summary", "Blue wins test")
	var log_state: Dictionary = _read_summary_log(arena.get_last_match_summary_log_path())
	var log_data: Dictionary = log_state.get("data", {})
	var log_teams: Dictionary = log_data.get("teams", {})
	var log_blue: Dictionary = log_teams.get("blue", {})
	var log_red: Dictionary = log_teams.get("red", {})
	var log_draft: Dictionary = log_data.get("draft", {})
	var log_squad: Array = log_data.get("selected_squad_ids", [])
	var log_ok := bool(log_state.get("ok", false)) \
		and bool(arena.match_over) \
		and String(log_data.get("winner", "")) == "Blue" \
		and String(log_data.get("reason", "")) == "test_summary" \
		and String(log_data.get("selected_creature_id", "")) == "duck" \
		and log_squad.has("snapping_turtle") \
		and bool(log_draft.get("enabled", false)) \
		and int(log_draft.get("pick_slots_per_team", 0)) == 3 \
		and int(log_blue.get("stock_losses", 0)) == 1 \
		and int(log_blue.get("deposits", 0)) == 2 \
		and int(log_blue.get("breeds_completed", 0)) == 1 \
		and int(log_red.get("breeds_denied", 0)) == 1 \
		and int(log_blue.get("core_damage", 0)) == 123

	if not deposited or not denied or not data_ok or not text_ok or not player_rows_ok or not scoreboard_ok or not log_ok:
		failures.append("M8 summary should report stocks, deposits, breeding, hut damage, core damage, player rows, live scoreboard flow, and a JSON match log; deposited=%s denied=%s data_ok=%s text_ok=%s player_rows_ok=%s scoreboard_ok=%s log_ok=%s summary=%s text=%s scoreboard=%s rows=%s log=%s" % [
			str(deposited),
			str(denied),
			str(data_ok),
			str(text_ok),
			str(player_rows_ok),
			str(scoreboard_ok),
			str(log_ok),
			str(summary),
			text,
			scoreboard_text,
			str(player_rows),
			str(log_state)
		])

func _first_hut(arena: Node, team: int) -> Node:
	for hut in arena.huts:
		if hut != null and is_instance_valid(hut) and int(hut.team) == team:
			return hut
	return null

func _satiate_in_habitat(actor: Node, arena: Node) -> void:
	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(actor.team)
	actor.global_position = habitat.get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true

func _row_has_stat(rows: Array, name_part: String, stat: String, minimum: Variant) -> bool:
	for row: Dictionary in rows:
		if not String(row.get("name", "")).contains(name_part):
			continue
		if typeof(minimum) == TYPE_FLOAT:
			return float(row.get(stat, 0.0)) >= float(minimum)
		return int(row.get(stat, 0)) >= int(minimum)
	return false

func _read_summary_log(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "path": path, "reason": "missing_file"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "path": path, "reason": "open_failed", "error": FileAccess.get_open_error()}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "path": path, "reason": "parse_failed", "text": text}
	return {"ok": true, "path": path, "data": parsed}
