extends RefCounted

static func team_color(team: int) -> Color:
	return Color(0.25, 0.65, 1.0) if team == 0 else Color(1.0, 0.28, 0.25)

static func creature_color(creature_id: String) -> Color:
	var creature_hash: int = abs(hash(creature_id))
	var hue := float(creature_hash % 360) / 360.0
	return Color.from_hsv(hue, 0.58, 0.92)

static func draw_pixel_hero(canvas: CanvasItem, creature_id: String, team: int, pixel_size := 5.0, alpha := 1.0) -> void:
	draw_pixel_creature(canvas, creature_id, team, pixel_size, alpha)

static func draw_pixel_creature(canvas: CanvasItem, creature_id: String, team: int, pixel_size := 5.0, alpha := 1.0) -> void:
	var team_col := _with_alpha(team_color(team), alpha)
	var main_col := _with_alpha(creature_color(creature_id), alpha)
	var dark_col := _with_alpha(Color(0.03, 0.035, 0.045), alpha)
	var bright_col := _with_alpha(main_col.lightened(0.28), alpha)
	_draw_cells(canvas, _outline_cells(creature_id), pixel_size, dark_col)
	_draw_cells(canvas, _body_cells(creature_id), pixel_size, main_col)
	_draw_cells(canvas, _highlight_cells(creature_id), pixel_size, bright_col)
	_draw_cells(canvas, [Vector2i(2, 3), Vector2i(5, 3)], pixel_size, team_col)

static func draw_battle_creature(canvas: CanvasItem, creature_id: String, team: int, radius: float, facing: Vector2, flash_alpha := 0.0, alpha := 1.0, airborne := false, anim: Dictionary = {}) -> void:
	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var outline := _with_alpha(team_color(team), alpha)
	var body := _with_alpha(creature_color(creature_id).lightened(0.18) if airborne else creature_color(creature_id), alpha)
	var shadow := _with_alpha(Color(0.02, 0.025, 0.03), alpha)

	var attack_t := float(anim.get("attack_t", -1.0))
	var windup_t := float(anim.get("windup_t", -1.0))
	var walk_phase := float(anim.get("walk_phase", 0.0))
	var moving := bool(anim.get("moving", false))
	var attack_aim: Vector2 = anim.get("attack_aim", forward)
	if attack_aim == Vector2.ZERO:
		attack_aim = forward
	var attack_reach := float(anim.get("attack_reach", radius * 1.6))

	# Body offset: lunge forward on attack (fast out, ease back), pull back during windup.
	var body_offset := Vector2.ZERO
	var strike_progress := 0.0
	if attack_t >= 0.0:
		strike_progress = _strike_curve(attack_t)
		body_offset = attack_aim.normalized() * radius * 0.55 * strike_progress
	elif windup_t >= 0.0:
		body_offset = -forward * radius * 0.3 * windup_t

	# Walk bob: gentle rock around facing while moving.
	var rock := 0.0
	if moving and attack_t < 0.0:
		rock = sin(walk_phase) * 0.12
	var rocked_forward := forward.rotated(rock)
	var side := Vector2(-rocked_forward.y, rocked_forward.x)

	var shake_offset: Vector2 = anim.get("shake_offset", Vector2.ZERO)
	if airborne:
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		canvas.draw_circle(Vector2(0.0, radius * 0.55), radius * 0.8, _with_alpha(Color(0.0, 0.0, 0.0, 0.3), alpha))
	canvas.draw_set_transform(shake_offset + body_offset + (Vector2(0.0, -radius * 0.5) if airborne else Vector2.ZERO), 0.0, Vector2.ONE)

	if creature_id == "snapping_turtle":
		_draw_turtle(canvas, radius, rocked_forward, side, shadow, outline, body)
		if strike_progress > 0.0:
			_draw_turtle_bite(canvas, radius, attack_aim.normalized(), attack_reach, strike_progress, outline, body)
	elif creature_id == "mink":
		_draw_mink(canvas, radius, rocked_forward, side, shadow, outline, body, strike_progress)
	elif creature_id == "chorus_frog":
		_draw_frog(canvas, radius, rocked_forward, side, shadow, outline, body)
		if strike_progress > 0.0:
			_draw_frog_tongue(canvas, radius, attack_aim.normalized(), attack_reach, strike_progress)
	else:
		canvas.draw_circle(Vector2.ZERO, radius + 4.0, shadow)
		canvas.draw_circle(Vector2.ZERO, radius + 2.0, outline)
		canvas.draw_circle(Vector2.ZERO, radius, body)
	if flash_alpha > 0.0:
		var flash := Color(1.0, 1.0, 1.0, clampf(flash_alpha, 0.0, 1.0) * 0.85)
		canvas.draw_circle(Vector2.ZERO, radius + 3.0, flash)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# 0 at start/end, peaks ~1 early: snap out, ease back.
static func _strike_curve(t: float) -> float:
	if t < 0.3:
		return t / 0.3
	return 1.0 - (t - 0.3) / 0.7

static func _draw_turtle_bite(canvas: CanvasItem, radius: float, aim: Vector2, reach: float, progress: float, outline: Color, body: Color) -> void:
	var side := Vector2(-aim.y, aim.x)
	var neck_length := (radius * 0.4) + (reach - radius * 0.4) * progress
	var neck_width := maxf(radius * 0.3, 4.0)
	var neck := PackedVector2Array([
		aim * radius * 0.5 + side * neck_width * 0.6,
		aim * neck_length + side * neck_width * 0.42,
		aim * neck_length - side * neck_width * 0.42,
		aim * radius * 0.5 - side * neck_width * 0.6
	])
	canvas.draw_colored_polygon(neck, body.darkened(0.12))
	var head_center := aim * neck_length
	canvas.draw_circle(head_center, neck_width * 0.95, outline)
	canvas.draw_circle(head_center, neck_width * 0.75, body.darkened(0.05))
	var jaw_open := (1.0 - progress) * 0.7 + 0.15
	canvas.draw_line(head_center, head_center + aim.rotated(jaw_open) * neck_width * 1.2, Color(0.95, 0.95, 0.9), 2.5)
	canvas.draw_line(head_center, head_center + aim.rotated(-jaw_open) * neck_width * 1.2, Color(0.95, 0.95, 0.9), 2.5)

static func _draw_frog_tongue(canvas: CanvasItem, radius: float, aim: Vector2, reach: float, progress: float) -> void:
	var tongue_tip := aim * (radius * 0.5 + (reach - radius * 0.5) * progress)
	var tongue_color := Color(0.95, 0.45, 0.55)
	canvas.draw_line(aim * radius * 0.5, tongue_tip, tongue_color, maxf(radius * 0.22, 3.0))
	canvas.draw_circle(tongue_tip, maxf(radius * 0.2, 3.0), tongue_color.lightened(0.15))

static func draw_aim_indicator(canvas: CanvasItem, radius: float, facing: Vector2) -> void:
	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var start := forward * (radius + 5.0)
	var end := forward * (radius + 26.0)
	canvas.draw_line(start, end, Color(1.0, 0.95, 0.55, 0.9), 3.0)
	canvas.draw_line(end, end - forward * 6.0 + Vector2(-forward.y, forward.x) * 4.0, Color(1.0, 0.95, 0.55, 0.9), 2.0)
	canvas.draw_line(end, end - forward * 6.0 - Vector2(-forward.y, forward.x) * 4.0, Color(1.0, 0.95, 0.55, 0.9), 2.0)

static func draw_pixel_minion(canvas: CanvasItem, team: int, pixel_size := 4.0, alpha := 1.0) -> void:
	var team_col := _with_alpha(team_color(team), alpha)
	var dark_col := _with_alpha(team_col.darkened(0.2), alpha)
	var body_cells := [
		Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(2, 4), Vector2i(3, 4)
	]
	var outline_cells := [
		Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(0, 2), Vector2i(5, 2),
		Vector2i(0, 3), Vector2i(5, 3),
		Vector2i(1, 5), Vector2i(4, 5)
	]
	_draw_cells(canvas, outline_cells, pixel_size, dark_col, Vector2(3.0, 3.0))
	_draw_cells(canvas, body_cells, pixel_size, team_col, Vector2(3.0, 3.0))
	_draw_cells(canvas, [Vector2i(4, 1), Vector2i(5, 1)], pixel_size, _with_alpha(Color(0.85, 0.9, 0.95), alpha), Vector2(3.0, 3.0))

static func _draw_turtle(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, shadow: Color, outline: Color, body: Color) -> void:
	var shell := [
		Vector2(-1.12, 0.0), Vector2(-0.86, -0.5), Vector2(-0.26, -0.73), Vector2(0.48, -0.64),
		Vector2(0.86, -0.34), Vector2(1.18, -0.22), Vector2(1.32, 0.0), Vector2(1.18, 0.22),
		Vector2(0.86, 0.34), Vector2(0.48, 0.64), Vector2(-0.26, 0.73), Vector2(-0.86, 0.5)
	]
	_draw_shape(canvas, shell, radius + 4.0, forward, side, shadow)
	_draw_shape(canvas, shell, radius + 2.0, forward, side, outline)
	_draw_shape(canvas, shell, radius, forward, side, body)
	canvas.draw_line(_orient(Vector2(-0.55, -0.38), radius, forward, side), _orient(Vector2(0.62, -0.26), radius, forward, side), body.lightened(0.28), 2.0)
	canvas.draw_line(_orient(Vector2(-0.62, 0.32), radius, forward, side), _orient(Vector2(0.48, 0.25), radius, forward, side), body.darkened(0.18), 2.0)

static func _draw_mink(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, shadow: Color, outline: Color, body: Color, strike := 0.0) -> void:
	var stretch := 1.0 + strike * 0.45
	var squeeze := 1.0 - strike * 0.25
	var body_shape := [
		Vector2(-1.48 * stretch, -0.18 * squeeze), Vector2(-1.12 * stretch, -0.42 * squeeze), Vector2(0.58 * stretch, -0.46 * squeeze), Vector2(1.22 * stretch, -0.28 * squeeze),
		Vector2(1.48 * stretch, -0.08 * squeeze), Vector2(1.28 * stretch, 0.24 * squeeze), Vector2(0.32 * stretch, 0.42 * squeeze), Vector2(-1.28 * stretch, 0.34 * squeeze),
		Vector2(-1.72 * stretch, 0.08 * squeeze)
	]
	_draw_shape(canvas, body_shape, radius + 4.0, forward, side, shadow)
	_draw_shape(canvas, body_shape, radius + 2.0, forward, side, outline)
	_draw_shape(canvas, body_shape, radius, forward, side, body)
	canvas.draw_line(_orient(Vector2(-1.32 * stretch, 0.12), radius, forward, side), _orient(Vector2(-1.88 * stretch, 0.44), radius, forward, side), outline, 3.0)
	canvas.draw_circle(_orient(Vector2(1.02 * stretch, -0.1), radius, forward, side), maxf(radius * 0.12, 1.5), Color(0.95, 0.96, 0.85))
	if strike > 0.25:
		var fang_origin := _orient(Vector2(1.5 * stretch, 0.0), radius, forward, side)
		canvas.draw_line(fang_origin, fang_origin + forward * radius * 0.5, Color(0.98, 0.98, 0.92, strike), 2.5)

static func _draw_frog(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, shadow: Color, outline: Color, body: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, radius + 4.0, shadow)
	canvas.draw_circle(Vector2.ZERO, radius + 2.0, outline)
	canvas.draw_circle(Vector2.ZERO, radius, body)
	canvas.draw_circle(_orient(Vector2(0.58, 0.0), radius, forward, side), radius * 0.42, body.lightened(0.22))
	canvas.draw_circle(_orient(Vector2(0.38, -0.45), radius, forward, side), maxf(radius * 0.18, 1.5), Color(0.95, 0.96, 0.85))
	canvas.draw_circle(_orient(Vector2(0.38, 0.45), radius, forward, side), maxf(radius * 0.18, 1.5), Color(0.95, 0.96, 0.85))

static func _draw_shape(canvas: CanvasItem, local_points: Array, radius: float, forward: Vector2, side: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for point: Vector2 in local_points:
		points.append(_orient(point, radius, forward, side))
	canvas.draw_colored_polygon(points, color)

static func _orient(point: Vector2, radius: float, forward: Vector2, side: Vector2) -> Vector2:
	return forward * point.x * radius + side * point.y * radius

static func draw_pixel_core(canvas: CanvasItem, team: int, pixel_size := 8.0, alpha := 1.0) -> void:
	var team_col := _with_alpha(team_color(team), alpha)
	var dark_col := _with_alpha(Color(0.04, 0.045, 0.055), alpha)
	var core_col := _with_alpha(team_col.darkened(0.12), alpha)
	var glow_col := _with_alpha(team_col.lightened(0.3), alpha)
	for y in range(12):
		for x in range(12):
			if x == 0 or x == 11 or y == 0 or y == 11:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, dark_col, Vector2(6.0, 6.0))
			elif x in [2, 3, 8, 9] or y in [2, 3, 8, 9]:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, core_col, Vector2(6.0, 6.0))
			elif x >= 4 and x <= 7 and y >= 4 and y <= 7:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, glow_col, Vector2(6.0, 6.0))

static func draw_pixel_projectile(canvas: CanvasItem, color: Color, radius: float) -> void:
	var dark_col := Color(0.04, 0.04, 0.045, color.a)
	var size := maxf(radius * 1.3, 7.0)
	canvas.draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)), dark_col)
	canvas.draw_rect(Rect2(Vector2(-size * 0.5 + 2.0, -size * 0.5 + 2.0), Vector2(size - 4.0, size - 4.0)), color)
	canvas.draw_rect(Rect2(Vector2(0.0, -size * 0.5 + 2.0), Vector2(size * 0.8, size - 4.0)), color.lightened(0.25))

static func _outline_cells(creature_id: String) -> Array:
	if creature_id.contains("frog") or creature_id.contains("turtle"):
		return _rect_cells(1, 1, 6, 5) + [Vector2i(0, 3), Vector2i(7, 3)]
	if creature_id.contains("mink"):
		return _rect_cells(1, 2, 7, 3) + [Vector2i(0, 3), Vector2i(8, 3), Vector2i(2, 1)]
	return _rect_cells(1, 1, 6, 6)

static func _body_cells(creature_id: String) -> Array:
	if creature_id.contains("mink"):
		return _rect_cells(2, 2, 5, 3) + [Vector2i(7, 3)]
	return _rect_cells(2, 2, 4, 3) + [Vector2i(1, 3), Vector2i(6, 3)]

static func _highlight_cells(creature_id: String) -> Array:
	if creature_id.contains("turtle"):
		return [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]
	if creature_id.contains("frog"):
		return [Vector2i(5, 1), Vector2i(6, 1), Vector2i(6, 2)]
	return [Vector2i(6, 2), Vector2i(7, 3)]

static func _rect_cells(x: int, y: int, width: int, height: int) -> Array:
	var cells: Array = []
	for cy in range(y, y + height):
		for cx in range(x, x + width):
			cells.append(Vector2i(cx, cy))
	return cells

static func _draw_cells(canvas: CanvasItem, cells: Array, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	for cell in cells:
		_draw_cell(canvas, cell, pixel_size, color, origin)

static func _draw_cell(canvas: CanvasItem, cell: Vector2i, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	var position := Vector2((float(cell.x) - origin.x) * pixel_size, (float(cell.y) - origin.y) * pixel_size)
	canvas.draw_rect(Rect2(position, Vector2(pixel_size, pixel_size)), color)

static func _with_alpha(color: Color, alpha: float) -> Color:
	var output := color
	output.a *= alpha
	return output
