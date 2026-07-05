extends Control

# Hold P: full ability/passive reference for the currently controlled
# creature, read straight from the design-owned roster JSON (UI pass,
# 2026-07-05). Also carries the controls reference that used to crowd the
# top-left HUD stack.

const PANEL_WIDTH := 520.0
const LINE_HEIGHT := 18.0
const WRAP_CHARS := 66

var arena: Node = null
var was_visible := false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var show := Input.is_key_pressed(KEY_P)
	if show != was_visible:
		was_visible = show
		visible = show
		if show:
			queue_redraw()

# Assembled as data so checks can assert roster names appear.
func get_info_lines() -> Array[String]:
	var lines: Array[String] = []
	if arena == null or not is_instance_valid(arena):
		return lines
	var player: Node = arena.get("player")
	if player == null or not is_instance_valid(player):
		return lines
	var data: Dictionary = player.creature_data
	var stats: Dictionary = data.get("stats", {})
	lines.append("%s  —  %s / %s" % [String(data.get("name", "Unknown")), String(data.get("family", "?")), String(data.get("diet", "?"))])
	lines.append("")
	lines.append_array(_wrap("LMB — " + String(data.get("primary", "Primary attack")), ""))
	var primary_bits := "   %s dmg / %ss" % [str(stats.get("primary_damage", "?")), str(stats.get("attack_interval_sec", "?"))]
	if stats.has("windup_sec"):
		primary_bits += " (%ss windup)" % str(stats.get("windup_sec"))
	if stats.has("range"):
		primary_bits += "  range %s" % str(stats.get("range"))
	lines.append(primary_bits)
	for ability: Dictionary in data.get("abilities", []):
		var cd := float(ability.get("cooldown_sec", ability.get("cooldown_after_sec", 0.0)))
		var header := "%s — %s%s" % [String(ability.get("slot", "?")), String(ability.get("name", "?")), "  (%ss CD)" % str(cd) if cd > 0.0 else ""]
		lines.append("")
		lines.append(header)
		lines.append_array(_wrap(String(ability.get("summary", "")), "   "))
	for passive: Dictionary in data.get("passives", []):
		lines.append("")
		lines.append("Passive — %s" % String(passive.get("name", "?")))
		lines.append_array(_wrap(String(passive.get("summary", "")), "   "))
	lines.append("")
	lines.append("Controls: WASD move | mouse aim | LMB primary | Q/E abilities")
	lines.append("1/2/3 swap creature | T regroup | G farm/safe | Space flight")
	lines.append("F3 perf overlay | Esc menu")
	return lines

func _wrap(text: String, indent: String) -> Array[String]:
	var lines: Array[String] = []
	var current := indent
	for word in text.split(" ", false):
		if current.length() + word.length() + 1 > WRAP_CHARS and current != indent:
			lines.append(current)
			current = indent
		current += ("" if current == indent else " ") + word
	if current.strip_edges() != "":
		lines.append(current)
	return lines

func _draw() -> void:
	var lines := get_info_lines()
	if lines.is_empty():
		return
	var panel_height := LINE_HEIGHT * float(lines.size()) + 28.0
	var panel := Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, panel_height))
	draw_rect(panel, Color(0.04, 0.06, 0.05, 0.94))
	draw_rect(panel, Color(0.68, 0.75, 0.65, 0.55), false, 1.5)
	var font := ThemeDB.fallback_font
	for i in lines.size():
		var is_title := i == 0
		draw_string(
			font,
			Vector2(16.0, 22.0 + float(i) * LINE_HEIGHT),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			PANEL_WIDTH - 32.0,
			15 if is_title else 12,
			Color(0.95, 0.9, 0.6) if is_title else Color(0.88, 0.92, 0.85)
		)
