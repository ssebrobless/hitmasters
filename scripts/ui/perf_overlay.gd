extends Label

# F3 toggles a small perf readout during playtests: FPS, frame ms, entity
# count, canvas draw calls. UI layer — allowed to read Input directly.

const UPDATE_INTERVAL := 0.25

var arena: Node = null
var accumulator := 0.0

func _ready() -> void:
	visible = false
	add_theme_color_override("font_color", Color(0.95, 0.95, 0.6))
	add_theme_font_size_override("font_size", 14)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3:
		visible = not visible

func _process(delta: float) -> void:
	if not visible:
		return
	accumulator += delta
	if accumulator < UPDATE_INTERVAL:
		return
	accumulator = 0.0
	var fps := Engine.get_frames_per_second()
	var entity_count := -1
	if arena != null and is_instance_valid(arena) and arena.get("entities") != null:
		entity_count = (arena.entities as Array).size()
	text = "FPS %d  (%.1f ms)  entities %d  draw calls %d  vram %.0f MB" % [
		fps,
		1000.0 / maxf(float(fps), 1.0),
		entity_count,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	]
	if arena != null and is_instance_valid(arena) and arena.has_method("get_information_debug_state"):
		text += "\n%s" % _format_info_debug(arena.get_information_debug_state())

func _format_info_debug(state: Dictionary) -> String:
	var enemies: Dictionary = state.get("enemy_info", {})
	var food: Dictionary = state.get("food_info", {})
	return "Info %s V%d R%d H%d L%d S%d X%d  Food V%d L%d X%d  Obj %d/%d" % [
		String(state.get("phase", "?")).substr(0, 1).to_upper(),
		int(enemies.get("visible", 0)),
		int(enemies.get("revealed", 0)),
		int(enemies.get("heard", 0)),
		int(enemies.get("last_known", 0)),
		int(enemies.get("suspected", 0)),
		int(enemies.get("hidden", 0)),
		int(food.get("visible", 0)),
		int(food.get("last_known", 0)),
		int(food.get("hidden", 0)),
		int(state.get("live_objective_count", 0)),
		int(state.get("objective_event_count", 0))
	]
