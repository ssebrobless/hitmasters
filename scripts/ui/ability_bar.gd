extends Control

# Per-creature ability bar (UI pass, 2026-07-05): primary/Q/E boxes carrying
# the roster-designated ability names, cooldown fills, and charge pips.
# Replaces the old cooldown text line.

const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

const BOX_SIZE := Vector2(126.0, 46.0)
const BOX_GAP := 8.0
const UPDATE_INTERVAL := 0.1

var arena: Node = null
var accumulator := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	accumulator += delta
	if accumulator >= UPDATE_INTERVAL:
		accumulator = 0.0
		queue_redraw()

# Data assembly kept separate from drawing so checks can assert it.
func get_ability_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if arena == null or not is_instance_valid(arena):
		return slots
	var player: Node = arena.get("player")
	if player == null or not is_instance_valid(player):
		return slots
	var stats: Dictionary = player.get("stats") if player.get("stats") != null else {}
	slots.append({
		"key": "LMB",
		"name": "Primary",
		"remaining": float(player.primary_timer),
		"max": maxf(float(stats.get("attack_interval_sec", 1.0)) if typeof(stats.get("attack_interval_sec")) != TYPE_STRING else 1.0, 0.01),
		"charges": -1
	})
	var abilities: Array = player.creature_data.get("abilities", [])
	for ability: Dictionary in abilities:
		var slot_key := String(ability.get("slot", ""))
		if slot_key != "Q" and slot_key != "E":
			continue
		var remaining: float = float(player.q_timer) if slot_key == "Q" else float(player.e_timer)
		var charges: int = int(player.q_charges) if slot_key == "Q" else int(player.e_charges)
		var max_cd := float(ability.get("cooldown_sec", ability.get("cooldown_after_sec", 0.0)))
		slots.append({
			"key": slot_key,
			"name": String(ability.get("name", slot_key)),
			"remaining": remaining,
			"max": maxf(max_cd, 0.01),
			"charges": charges
		})
	return slots

func _draw() -> void:
	var player: Node = arena.get("player") if arena != null and is_instance_valid(arena) else null
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_alive") and not player.is_alive():
		var respawn_text := "RESPAWNING %.1fs" % maxf(float(player.respawn_timer), 0.0)
		draw_string(ThemeDB.fallback_font, Vector2(0.0, 24.0), respawn_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(1.0, 0.5, 0.4))
		return
	var slots := get_ability_slots()
	var total_width := float(slots.size()) * BOX_SIZE.x + float(slots.size() - 1) * BOX_GAP
	var origin_x := (size.x - total_width) * 0.5
	for i in slots.size():
		_draw_slot(Vector2(origin_x + float(i) * (BOX_SIZE.x + BOX_GAP), 0.0), slots[i], player)

func _draw_slot(at: Vector2, slot: Dictionary, player: Node) -> void:
	var rect := Rect2(at, BOX_SIZE)
	var remaining := float(slot.remaining)
	var max_cd := float(slot.max)
	var ready := remaining <= 0.0
	var team_col: Color = VisualGrammar.team_color(int(player.team))

	draw_rect(rect, Color(0.05, 0.07, 0.06, 0.88))
	if not ready:
		# Cooldown fill rises from the bottom as the ability comes back.
		var progress := 1.0 - clampf(remaining / max_cd, 0.0, 1.0)
		var fill_height := rect.size.y * progress
		draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - fill_height), Vector2(rect.size.x, fill_height)), Color(0.16, 0.2, 0.18, 0.9))
	draw_rect(rect, team_col if ready else Color(0.4, 0.42, 0.4, 0.6), false, 2.0)

	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(6.0, 15.0), String(slot.key), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.75, 0.8, 0.72))
	var name_color := Color(0.95, 0.97, 0.9) if ready else Color(0.6, 0.63, 0.58)
	draw_string(font, rect.position + Vector2(6.0, 32.0), String(slot.name), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, 13, name_color)
	if not ready:
		draw_string(font, rect.position + Vector2(rect.size.x - 38.0, 15.0), "%.1f" % remaining, HORIZONTAL_ALIGNMENT_RIGHT, 34.0, 11, Color(1.0, 0.85, 0.4))
	var charges := int(slot.charges)
	if charges > 0:
		for c in charges:
			draw_circle(rect.position + Vector2(rect.size.x - 10.0 - float(c) * 9.0, rect.size.y - 8.0), 3.0, team_col)
