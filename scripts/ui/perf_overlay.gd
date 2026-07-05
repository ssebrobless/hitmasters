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
