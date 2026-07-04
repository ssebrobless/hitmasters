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

	var origin: Vector2 = anim.get("origin", Vector2.ZERO)
	var shake_offset: Vector2 = origin + anim.get("shake_offset", Vector2.ZERO)
	if airborne:
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		canvas.draw_circle(Vector2(0.0, radius * 0.55), radius * 0.8, _with_alpha(Color(0.0, 0.0, 0.0, 0.3), alpha))
	canvas.draw_set_transform(shake_offset + body_offset + (Vector2(0.0, -radius * 0.5) if airborne else Vector2.ZERO), 0.0, Vector2.ONE)

	if creature_id == "snapping_turtle":
		_draw_turtle(canvas, radius, rocked_forward, side, outline, walk_phase, moving, windup_t)
		if strike_progress > 0.0:
			_draw_turtle_bite(canvas, radius, attack_aim.normalized(), attack_reach, strike_progress, outline, Color(0.45, 0.4, 0.24))
	elif creature_id == "mink":
		_draw_mink(canvas, radius, rocked_forward, side, outline, walk_phase, moving, strike_progress)
	elif creature_id == "chorus_frog":
		_draw_frog(canvas, radius, rocked_forward, side, outline, walk_phase, moving)
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

static func _draw_turtle(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, outline: Color, walk_phase: float, moving: bool, windup_t: float) -> void:
	var shell_color := Color(0.26, 0.3, 0.16)
	var shell_rim := Color(0.18, 0.21, 0.11)
	var skin := Color(0.45, 0.4, 0.24)
	var skin_dark := skin.darkened(0.22)

	# Team ring under everything.
	canvas.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 40, outline, 2.5)

	# Tail: saw-ridged, swishes slowly.
	var tail_sway := sin(walk_phase * 0.5) * 0.15
	var tail_direction := (-forward).rotated(tail_sway)
	var tail_base := tail_direction * radius * 0.9
	var tail_tip := tail_direction * radius * 1.55
	canvas.draw_line(tail_base, tail_tip, skin_dark, maxf(radius * 0.18, 3.0))
	for i in 3:
		var t := 0.25 + 0.25 * float(i)
		var ridge := tail_base.lerp(tail_tip, t)
		canvas.draw_line(ridge, ridge + tail_direction.rotated(PI * 0.5) * radius * 0.09, skin_dark.darkened(0.15), 2.0)

	# Four clawed legs at the shell corners, paddle-stepping.
	for leg_index in 4:
		var angle := [0.96, -0.96, 2.18, -2.18][leg_index] as float
		var leg_phase := walk_phase + (PI if leg_index % 2 == 0 else 0.0)
		var step := (sin(leg_phase) * radius * 0.12) if moving else 0.0
		var leg_center := (forward.rotated(angle) * radius * 0.92) + forward * step
		canvas.draw_circle(leg_center, radius * 0.26, skin_dark)
		canvas.draw_circle(leg_center, radius * 0.2, skin)
		var claw_direction := leg_center.normalized()
		for claw in 3:
			var claw_angle := (float(claw) - 1.0) * 0.35
			canvas.draw_line(leg_center + claw_direction.rotated(claw_angle) * radius * 0.18, leg_center + claw_direction.rotated(claw_angle) * radius * 0.34, Color(0.85, 0.82, 0.7), 1.5)

	# Head: hooked beak, retracts into the shell during windup.
	var head_reach := 1.05 - (0.35 * windup_t if windup_t >= 0.0 else 0.0)
	var head_center := forward * radius * head_reach
	canvas.draw_circle(head_center, radius * 0.32, skin_dark)
	canvas.draw_circle(head_center, radius * 0.26, skin)
	canvas.draw_line(head_center + forward * radius * 0.2, head_center + forward * radius * 0.4, skin_dark.darkened(0.2), 2.5)
	canvas.draw_circle(head_center + side * radius * 0.13 + forward * radius * 0.08, maxf(radius * 0.05, 1.2), Color(0.1, 0.09, 0.05))
	canvas.draw_circle(head_center - side * radius * 0.13 + forward * radius * 0.08, maxf(radius * 0.05, 1.2), Color(0.1, 0.09, 0.05))

	# Carapace: broad oval with rim, scute grid, and three keel ridges.
	var shell_points := PackedVector2Array()
	for i in 18:
		var shell_angle := TAU * float(i) / 18.0
		var rx := radius * 1.02
		var ry := radius * 0.88
		shell_points.append(forward * cos(shell_angle) * rx + side * sin(shell_angle) * ry)
	canvas.draw_colored_polygon(shell_points, shell_rim)
	var inner_points := PackedVector2Array()
	for i in 18:
		var shell_angle := TAU * float(i) / 18.0
		inner_points.append(forward * cos(shell_angle) * radius * 0.88 + side * sin(shell_angle) * radius * 0.74)
	canvas.draw_colored_polygon(inner_points, shell_color)
	for keel in [-0.34, 0.0, 0.34]:
		canvas.draw_line(forward * radius * -0.7 + side * radius * keel, forward * radius * 0.72 + side * radius * keel, shell_rim.darkened(0.1), 2.0)
	for cross in [-0.42, 0.0, 0.42]:
		canvas.draw_line(forward * radius * cross - side * radius * 0.55, forward * radius * cross + side * radius * 0.55, shell_rim.darkened(0.06), 1.5)
	canvas.draw_line(forward * radius * -0.7, forward * radius * 0.72, shell_color.lightened(0.18), 1.5)

static func _draw_mink(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, outline: Color, walk_phase: float, moving: bool, strike := 0.0) -> void:
	var fur := Color(0.24, 0.14, 0.09)
	var fur_dark := Color(0.17, 0.1, 0.06)
	var stretch := 1.0 + strike * 0.5

	canvas.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 40, outline, 2.5)

	# Sinuous spine: 5 segments from tail to head, undulating laterally while moving.
	var spine: Array[Vector2] = []
	var segment_radii: Array[float] = []
	for i in 5:
		var t := float(i) / 4.0
		var along := lerpf(-1.35, 1.15, t) * radius * stretch
		var wiggle := 0.0
		if moving and strike <= 0.0:
			wiggle = sin(walk_phase * 1.4 - t * 2.6) * radius * 0.16 * (1.0 - t * 0.4)
		spine.append(forward * along + side * wiggle)
		segment_radii.append(radius * lerpf(0.4, 0.52, sin(t * PI)))

	# Bushy tail off the rear segment.
	var tail_wiggle := sin(walk_phase * 1.4 + 1.8) * 0.3 if moving else 0.12
	var tail_direction := (-forward).rotated(tail_wiggle)
	var tail_base: Vector2 = spine[0]
	for i in 4:
		var t := float(i) / 3.0
		canvas.draw_circle(tail_base + tail_direction * radius * (0.35 + t * 1.0), radius * lerpf(0.3, 0.12, t), fur_dark)

	# Paw nubs alternating with the stride.
	if moving and strike <= 0.0:
		for paw_index in 4:
			var paw_t := [0.22, 0.36, 0.72, 0.86][paw_index] as float
			var paw_side := 1.0 if paw_index % 2 == 0 else -1.0
			var paw_phase := walk_phase * 1.4 + PI * float(paw_index)
			var paw_step := sin(paw_phase) * radius * 0.14
			var spine_point: Vector2 = spine[1].lerp(spine[3], paw_t)
			canvas.draw_circle(spine_point + side * paw_side * radius * 0.5 + forward * paw_step, radius * 0.13, fur_dark)

	# Body segments, tail-to-head so the head overlaps.
	for i in 5:
		canvas.draw_circle(spine[i], segment_radii[i] + 2.0, fur_dark)
	for i in 5:
		canvas.draw_circle(spine[i], segment_radii[i], fur)
	canvas.draw_line(spine[0], spine[4], fur.lightened(0.12), maxf(radius * 0.14, 2.0))

	# Head: small, round ears, pale snout, white chin patch, whiskers.
	var head: Vector2 = spine[4]
	canvas.draw_circle(head + side * radius * 0.28 - forward * radius * 0.1, radius * 0.14, fur_dark)
	canvas.draw_circle(head - side * radius * 0.28 - forward * radius * 0.1, radius * 0.14, fur_dark)
	canvas.draw_circle(head, radius * 0.4, fur)
	canvas.draw_circle(head + forward * radius * 0.28, radius * 0.18, fur.lightened(0.18))
	canvas.draw_circle(head + forward * radius * 0.34, maxf(radius * 0.07, 1.2), Color(0.1, 0.07, 0.05))
	canvas.draw_circle(head + forward * radius * 0.16, maxf(radius * 0.09, 1.4), Color(0.93, 0.9, 0.82))
	canvas.draw_circle(head + side * radius * 0.16 + forward * radius * 0.16, maxf(radius * 0.05, 1.0), Color(0.08, 0.05, 0.04))
	canvas.draw_circle(head - side * radius * 0.16 + forward * radius * 0.16, maxf(radius * 0.05, 1.0), Color(0.08, 0.05, 0.04))
	canvas.draw_line(head + forward * radius * 0.24, head + forward * radius * 0.44 + side * radius * 0.22, Color(0.8, 0.78, 0.7, 0.7), 1.0)
	canvas.draw_line(head + forward * radius * 0.24, head + forward * radius * 0.44 - side * radius * 0.22, Color(0.8, 0.78, 0.7, 0.7), 1.0)

	if strike > 0.25:
		var fang_origin := head + forward * radius * 0.4
		canvas.draw_line(fang_origin + side * 2.0, fang_origin + forward * radius * 0.4 + side * 2.0, Color(0.98, 0.98, 0.92, strike), 2.0)
		canvas.draw_line(fang_origin - side * 2.0, fang_origin + forward * radius * 0.4 - side * 2.0, Color(0.98, 0.98, 0.92, strike), 2.0)

static func _draw_frog(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, outline: Color, walk_phase: float, moving: bool) -> void:
	var skin := Color(0.36, 0.42, 0.2)
	var skin_dark := Color(0.22, 0.27, 0.12)
	var belly := skin.lightened(0.2)

	canvas.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 40, outline, 2.5)

	# Hop cycle: legs extend at the push phase, body squashes/stretches slightly.
	var hop := sin(walk_phase * 1.2) * 0.5 + 0.5 if moving else 0.0
	var leg_extend := 0.55 + hop * 0.55

	# Folded Z hind legs hugging the rear flanks.
	for leg_side: float in [-1.0, 1.0]:
		var hip := -forward * radius * 0.45 + side * leg_side * radius * 0.62
		var knee := hip - forward * radius * 0.35 * leg_extend + side * leg_side * radius * 0.4
		var foot := knee - forward * radius * 0.55 * leg_extend - side * leg_side * radius * 0.08
		canvas.draw_line(hip, knee, skin_dark, maxf(radius * 0.24, 3.0))
		canvas.draw_line(knee, foot, skin_dark, maxf(radius * 0.18, 2.5))
		for toe in 3:
			var toe_angle := (float(toe) - 1.0) * 0.4
			canvas.draw_line(foot, foot + (-forward).rotated(toe_angle) * radius * 0.22, skin_dark, 1.5)

	# Front feet: small dots ahead of the chest.
	for foot_side: float in [-1.0, 1.0]:
		var front_step := sin(walk_phase * 1.2 + PI * 0.5) * radius * 0.08 if moving else 0.0
		canvas.draw_circle(forward * (radius * 0.55 + front_step) + side * foot_side * radius * 0.4, radius * 0.13, skin_dark)

	# Pear body: wide rear, narrow front.
	var body_points := PackedVector2Array()
	for i in 16:
		var body_angle := TAU * float(i) / 16.0
		var rx := radius * 0.95
		var ry := radius * lerpf(0.85, 0.6, (cos(body_angle) * 0.5 + 0.5))
		body_points.append(forward * cos(body_angle) * rx + side * sin(body_angle) * ry)
	canvas.draw_colored_polygon(body_points, skin_dark)
	var inner := PackedVector2Array()
	for point in body_points:
		inner.append(point * 0.88)
	canvas.draw_colored_polygon(inner, skin)

	# Chorus frog signature: dark triangle between the eyes + three dorsal stripes.
	canvas.draw_colored_polygon(PackedVector2Array([
		forward * radius * 0.62 + side * radius * 0.22,
		forward * radius * 0.62 - side * radius * 0.22,
		forward * radius * 0.3
	]), skin_dark.darkened(0.15))
	for stripe in [-0.3, 0.0, 0.3]:
		canvas.draw_line(forward * radius * 0.15 + side * radius * stripe, -forward * radius * 0.72 + side * radius * stripe * 1.4, skin_dark.darkened(0.12), maxf(radius * 0.09, 1.5))

	# Bulging eyes with pupils.
	for eye_side: float in [-1.0, 1.0]:
		var eye := forward * radius * 0.68 + side * eye_side * radius * 0.42
		canvas.draw_circle(eye, radius * 0.22, skin_dark)
		canvas.draw_circle(eye, radius * 0.17, Color(0.82, 0.72, 0.35))
		canvas.draw_circle(eye + forward * radius * 0.05, maxf(radius * 0.08, 1.3), Color(0.08, 0.07, 0.04))

	# Pulsing vocal sac under the chin — it's a chorus frog.
	var sac_pulse := (sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5) * 0.35
	canvas.draw_circle(forward * radius * 0.88, radius * (0.14 + sac_pulse * 0.14), belly)

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
