extends RefCounted

# Creature rendering: shared body-base archetypes reskinned per creature.
# Every dimension derives from the roster footprint radius so the visual
# silhouette stays honest to the hitbox.

static func team_color(team: int) -> Color:
	return Color(0.25, 0.65, 1.0) if team == 0 else Color(1.0, 0.28, 0.25)

# base: which body archetype draws this creature.
# main/dark/accent/belly: real-life palette. Extra keys tune the base.
const SKINS := {
	"bullfrog": {"base": "frog", "main": Color(0.3, 0.45, 0.18), "dark": Color(0.18, 0.28, 0.1), "belly": Color(0.62, 0.66, 0.42), "eye": Color(0.75, 0.6, 0.25), "strike": "tongue", "tympanum": true},
	"chorus_frog": {"base": "frog", "main": Color(0.36, 0.42, 0.2), "dark": Color(0.2, 0.25, 0.11), "belly": Color(0.6, 0.62, 0.44), "eye": Color(0.82, 0.72, 0.35), "strike": "tongue", "stripes": true, "call_sac": true},
	"cane_toad": {"base": "frog", "main": Color(0.46, 0.36, 0.2), "dark": Color(0.28, 0.21, 0.11), "belly": Color(0.66, 0.58, 0.42), "eye": Color(0.7, 0.55, 0.2), "strike": "tongue", "warts": true},
	"newt": {"base": "mustelid", "main": Color(0.3, 0.2, 0.13), "dark": Color(0.19, 0.12, 0.08), "accent": Color(0.92, 0.5, 0.14), "tail": "fin", "smooth": true, "spots": true},
	"snapping_turtle": {"base": "turtle", "shell": Color(0.26, 0.3, 0.16), "rim": Color(0.18, 0.21, 0.11), "skin": Color(0.45, 0.4, 0.24), "keels": true, "lunge_scale": 0.2},
	"water_snake": {"base": "serpent", "main": Color(0.36, 0.26, 0.15), "dark": Color(0.2, 0.14, 0.09), "belly": Color(0.6, 0.5, 0.34)},
	"bog_turtle": {"base": "turtle", "shell": Color(0.26, 0.2, 0.12), "rim": Color(0.16, 0.12, 0.07), "skin": Color(0.34, 0.28, 0.18), "neck_patch": Color(0.95, 0.55, 0.12), "lunge_scale": 0.2},
	"alligator": {"base": "croc", "main": Color(0.2, 0.26, 0.17), "dark": Color(0.12, 0.16, 0.1), "belly": Color(0.5, 0.52, 0.4)},
	"owl": {"base": "bird", "main": Color(0.42, 0.32, 0.22), "dark": Color(0.26, 0.19, 0.13), "breast": Color(0.62, 0.54, 0.42), "beak": Color(0.75, 0.65, 0.4), "beak_len": 0.25, "tufts": true, "facial_disc": true},
	"great_blue_heron": {"base": "bird", "main": Color(0.44, 0.5, 0.56), "dark": Color(0.26, 0.31, 0.36), "breast": Color(0.68, 0.7, 0.72), "beak": Color(0.85, 0.7, 0.3), "beak_len": 0.95, "neck": 0.7},
	"kingfisher": {"base": "bird", "main": Color(0.14, 0.44, 0.68), "dark": Color(0.08, 0.26, 0.42), "breast": Color(0.85, 0.5, 0.2), "beak": Color(0.15, 0.13, 0.12), "beak_len": 0.7},
	"duck": {"base": "bird", "main": Color(0.4, 0.32, 0.24), "dark": Color(0.24, 0.19, 0.14), "breast": Color(0.55, 0.45, 0.36), "beak": Color(0.85, 0.72, 0.2), "beak_len": 0.45, "flat_bill": true, "head_color": Color(0.1, 0.38, 0.2)},
	"water_shrew": {"base": "mustelid", "main": Color(0.16, 0.16, 0.18), "dark": Color(0.1, 0.1, 0.12), "belly": Color(0.55, 0.55, 0.5), "snout": 1.4, "bulk": 0.9},
	"beaver": {"base": "mustelid", "main": Color(0.36, 0.23, 0.12), "dark": Color(0.22, 0.14, 0.07), "tail": "paddle", "bulk": 1.25},
	"otter": {"base": "mustelid", "main": Color(0.4, 0.28, 0.16), "dark": Color(0.26, 0.18, 0.1), "belly": Color(0.6, 0.5, 0.36), "tail": "thick", "bulk": 1.05},
	"mink": {"base": "mustelid", "main": Color(0.24, 0.14, 0.09), "dark": Color(0.17, 0.1, 0.06), "belly": Color(0.93, 0.9, 0.82), "tail": "bushy"},
	"leech": {"base": "cluster", "main": Color(0.27, 0.11, 0.08), "dark": Color(0.16, 0.06, 0.05)},
	"crayfish": {"base": "crustacean", "main": Color(0.5, 0.2, 0.1), "dark": Color(0.32, 0.12, 0.06)},
	"mosquito_swarm": {"base": "swarm", "main": Color(0.4, 0.4, 0.42), "dark": Color(0.2, 0.2, 0.22)},
	"wolf_spider": {"base": "spider", "main": Color(0.3, 0.22, 0.12), "dark": Color(0.18, 0.13, 0.07), "accent": Color(0.55, 0.45, 0.3)},
	"firefly": {"base": "bug", "main": Color(0.22, 0.16, 0.1), "dark": Color(0.12, 0.09, 0.06), "glow": Color(0.95, 0.9, 0.4)}
}

static func creature_color(creature_id: String) -> Color:
	var skin: Dictionary = SKINS.get(creature_id, {})
	if skin.has("main"):
		return skin["main"]
	if skin.has("shell"):
		return skin["shell"]
	var creature_hash: int = abs(hash(creature_id))
	return Color.from_hsv(float(creature_hash % 360) / 360.0, 0.58, 0.92)

static func draw_battle_creature(canvas: CanvasItem, creature_id: String, team: int, radius: float, facing: Vector2, flash_alpha := 0.0, alpha := 1.0, airborne := false, anim: Dictionary = {}) -> void:
	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var outline := _with_alpha(team_color(team), alpha)
	var skin: Dictionary = SKINS.get(creature_id, {})

	var attack_t := float(anim.get("attack_t", -1.0))
	var windup_t := float(anim.get("windup_t", -1.0))
	var walk_phase := float(anim.get("walk_phase", 0.0))
	var moving := bool(anim.get("moving", false))
	var attack_aim: Vector2 = anim.get("attack_aim", forward)
	if attack_aim == Vector2.ZERO:
		attack_aim = forward
	var attack_reach := float(anim.get("attack_reach", radius * 1.6))

	var body_offset := Vector2.ZERO
	var strike := 0.0
	var lunge_scale := float(skin.get("lunge_scale", 1.0))
	if attack_t >= 0.0:
		strike = _strike_curve(attack_t)
		body_offset = attack_aim.normalized() * maxf(radius * 0.8, 8.0) * strike * lunge_scale
	elif windup_t >= 0.0:
		body_offset = -forward * maxf(radius * 0.4, 6.0) * windup_t * lunge_scale

	var rock := 0.0
	if moving and attack_t < 0.0:
		rock = sin(walk_phase) * 0.1
	var rocked_forward := forward.rotated(rock)
	var side := Vector2(-rocked_forward.y, rocked_forward.x)

	var origin: Vector2 = anim.get("origin", Vector2.ZERO)
	var shake_offset: Vector2 = origin + anim.get("shake_offset", Vector2.ZERO)
	if airborne:
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		canvas.draw_circle(Vector2(0.0, radius * 0.55), radius * 0.8, _with_alpha(Color(0.0, 0.0, 0.0, 0.3), alpha))
	canvas.draw_set_transform(shake_offset + body_offset + (Vector2(0.0, -radius * 0.5) if airborne else Vector2.ZERO), 0.0, Vector2.ONE)

	canvas.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 40, outline, 2.5)

	match String(skin.get("base", "blob")):
		"frog":
			_base_frog(canvas, radius, rocked_forward, side, skin, walk_phase, moving)
		"turtle":
			_base_turtle(canvas, radius, rocked_forward, side, skin, walk_phase, moving, windup_t, strike, attack_aim.normalized(), attack_reach)
		"mustelid":
			_base_mustelid(canvas, radius, rocked_forward, side, skin, walk_phase, moving, strike)
		"bird":
			_base_bird(canvas, radius, rocked_forward, side, skin, walk_phase, moving, airborne)
		"serpent":
			_base_serpent(canvas, radius, rocked_forward, side, skin, walk_phase, moving)
		"croc":
			_base_croc(canvas, radius, rocked_forward, side, skin, walk_phase, moving)
		"crustacean":
			_base_crustacean(canvas, radius, rocked_forward, side, skin, walk_phase, moving, strike)
		"spider":
			_base_spider(canvas, radius, rocked_forward, side, skin, walk_phase, moving)
		"swarm":
			_base_swarm(canvas, radius, skin)
		"cluster":
			_base_cluster(canvas, radius, rocked_forward, side, skin)
		"bug":
			_base_bug(canvas, radius, rocked_forward, side, skin)
		_:
			canvas.draw_circle(Vector2.ZERO, radius + 2.0, _with_alpha(Color(0.05, 0.06, 0.06), alpha))
			canvas.draw_circle(Vector2.ZERO, radius, _with_alpha(creature_color(creature_id), alpha))

	if strike > 0.0:
		match String(skin.get("strike", "")):
			"tongue":
				_strike_tongue(canvas, radius, attack_aim.normalized(), attack_reach, strike)

	if flash_alpha > 0.0:
		canvas.draw_circle(Vector2.ZERO, radius + 3.0, Color(1.0, 1.0, 1.0, clampf(flash_alpha, 0.0, 1.0) * 0.85))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Snap out fast, HOLD the extended pose, then ease back — the hold is what
# makes small creatures' attacks readable.
static func _strike_curve(t: float) -> float:
	if t < 0.18:
		return t / 0.18
	if t < 0.6:
		return 1.0
	return 1.0 - (t - 0.6) / 0.4

# ---------- bases ----------

static func _base_frog(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool) -> void:
	var main: Color = skin.get("main", Color(0.36, 0.42, 0.2))
	var dark: Color = skin.get("dark", main.darkened(0.4))
	var belly: Color = skin.get("belly", main.lightened(0.25))
	var eye_color: Color = skin.get("eye", Color(0.8, 0.7, 0.3))

	var hop := sin(walk_phase * 1.2) * 0.5 + 0.5 if moving else 0.0
	var leg_extend := 0.55 + hop * 0.55

	for leg_side: float in [-1.0, 1.0]:
		var hip := -forward * radius * 0.45 + side * leg_side * radius * 0.62
		var knee := hip - forward * radius * 0.35 * leg_extend + side * leg_side * radius * 0.4
		var foot := knee - forward * radius * 0.55 * leg_extend - side * leg_side * radius * 0.08
		canvas.draw_line(hip, knee, dark, maxf(radius * 0.24, 3.0))
		canvas.draw_line(knee, foot, dark, maxf(radius * 0.18, 2.5))
		for toe in 3:
			canvas.draw_line(foot, foot + (-forward).rotated((float(toe) - 1.0) * 0.4) * radius * 0.22, dark, 1.5)

	for foot_side: float in [-1.0, 1.0]:
		var front_step := sin(walk_phase * 1.2 + PI * 0.5) * radius * 0.08 if moving else 0.0
		canvas.draw_circle(forward * (radius * 0.55 + front_step) + side * foot_side * radius * 0.4, radius * 0.13, dark)

	var body_points := PackedVector2Array()
	for i in 16:
		var body_angle := TAU * float(i) / 16.0
		var ry := radius * lerpf(0.85, 0.6, (cos(body_angle) * 0.5 + 0.5))
		body_points.append(forward * cos(body_angle) * radius * 0.95 + side * sin(body_angle) * ry)
	canvas.draw_colored_polygon(body_points, dark)
	var inner := PackedVector2Array()
	for point in body_points:
		inner.append(point * 0.88)
	canvas.draw_colored_polygon(inner, main)

	if bool(skin.get("stripes", false)):
		canvas.draw_colored_polygon(PackedVector2Array([
			forward * radius * 0.62 + side * radius * 0.22,
			forward * radius * 0.62 - side * radius * 0.22,
			forward * radius * 0.3
		]), dark.darkened(0.15))
		for stripe: float in [-0.3, 0.0, 0.3]:
			canvas.draw_line(forward * radius * 0.15 + side * radius * stripe, -forward * radius * 0.72 + side * radius * stripe * 1.4, dark.darkened(0.12), maxf(radius * 0.09, 1.5))
	if bool(skin.get("warts", false)):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 9:
			var wart := forward * rng.randf_range(-0.6, 0.5) * radius + side * rng.randf_range(-0.5, 0.5) * radius
			canvas.draw_circle(wart, maxf(radius * rng.randf_range(0.05, 0.09), 1.2), dark.lightened(0.12))
		for gland_side: float in [-1.0, 1.0]:
			canvas.draw_circle(forward * radius * 0.35 + side * gland_side * radius * 0.42, radius * 0.16, dark.lightened(0.06))
	if bool(skin.get("tympanum", false)):
		for ear_side: float in [-1.0, 1.0]:
			canvas.draw_arc(forward * radius * 0.42 + side * ear_side * radius * 0.5, radius * 0.12, 0.0, TAU, 12, dark, 1.5)

	for eye_side: float in [-1.0, 1.0]:
		var eye := forward * radius * 0.68 + side * eye_side * radius * 0.42
		canvas.draw_circle(eye, radius * 0.22, dark)
		canvas.draw_circle(eye, radius * 0.17, eye_color)
		canvas.draw_circle(eye + forward * radius * 0.05, maxf(radius * 0.08, 1.3), Color(0.08, 0.07, 0.04))

	if bool(skin.get("call_sac", false)):
		var sac_pulse := (sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5) * 0.35
		canvas.draw_circle(forward * radius * 0.88, radius * (0.14 + sac_pulse * 0.14), belly)

static func _base_turtle(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, windup_t: float, strike := 0.0, attack_aim := Vector2.ZERO, attack_reach := 0.0) -> void:
	var shell_color: Color = skin.get("shell", Color(0.26, 0.3, 0.16))
	var shell_rim: Color = skin.get("rim", shell_color.darkened(0.3))
	var skin_color: Color = skin.get("skin", Color(0.45, 0.4, 0.24))
	var skin_dark := skin_color.darkened(0.22)

	var tail_direction := (-forward).rotated(sin(walk_phase * 0.5) * 0.15)
	canvas.draw_line(tail_direction * radius * 0.9, tail_direction * radius * 1.45, skin_dark, maxf(radius * 0.16, 3.0))

	for leg_index in 4:
		var angle := [0.96, -0.96, 2.18, -2.18][leg_index] as float
		var step := (sin(walk_phase + (PI if leg_index % 2 == 0 else 0.0)) * radius * 0.12) if moving else 0.0
		var leg_center := (forward.rotated(angle) * radius * 0.92) + forward * step
		canvas.draw_circle(leg_center, radius * 0.26, skin_dark)
		canvas.draw_circle(leg_center, radius * 0.2, skin_color)
		var claw_direction := leg_center.normalized()
		for claw in 3:
			canvas.draw_line(leg_center + claw_direction.rotated((float(claw) - 1.0) * 0.35) * radius * 0.18, leg_center + claw_direction.rotated((float(claw) - 1.0) * 0.35) * radius * 0.34, Color(0.85, 0.82, 0.7), 1.5)

	# One head, three states: striking (neck extends along the attack aim),
	# winding up (retracted under the shell), or idle. Drawn BEFORE the shell
	# so the neck always emerges from underneath the carapace.
	var head_direction := forward
	var head_reach := radius * 1.05
	var neck_width := maxf(radius * 0.3, 4.0)
	if strike > 0.0 and attack_aim != Vector2.ZERO:
		head_direction = attack_aim
		head_reach = radius * 0.6 + (maxf(attack_reach, radius * 1.2) - radius * 0.6) * strike
	elif windup_t >= 0.0:
		head_reach = radius * (1.05 - 0.45 * windup_t)
	var head_center := head_direction * head_reach
	var head_side := Vector2(-head_direction.y, head_direction.x)
	canvas.draw_colored_polygon(PackedVector2Array([
		head_side * neck_width * 0.7,
		head_center + head_side * neck_width * 0.45,
		head_center - head_side * neck_width * 0.45,
		-head_side * neck_width * 0.7
	]), skin_dark)
	canvas.draw_circle(head_center, radius * 0.32, skin_dark)
	canvas.draw_circle(head_center, radius * 0.26, skin_color)
	if skin.has("neck_patch"):
		var patch: Color = skin["neck_patch"]
		canvas.draw_circle(head_center + head_side * radius * 0.2, radius * 0.1, patch)
		canvas.draw_circle(head_center - head_side * radius * 0.2, radius * 0.1, patch)
	if strike > 0.0:
		var jaw_open := (1.0 - strike) * 0.7 + 0.15
		canvas.draw_line(head_center, head_center + head_direction.rotated(jaw_open) * neck_width * 1.2, Color(0.95, 0.95, 0.9), 2.5)
		canvas.draw_line(head_center, head_center + head_direction.rotated(-jaw_open) * neck_width * 1.2, Color(0.95, 0.95, 0.9), 2.5)
	else:
		canvas.draw_line(head_center + head_direction * radius * 0.2, head_center + head_direction * radius * 0.4, skin_dark.darkened(0.2), 2.5)
	canvas.draw_circle(head_center + head_side * radius * 0.13 + head_direction * radius * 0.08, maxf(radius * 0.05, 1.2), Color(0.1, 0.09, 0.05))
	canvas.draw_circle(head_center - head_side * radius * 0.13 + head_direction * radius * 0.08, maxf(radius * 0.05, 1.2), Color(0.1, 0.09, 0.05))

	var shell_points := PackedVector2Array()
	for i in 18:
		var shell_angle := TAU * float(i) / 18.0
		shell_points.append(forward * cos(shell_angle) * radius * 1.02 + side * sin(shell_angle) * radius * 0.88)
	canvas.draw_colored_polygon(shell_points, shell_rim)
	var inner_points := PackedVector2Array()
	for i in 18:
		var shell_angle := TAU * float(i) / 18.0
		inner_points.append(forward * cos(shell_angle) * radius * 0.88 + side * sin(shell_angle) * radius * 0.74)
	canvas.draw_colored_polygon(inner_points, shell_color)
	if bool(skin.get("keels", false)):
		for keel: float in [-0.34, 0.0, 0.34]:
			canvas.draw_line(forward * radius * -0.7 + side * radius * keel, forward * radius * 0.72 + side * radius * keel, shell_rim.darkened(0.1), 2.0)
	for cross: float in [-0.42, 0.0, 0.42]:
		canvas.draw_line(forward * radius * cross - side * radius * 0.55, forward * radius * cross + side * radius * 0.55, shell_rim.darkened(0.06), 1.5)
	canvas.draw_line(forward * radius * -0.7, forward * radius * 0.72, shell_color.lightened(0.18), 1.5)

static func _base_mustelid(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, strike := 0.0) -> void:
	var fur: Color = skin.get("main", Color(0.24, 0.14, 0.09))
	var fur_dark: Color = skin.get("dark", fur.darkened(0.3))
	var belly: Color = skin.get("belly", fur.lightened(0.3))
	var bulk := float(skin.get("bulk", 1.0))
	var snout := float(skin.get("snout", 1.0))
	var stretch := 1.0 + strike * 0.5

	var spine: Array[Vector2] = []
	var segment_radii: Array[float] = []
	for i in 5:
		var t := float(i) / 4.0
		var along := lerpf(-1.35, 1.15, t) * radius * stretch
		var wiggle := 0.0
		if moving and strike <= 0.0:
			wiggle = sin(walk_phase * 1.4 - t * 2.6) * radius * 0.16 * (1.0 - t * 0.4)
		spine.append(forward * along + side * wiggle)
		segment_radii.append(radius * lerpf(0.4, 0.52, sin(t * PI)) * bulk)

	var tail_style := String(skin.get("tail", "bushy"))
	var tail_direction := (-forward).rotated(sin(walk_phase * 1.4 + 1.8) * 0.3 if moving else 0.12)
	var tail_base: Vector2 = spine[0]
	match tail_style:
		"paddle":
			var paddle_center := tail_base + tail_direction * radius * 1.0
			var paddle_points := PackedVector2Array()
			for i in 12:
				var paddle_angle := TAU * float(i) / 12.0
				paddle_points.append(paddle_center + tail_direction * cos(paddle_angle) * radius * 0.7 + side * sin(paddle_angle) * radius * 0.42)
			canvas.draw_colored_polygon(paddle_points, Color(0.16, 0.12, 0.1))
			canvas.draw_line(paddle_center - side * radius * 0.3, paddle_center + side * radius * 0.3, Color(0.1, 0.08, 0.07), 1.5)
		"fin":
			canvas.draw_colored_polygon(PackedVector2Array([
				tail_base + side * radius * 0.16,
				tail_base + tail_direction * radius * 1.3,
				tail_base - side * radius * 0.16
			]), fur_dark.lightened(0.08))
		"thick":
			for i in 4:
				var t := float(i) / 3.0
				canvas.draw_circle(tail_base + tail_direction * radius * (0.35 + t * 1.1), radius * lerpf(0.32, 0.14, t), fur_dark)
		_:
			for i in 4:
				var t := float(i) / 3.0
				canvas.draw_circle(tail_base + tail_direction * radius * (0.35 + t * 1.0), radius * lerpf(0.3, 0.12, t), fur_dark)

	if moving and strike <= 0.0:
		for paw_index in 4:
			var paw_t := [0.22, 0.36, 0.72, 0.86][paw_index] as float
			var paw_side := 1.0 if paw_index % 2 == 0 else -1.0
			var paw_step := sin(walk_phase * 1.4 + PI * float(paw_index)) * radius * 0.14
			canvas.draw_circle(spine[1].lerp(spine[3], paw_t) + side * paw_side * radius * 0.5 * bulk + forward * paw_step, radius * 0.13, fur_dark)

	for i in 5:
		canvas.draw_circle(spine[i], segment_radii[i] + 2.0, fur_dark)
	for i in 5:
		canvas.draw_circle(spine[i], segment_radii[i], fur)
	if not bool(skin.get("smooth", false)):
		canvas.draw_line(spine[0], spine[4], fur.lightened(0.12), maxf(radius * 0.14, 2.0))
	if bool(skin.get("spots", false)):
		var accent: Color = skin.get("accent", Color(0.9, 0.5, 0.15))
		for i in 4:
			canvas.draw_circle(spine[i] + side * (radius * 0.18 if i % 2 == 0 else radius * -0.18), maxf(radius * 0.08, 1.5), accent)

	var head: Vector2 = spine[4]
	if not bool(skin.get("smooth", false)):
		canvas.draw_circle(head + side * radius * 0.28 - forward * radius * 0.1, radius * 0.14, fur_dark)
		canvas.draw_circle(head - side * radius * 0.28 - forward * radius * 0.1, radius * 0.14, fur_dark)
	canvas.draw_circle(head, radius * 0.4 * bulk, fur)
	canvas.draw_circle(head + forward * radius * 0.28 * snout, radius * 0.18, fur.lightened(0.18))
	canvas.draw_circle(head + forward * radius * (0.34 * snout), maxf(radius * 0.07, 1.2), Color(0.1, 0.07, 0.05))
	canvas.draw_circle(head + forward * radius * 0.16, maxf(radius * 0.09, 1.4), belly)
	canvas.draw_circle(head + side * radius * 0.16 + forward * radius * 0.16, maxf(radius * 0.05, 1.0), Color(0.08, 0.05, 0.04))
	canvas.draw_circle(head - side * radius * 0.16 + forward * radius * 0.16, maxf(radius * 0.05, 1.0), Color(0.08, 0.05, 0.04))
	canvas.draw_line(head + forward * radius * 0.24, head + forward * radius * 0.44 + side * radius * 0.22, Color(0.8, 0.78, 0.7, 0.7), 1.0)
	canvas.draw_line(head + forward * radius * 0.24, head + forward * radius * 0.44 - side * radius * 0.22, Color(0.8, 0.78, 0.7, 0.7), 1.0)

	if strike > 0.25:
		var fang_origin := head + forward * radius * 0.4
		canvas.draw_line(fang_origin + side * 2.0, fang_origin + forward * radius * 0.4 + side * 2.0, Color(0.98, 0.98, 0.92, strike), 2.0)
		canvas.draw_line(fang_origin - side * 2.0, fang_origin + forward * radius * 0.4 - side * 2.0, Color(0.98, 0.98, 0.92, strike), 2.0)

static func _base_bird(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, airborne: bool) -> void:
	var main: Color = skin.get("main", Color(0.4, 0.32, 0.22))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var breast: Color = skin.get("breast", main.lightened(0.25))
	var beak: Color = skin.get("beak", Color(0.8, 0.7, 0.35))
	var beak_len := float(skin.get("beak_len", 0.4))
	var neck := float(skin.get("neck", 0.0))
	var head_color: Color = skin.get("head_color", main)

	# Tail fan.
	canvas.draw_colored_polygon(PackedVector2Array([
		-forward * radius * 0.5 + side * radius * 0.22,
		-forward * radius * (1.15 + (0.1 if airborne else 0.0)) + side * radius * 0.4,
		-forward * radius * (1.2 + (0.1 if airborne else 0.0)),
		-forward * radius * (1.15 + (0.1 if airborne else 0.0)) - side * radius * 0.4,
		-forward * radius * 0.5 - side * radius * 0.22
	]), dark)

	if airborne:
		# Extended flapping wings.
		var flap := sin(Time.get_ticks_msec() * 0.012 + walk_phase) * 0.35
		for wing_side: float in [-1.0, 1.0]:
			var wing_tip := side * wing_side * radius * 1.9 + forward * radius * (0.1 + flap * wing_side * wing_side)
			canvas.draw_colored_polygon(PackedVector2Array([
				forward * radius * 0.35 + side * wing_side * radius * 0.3,
				wing_tip + forward * radius * (0.25 + flap),
				wing_tip - forward * radius * 0.35,
				-forward * radius * 0.45 + side * wing_side * radius * 0.3
			]), dark)
			canvas.draw_line(forward * radius * 0.2 + side * wing_side * radius * 0.4, wing_tip, main.lightened(0.1), 2.0)
	else:
		# Folded wings hugging the body.
		for wing_side: float in [-1.0, 1.0]:
			canvas.draw_colored_polygon(PackedVector2Array([
				forward * radius * 0.4 + side * wing_side * radius * 0.35,
				-forward * radius * 0.9 + side * wing_side * radius * 0.55,
				-forward * radius * 0.2 + side * wing_side * radius * 0.7
			]), dark.lightened(0.06))

	# Body.
	var body_points := PackedVector2Array()
	for i in 14:
		var body_angle := TAU * float(i) / 14.0
		body_points.append(forward * cos(body_angle) * radius * 0.8 + side * sin(body_angle) * radius * 0.62)
	canvas.draw_colored_polygon(body_points, main)
	canvas.draw_circle(forward * radius * 0.3, radius * 0.34, breast)

	# Legs when grounded.
	if not airborne and moving:
		for leg_side: float in [-1.0, 1.0]:
			var leg_step := sin(walk_phase * 1.6 + (PI if leg_side > 0.0 else 0.0)) * radius * 0.12
			canvas.draw_line(side * leg_side * radius * 0.2, side * leg_side * radius * 0.24 + forward * leg_step - forward * radius * 0.05, beak.darkened(0.2), 1.5)

	# Head (long neck for heron), beak, eyes.
	var head_center := forward * radius * (0.75 + neck * 0.55)
	if neck > 0.0:
		canvas.draw_line(forward * radius * 0.5, head_center, main, maxf(radius * 0.2, 2.5))
	canvas.draw_circle(head_center, radius * 0.3, head_color)
	if bool(skin.get("facial_disc", false)):
		canvas.draw_arc(head_center, radius * 0.26, 0.0, TAU, 20, breast, 2.0)
	if bool(skin.get("tufts", false)):
		for tuft_side: float in [-1.0, 1.0]:
			canvas.draw_line(head_center + side * tuft_side * radius * 0.18 - forward * radius * 0.1, head_center + side * tuft_side * radius * 0.32 - forward * radius * 0.26, dark, 2.0)
	if bool(skin.get("flat_bill", false)):
		canvas.draw_colored_polygon(PackedVector2Array([
			head_center + forward * radius * 0.2 + side * radius * 0.14,
			head_center + forward * radius * (0.2 + beak_len) + side * radius * 0.1,
			head_center + forward * radius * (0.2 + beak_len) - side * radius * 0.1,
			head_center + forward * radius * 0.2 - side * radius * 0.14
		]), beak)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([
			head_center + forward * radius * 0.16 + side * radius * 0.1,
			head_center + forward * radius * (0.16 + beak_len),
			head_center + forward * radius * 0.16 - side * radius * 0.1
		]), beak)
	canvas.draw_circle(head_center + side * radius * 0.14 + forward * radius * 0.06, maxf(radius * 0.06, 1.2), Color(0.95, 0.85, 0.3) if bool(skin.get("facial_disc", false)) else Color(0.08, 0.06, 0.05))
	canvas.draw_circle(head_center - side * radius * 0.14 + forward * radius * 0.06, maxf(radius * 0.06, 1.2), Color(0.95, 0.85, 0.3) if bool(skin.get("facial_disc", false)) else Color(0.08, 0.06, 0.05))

static func _base_serpent(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool) -> void:
	var main: Color = skin.get("main", Color(0.36, 0.26, 0.15))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var segments := 9
	var slither := 1.0 if moving else 0.3
	var points: Array[Vector2] = []
	for i in segments:
		var t := float(i) / float(segments - 1)
		var along := lerpf(0.9, -2.2, t) * radius
		var sway := sin(walk_phase * 1.6 + t * 4.2) * radius * 0.3 * slither * t
		points.append(forward * along + side * sway)
	for i in range(segments - 1, -1, -1):
		var t := float(i) / float(segments - 1)
		var seg_radius := radius * lerpf(0.42, 0.12, t)
		canvas.draw_circle(points[i], seg_radius + 1.5, dark)
	for i in range(segments - 1, -1, -1):
		var t := float(i) / float(segments - 1)
		var seg_radius := radius * lerpf(0.42, 0.12, t)
		canvas.draw_circle(points[i], seg_radius, dark if i % 2 == 1 else main)
	# Head with flicking tongue.
	var head: Vector2 = points[0]
	canvas.draw_circle(head, radius * 0.45, main)
	canvas.draw_circle(head + side * radius * 0.18 + forward * radius * 0.16, maxf(radius * 0.07, 1.2), Color(0.85, 0.6, 0.1))
	canvas.draw_circle(head - side * radius * 0.18 + forward * radius * 0.16, maxf(radius * 0.07, 1.2), Color(0.85, 0.6, 0.1))
	if fmod(Time.get_ticks_msec() * 0.001, 1.6) < 0.25:
		var tongue_tip := head + forward * radius * 0.85
		canvas.draw_line(head + forward * radius * 0.4, tongue_tip, Color(0.85, 0.2, 0.25), 1.5)
		canvas.draw_line(tongue_tip, tongue_tip + forward.rotated(0.5) * radius * 0.15, Color(0.85, 0.2, 0.25), 1.5)
		canvas.draw_line(tongue_tip, tongue_tip + forward.rotated(-0.5) * radius * 0.15, Color(0.85, 0.2, 0.25), 1.5)

static func _base_croc(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool) -> void:
	var main: Color = skin.get("main", Color(0.2, 0.26, 0.17))
	var dark: Color = skin.get("dark", main.darkened(0.35))

	# Keeled tail, swaying.
	var tail_direction := (-forward).rotated(sin(walk_phase * 0.9) * 0.25 if moving else 0.08)
	for i in 5:
		var t := float(i) / 4.0
		var tail_point := -forward * radius * 0.7 + tail_direction * radius * (0.3 + t * 1.5)
		canvas.draw_circle(tail_point, radius * lerpf(0.34, 0.08, t), dark)
		if i < 4:
			canvas.draw_line(tail_point, tail_point + tail_direction.rotated(PI * 0.5) * radius * 0.12, dark.darkened(0.15), 1.5)

	# Stubby legs.
	for leg_index in 4:
		var angle := [1.1, -1.1, 2.2, -2.2][leg_index] as float
		var step := (sin(walk_phase + (PI if leg_index % 2 == 0 else 0.0)) * radius * 0.1) if moving else 0.0
		var leg_center := forward.rotated(angle) * radius * 0.78 + forward * step
		canvas.draw_circle(leg_center, radius * 0.2, dark)

	# Body: broad armored oval.
	var body_points := PackedVector2Array()
	for i in 16:
		var body_angle := TAU * float(i) / 16.0
		body_points.append(forward * cos(body_angle) * radius * 0.95 + side * sin(body_angle) * radius * 0.6)
	canvas.draw_colored_polygon(body_points, dark)
	var inner := PackedVector2Array()
	for point in body_points:
		inner.append(point * 0.86)
	canvas.draw_colored_polygon(inner, main)
	# Scute rows.
	for row: float in [-0.24, 0.0, 0.24]:
		for i in 4:
			var scute := forward * radius * (-0.5 + float(i) * 0.32) + side * radius * row
			canvas.draw_circle(scute, maxf(radius * 0.06, 1.5), dark.lightened(0.08))

	# Long snout with nostrils and raised eyes.
	var snout_points := PackedVector2Array([
		forward * radius * 0.7 + side * radius * 0.3,
		forward * radius * 1.55 + side * radius * 0.18,
		forward * radius * 1.62,
		forward * radius * 1.55 - side * radius * 0.18,
		forward * radius * 0.7 - side * radius * 0.3
	])
	canvas.draw_colored_polygon(snout_points, main)
	canvas.draw_circle(forward * radius * 1.52 + side * radius * 0.08, maxf(radius * 0.04, 1.0), dark)
	canvas.draw_circle(forward * radius * 1.52 - side * radius * 0.08, maxf(radius * 0.04, 1.0), dark)
	canvas.draw_circle(forward * radius * 0.78 + side * radius * 0.22, radius * 0.1, dark)
	canvas.draw_circle(forward * radius * 0.78 - side * radius * 0.22, radius * 0.1, dark)
	canvas.draw_circle(forward * radius * 0.78 + side * radius * 0.22, maxf(radius * 0.05, 1.2), Color(0.85, 0.75, 0.3))
	canvas.draw_circle(forward * radius * 0.78 - side * radius * 0.22, maxf(radius * 0.05, 1.2), Color(0.85, 0.75, 0.3))

static func _base_crustacean(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, strike := 0.0) -> void:
	var main: Color = skin.get("main", Color(0.5, 0.2, 0.1))
	var dark: Color = skin.get("dark", main.darkened(0.35))

	# Fan tail.
	canvas.draw_colored_polygon(PackedVector2Array([
		-forward * radius * 0.6,
		-forward * radius * 1.25 + side * radius * 0.4,
		-forward * radius * 1.35,
		-forward * radius * 1.25 - side * radius * 0.4
	]), dark)

	# Walking legs.
	for leg_index in 8:
		var leg_side := 1.0 if leg_index % 2 == 0 else -1.0
		var leg_t := float(leg_index / 2) / 3.0
		var leg_base := forward * lerpf(0.3, -0.5, leg_t) * radius
		var leg_step := sin(walk_phase * 1.8 + float(leg_index) * PI * 0.5) * 0.15 if moving else 0.0
		var leg_tip := leg_base + side * leg_side * radius * 0.85 + forward * radius * leg_step
		canvas.draw_line(leg_base, leg_tip, dark, 1.5)

	# Segmented abdomen + carapace.
	for i in 3:
		canvas.draw_circle(-forward * radius * (0.25 + float(i) * 0.22), radius * (0.42 - float(i) * 0.06), dark if i % 2 == 1 else main)
	canvas.draw_circle(forward * radius * 0.15, radius * 0.5, main)
	canvas.draw_line(forward * radius * 0.5, forward * radius * 0.0, dark, 1.5)

	# Big claws, opening on strike.
	var claw_open := 0.25 + strike * 0.6
	for claw_side: float in [-1.0, 1.0]:
		var arm_base := forward * radius * 0.4 + side * claw_side * radius * 0.35
		var claw_center := forward * radius * (0.85 + strike * 0.3) + side * claw_side * radius * 0.55
		canvas.draw_line(arm_base, claw_center, main, maxf(radius * 0.14, 2.0))
		canvas.draw_circle(claw_center, radius * 0.24, dark)
		canvas.draw_circle(claw_center, radius * 0.19, main)
		canvas.draw_line(claw_center, claw_center + forward.rotated(claw_open * claw_side) * radius * 0.3, dark, 2.0)
		canvas.draw_line(claw_center, claw_center + forward.rotated(-claw_open * 0.4 * claw_side) * radius * 0.3, dark, 2.0)

	# Antennae.
	for antenna_side: float in [-1.0, 1.0]:
		canvas.draw_line(forward * radius * 0.55 + side * antenna_side * radius * 0.12, forward * radius * 1.15 + side * antenna_side * radius * 0.45, dark.lightened(0.1), 1.0)
	canvas.draw_circle(forward * radius * 0.5 + side * radius * 0.14, maxf(radius * 0.06, 1.2), Color(0.08, 0.05, 0.04))
	canvas.draw_circle(forward * radius * 0.5 - side * radius * 0.14, maxf(radius * 0.06, 1.2), Color(0.08, 0.05, 0.04))

static func _base_spider(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool) -> void:
	var main: Color = skin.get("main", Color(0.3, 0.22, 0.12))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var accent: Color = skin.get("accent", main.lightened(0.3))

	# Eight legs, two joints each, alternating gait.
	for leg_index in 8:
		var leg_side := 1.0 if leg_index % 2 == 0 else -1.0
		var pair := leg_index / 2
		var base_angle := lerpf(0.45, 2.2, float(pair) / 3.0) * leg_side
		var step := sin(walk_phase * 2.0 + float(pair) * PI * 0.5 + (PI if leg_side > 0.0 else 0.0)) * 0.18 if moving else 0.0
		var knee := forward.rotated(base_angle + step) * radius * 0.85
		var foot := forward.rotated(base_angle + step * 1.4) * radius * 1.35
		canvas.draw_line(Vector2.ZERO, knee, dark, maxf(radius * 0.09, 1.5))
		canvas.draw_line(knee, foot, dark, maxf(radius * 0.06, 1.2))

	# Abdomen + cephalothorax with dorsal stripe.
	canvas.draw_circle(-forward * radius * 0.45, radius * 0.52, dark)
	canvas.draw_circle(-forward * radius * 0.45, radius * 0.45, main)
	canvas.draw_circle(forward * radius * 0.25, radius * 0.4, main)
	canvas.draw_line(-forward * radius * 0.85, forward * radius * 0.55, accent, maxf(radius * 0.12, 2.0))

	# Eye cluster: wolf spiders have two big forward eyes.
	canvas.draw_circle(forward * radius * 0.52 + side * radius * 0.1, maxf(radius * 0.08, 1.4), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(forward * radius * 0.52 - side * radius * 0.1, maxf(radius * 0.08, 1.4), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(forward * radius * 0.58 + side * radius * 0.22, maxf(radius * 0.04, 1.0), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(forward * radius * 0.58 - side * radius * 0.22, maxf(radius * 0.04, 1.0), Color(0.05, 0.04, 0.03))

static func _base_swarm(canvas: CanvasItem, radius: float, skin: Dictionary) -> void:
	var main: Color = skin.get("main", Color(0.4, 0.4, 0.42))
	var dark: Color = skin.get("dark", Color(0.2, 0.2, 0.22))
	canvas.draw_circle(Vector2.ZERO, radius, Color(dark.r, dark.g, dark.b, 0.25))
	var time_now := Time.get_ticks_msec() * 0.001
	for i in 12:
		var orbit_angle := time_now * (1.2 + float(i % 4) * 0.35) + float(i) * TAU / 12.0
		var orbit_radius := radius * (0.3 + 0.6 * float((i * 7) % 10) / 10.0)
		var dot := Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
		canvas.draw_circle(dot, maxf(radius * 0.09, 1.6), dark)
		canvas.draw_line(dot + Vector2(-2.0, -1.0), dot + Vector2(2.0, -1.0), Color(main.r, main.g, main.b, 0.6), 1.0)

static func _base_cluster(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary) -> void:
	var main: Color = skin.get("main", Color(0.27, 0.11, 0.08))
	var dark: Color = skin.get("dark", Color(0.16, 0.06, 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wriggle := Time.get_ticks_msec() * 0.002
	for i in 12:
		var offset := Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)) * radius
		var leech_forward := forward.rotated(rng.randf_range(-PI, PI) + sin(wriggle + float(i)) * 0.3)
		var leech_side := Vector2(-leech_forward.y, leech_forward.x)
		var half_len := radius * 0.28
		var points := PackedVector2Array([
			offset - leech_forward * half_len + leech_side * radius * 0.08,
			offset + leech_forward * half_len + leech_side * radius * 0.05,
			offset + leech_forward * (half_len + radius * 0.08),
			offset + leech_forward * half_len - leech_side * radius * 0.05,
			offset - leech_forward * half_len - leech_side * radius * 0.08
		])
		canvas.draw_colored_polygon(points, dark if i % 3 == 0 else main)

static func _base_bug(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary) -> void:
	var main: Color = skin.get("main", Color(0.22, 0.16, 0.1))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var glow: Color = skin.get("glow", Color(0.95, 0.9, 0.4))
	var pulse := sin(Time.get_ticks_msec() * 0.006) * 0.5 + 0.5
	# Bioluminescent glow halo.
	canvas.draw_circle(-forward * radius * 0.4, radius * (1.6 + pulse * 0.5), Color(glow.r, glow.g, glow.b, 0.1 + pulse * 0.08))
	canvas.draw_circle(-forward * radius * 0.4, radius * 0.55, Color(glow.r, glow.g, glow.b, 0.55 + pulse * 0.35))
	# Wings blurred mid-beat.
	for wing_side: float in [-1.0, 1.0]:
		canvas.draw_circle(side * wing_side * radius * 0.5 + forward * radius * 0.1, radius * 0.4, Color(0.8, 0.85, 0.9, 0.25))
	# Body + head.
	canvas.draw_circle(Vector2.ZERO, radius * 0.42, dark)
	canvas.draw_circle(forward * radius * 0.42, radius * 0.28, main)
	canvas.draw_circle(forward * radius * 0.55 + side * radius * 0.1, maxf(radius * 0.07, 1.2), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(forward * radius * 0.55 - side * radius * 0.1, maxf(radius * 0.07, 1.2), Color(0.05, 0.04, 0.03))

# ---------- strike overlays ----------

static func _strike_tongue(canvas: CanvasItem, radius: float, aim: Vector2, reach: float, progress: float) -> void:
	# Originates at the mouth (front of the head, between the eyes).
	var mouth := aim * radius * 0.72
	var tongue_tip := aim * (radius * 0.72 + (reach - radius * 0.72) * progress)
	var tongue_color := Color(0.98, 0.42, 0.52)
	canvas.draw_line(mouth, tongue_tip, Color(0.5, 0.14, 0.2), maxf(radius * 0.34, 6.0))
	canvas.draw_line(mouth, tongue_tip, tongue_color, maxf(radius * 0.24, 4.0))
	canvas.draw_circle(tongue_tip, maxf(radius * 0.26, 5.0), tongue_color.lightened(0.15))
	canvas.draw_circle(tongue_tip, maxf(radius * 0.13, 2.5), Color(1.0, 0.85, 0.88))

# ---------- non-creature drawing ----------

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

static func _draw_cells(canvas: CanvasItem, cells: Array, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	for cell in cells:
		_draw_cell(canvas, cell, pixel_size, color, origin)

static func _draw_cell(canvas: CanvasItem, cell: Vector2i, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	var cell_position := Vector2((float(cell.x) - origin.x) * pixel_size, (float(cell.y) - origin.y) * pixel_size)
	canvas.draw_rect(Rect2(cell_position, Vector2(pixel_size, pixel_size)), color)

static func _with_alpha(color: Color, alpha: float) -> Color:
	var output := color
	output.a *= alpha
	return output
