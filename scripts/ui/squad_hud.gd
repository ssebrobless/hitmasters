extends Control

const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

const PANEL_SIZE := Vector2(392.0, 176.0)
const ROW_HEIGHT := 31.0
const STOCK_PIP_SIZE := Vector2(10.0, 6.0)

var arena: Node = null
var redraw_accumulator := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PANEL_SIZE

func _process(delta: float) -> void:
	var should_show := arena != null and is_instance_valid(arena) and arena.has_method("get_squad_hud_data")
	if should_show:
		var data: Dictionary = arena.get_squad_hud_data()
		should_show = bool(data.get("enabled", false))
	visible = should_show
	if not should_show:
		return
	redraw_accumulator += delta
	if redraw_accumulator >= 0.1:
		redraw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	if arena == null or not is_instance_valid(arena) or not arena.has_method("get_squad_hud_data"):
		return
	var data: Dictionary = arena.get_squad_hud_data()
	if not bool(data.get("enabled", false)):
		return

	var panel := Rect2(Vector2.ZERO, PANEL_SIZE)
	draw_rect(panel, Color(0.035, 0.045, 0.04, 0.88))
	draw_rect(panel, Color(0.68, 0.75, 0.65, 0.48), false, 1.5)

	_draw_header(data)

	var own_rows: Array = data.get("own", [])
	for i in own_rows.size():
		_draw_slot_row(own_rows[i], Rect2(Vector2(10.0, 36.0 + ROW_HEIGHT * i), Vector2(246.0, ROW_HEIGHT - 4.0)), true)

	var enemy_rows: Array = data.get("enemy", [])
	_draw_enemy_strip(enemy_rows, Rect2(Vector2(270.0, 36.0), Vector2(112.0, 90.0)))
	_draw_prompt_strip(data, Rect2(Vector2(10.0, 136.0), Vector2(372.0, 28.0)))

func _draw_header(data: Dictionary) -> void:
	var command := String(data.get("command", "farm"))
	var command_timer := float(data.get("command_timer", 0.0))
	var command_color := VisualGrammar.command_color(command, 0.95)
	var command_text := command.to_upper()
	if command_timer > 0.0:
		command_text = "%s %.0f" % [command_text, ceili(command_timer)]
	draw_string(ThemeDB.fallback_font, Vector2(11.0, 21.0), "TRIO", HORIZONTAL_ALIGNMENT_LEFT, 48.0, 13, Color(0.93, 0.95, 0.9, 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(58.0, 21.0), command_text, HORIZONTAL_ALIGNMENT_LEFT, 92.0, 13, command_color)

	var feedback: Dictionary = data.get("switch_feedback", {})
	if float(feedback.get("timer", 0.0)) > 0.0:
		var state := String(feedback.get("state", "idle"))
		var slot := int(feedback.get("slot_index", -1)) + 1
		var label := "SWAP %d" % slot if state == "active" else "WAIT %d" % slot
		var color := Color(0.38, 0.78, 1.0, 0.95) if state == "active" else Color(1.0, 0.46, 0.34, 0.95)
		_draw_pill(Rect2(Vector2(152.0, 7.0), Vector2(74.0, 20.0)), label, color)

func _draw_slot_row(row: Dictionary, rect: Rect2, owned: bool) -> void:
	var team := int(row.get("team", 0))
	var active := bool(row.get("active", false))
	var state := String(row.get("state", "field"))
	var hp_ratio := clampf(float(row.get("hp_ratio", 0.0)), 0.0, 1.0)
	var team_color := VisualGrammar.team_color(team, 0.95)
	var background := Color(0.07, 0.08, 0.072, 0.9)
	if active:
		background = Color(0.08, 0.12, 0.14, 0.94)
	elif state == "exhausted":
		background = Color(0.08, 0.055, 0.05, 0.84)
	draw_rect(rect, background)
	draw_rect(rect, team_color if active else Color(0.42, 0.46, 0.4, 0.48), false, 2.0 if active else 1.0)

	var slot_label := str(int(row.get("slot_index", 0)) + 1)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 18.0), slot_label, HORIZONTAL_ALIGNMENT_LEFT, 14.0, 12, Color(0.96, 0.98, 0.92, 0.96))

	var name := _short_name(String(row.get("name", row.get("creature_id", ""))), 15 if owned else 10)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(28.0, 18.0), name, HORIZONTAL_ALIGNMENT_LEFT, 112.0, 12, Color(0.96, 0.98, 0.92, 0.96))

	var hp_rect := Rect2(rect.position + Vector2(146.0, 8.0), Vector2(48.0, 6.0))
	draw_rect(hp_rect, Color(0.02, 0.025, 0.024, 0.95))
	var hp_color := Color(0.36, 0.95, 0.42, 0.95)
	if hp_ratio < 0.35:
		hp_color = Color(1.0, 0.42, 0.24, 0.95)
	elif hp_ratio < 0.65:
		hp_color = Color(0.95, 0.78, 0.28, 0.95)
	if state == "exhausted":
		hp_color = Color(0.28, 0.25, 0.24, 0.95)
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * hp_ratio, hp_rect.size.y)), hp_color)

	_draw_stock_pips(rect.position + Vector2(146.0, 17.0), int(row.get("stocks", 0)), int(row.get("max_stocks", 3)), team_color)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(206.0, 18.0), _state_label(row), HORIZONTAL_ALIGNMENT_LEFT, 36.0, 11, _state_color(row))

func _draw_enemy_strip(rows: Array, rect: Rect2) -> void:
	draw_rect(rect, Color(0.045, 0.04, 0.038, 0.72))
	draw_rect(rect, VisualGrammar.team_color(1, 0.45), false, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 17.0), "ENEMY", HORIZONTAL_ALIGNMENT_LEFT, 88.0, 12, Color(1.0, 0.88, 0.84, 0.9))
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := rect.position.y + 25.0 + float(i) * 19.0
		var name := _short_name(String(row.get("name", row.get("creature_id", ""))), 8)
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 8.0, y + 11.0), "%d %s" % [int(row.get("slot_index", 0)) + 1, name], HORIZONTAL_ALIGNMENT_LEFT, 62.0, 10, Color(1.0, 0.92, 0.88, 0.88))
		var hp_ratio := clampf(float(row.get("hp_ratio", 0.0)), 0.0, 1.0)
		var hp_rect := Rect2(Vector2(rect.position.x + 70.0, y + 3.0), Vector2(30.0, 5.0))
		draw_rect(hp_rect, Color(0.02, 0.018, 0.018, 0.92))
		draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * hp_ratio, hp_rect.size.y)), VisualGrammar.team_color(1, 0.9))
		_draw_stock_pips(Vector2(rect.position.x + 70.0, y + 11.0), int(row.get("stocks", 0)), int(row.get("max_stocks", 3)), VisualGrammar.team_color(1, 0.88), Vector2(6.0, 4.0), 2.0)

func _draw_prompt_strip(data: Dictionary, rect: Rect2) -> void:
	draw_rect(rect, Color(0.045, 0.052, 0.048, 0.75))
	draw_rect(rect, Color(0.48, 0.55, 0.48, 0.38), false, 1.0)
	var prompt: Dictionary = data.get("deposit_prompt", {})
	var prompt_state := String(prompt.get("state", "hidden"))
	var prompt_text := ""
	var prompt_color := Color(0.68, 0.76, 0.68, 0.8)
	match prompt_state:
		"ready":
			prompt_text = "U DEPOSIT READY"
			prompt_color = Color(0.55, 1.0, 0.6, 0.95)
		"accepted":
			prompt_text = "HABITAT CHECK-IN"
			prompt_color = Color(0.55, 0.86, 1.0, 0.95)
		"needs_habitat":
			prompt_text = "ENTER HABITAT"
			prompt_color = Color(1.0, 0.58, 0.36, 0.95)
		"near":
			prompt_text = "HOME HABITAT NEAR"
		_:
			prompt_text = "STOCKS LIVE"
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, 18.0), prompt_text, HORIZONTAL_ALIGNMENT_LEFT, 150.0, 11, prompt_color)

	var feedback: Dictionary = data.get("switch_feedback", {})
	var state := String(feedback.get("state", "idle"))
	if state != "idle" and float(feedback.get("timer", 0.0)) > 0.0:
		var width := 54.0 * clampf(float(feedback.get("timer", 0.0)) / 0.85, 0.0, 1.0)
		draw_rect(Rect2(rect.position + Vector2(304.0, 10.0), Vector2(54.0, 5.0)), Color(0.02, 0.025, 0.024, 0.92))
		draw_rect(Rect2(rect.position + Vector2(304.0, 10.0), Vector2(width, 5.0)), Color(0.45, 0.78, 1.0, 0.9))

func _draw_stock_pips(start: Vector2, stocks: int, max_stocks: int, color: Color, pip_size: Vector2 = STOCK_PIP_SIZE, gap: float = 3.0) -> void:
	var count := clampi(max_stocks, 0, 6)
	var filled := clampi(stocks, 0, count)
	for i in count:
		var rect := Rect2(start + Vector2(float(i) * (pip_size.x + gap), 0.0), pip_size)
		draw_rect(rect, color if i < filled else Color(0.14, 0.15, 0.13, 0.9))
		draw_rect(rect, Color(0.02, 0.025, 0.024, 0.65), false, 1.0)

func _draw_pill(rect: Rect2, text: String, color: Color) -> void:
	draw_rect(rect, Color(0.02, 0.03, 0.035, 0.9))
	draw_rect(rect, color, false, 1.2)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7.0, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10.0, 10, color)

func _state_label(row: Dictionary) -> String:
	if bool(row.get("active", false)):
		return "ON"
	match String(row.get("state", "field")):
		"respawning":
			return "KO"
		"exhausted":
			return "OUT"
		_:
			return "OK"

func _state_color(row: Dictionary) -> Color:
	if bool(row.get("active", false)):
		return Color(0.68, 0.9, 1.0, 0.96)
	match String(row.get("state", "field")):
		"respawning":
			return Color(1.0, 0.76, 0.32, 0.96)
		"exhausted":
			return Color(1.0, 0.32, 0.25, 0.96)
		_:
			return Color(0.67, 1.0, 0.58, 0.9)

func _short_name(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return value.substr(0, maxi(max_chars - 1, 1)) + "."
