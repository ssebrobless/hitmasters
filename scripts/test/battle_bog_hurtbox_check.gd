extends SceneTree

# Phase A acceptance (decision #21, RESEARCH_COMBAT_DEPTH.md):
# 1. Circle hulls behave exactly like the legacy center+radius math.
# 2. Capsule hulls (Water Snake, Alligator) are hittable along their length.
# 3. Capsule axis derives deterministically from velocity, aim fallback.
# 4. Roster capsule footprints parse to the designed sizes (the pre-#21 bug
#    collapsed Alligator to a 14.4 px circle).

const HurtboxScript := preload("res://scripts/sim/combat/hurtbox.gd")
const HitShapeScript := preload("res://scripts/sim/combat/hit_shape.gd")

class FakeBody:
	extends Node2D
	var body_radius := 10.0
	var body_capsule_half_len_px := 0.0
	var velocity := Vector2.ZERO
	var last_aim_direction := Vector2.RIGHT
	var creature_data: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	_check_circle_parity(failures)
	_check_capsule_geometry(failures)
	_check_axis_rules(failures)
	_check_authored_regions(failures)
	_check_roster_parse(failures)
	print("hurtbox_check failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _make_body(pos: Vector2, radius: float, half_len := 0.0) -> FakeBody:
	var body := FakeBody.new()
	body.body_radius = radius
	body.body_capsule_half_len_px = half_len
	get_root().add_child(body)
	body.global_position = pos
	return body

func _melee_shape(origin: Vector2, aim: Vector2, radius: float) -> Dictionary:
	return {"kind": "melee_arc", "origin": origin, "aim": aim, "radius": radius, "facing_dot_min": 0.15}

func _line_shape(from: Vector2, to: Vector2, half_width: float) -> Dictionary:
	return {"kind": "line", "from": from, "to": to, "origin": from, "aim": (to - from).normalized(), "range_px": from.distance_to(to), "half_width_px": half_width}

func _check_circle_parity(failures: Array[String]) -> void:
	var target := _make_body(Vector2(50, 0), 10.0)
	# Legacy: hit when |to_center| <= shape.radius + body_radius (50 <= 45+10).
	if not HitShapeScript.overlaps_melee_arc(_melee_shape(Vector2.ZERO, Vector2.RIGHT, 45.0), target):
		failures.append("circle parity: melee arc should hit circle at 50 with radius 45+10")
	# Legacy miss: 50 > 30+10.
	if HitShapeScript.overlaps_melee_arc(_melee_shape(Vector2.ZERO, Vector2.RIGHT, 30.0), target):
		failures.append("circle parity: melee arc should miss circle at 50 with radius 30+10")
	# Facing gate: target dead-perpendicular, dot 0 < 0.15.
	var side_target := _make_body(Vector2(0, 50), 10.0)
	if HitShapeScript.overlaps_melee_arc(_melee_shape(Vector2.ZERO, Vector2.RIGHT, 60.0), side_target):
		failures.append("circle parity: facing gate should reject perpendicular target")
	# Line: on-axis hit within range, lateral miss beyond radius+half_width.
	if not HitShapeScript.overlaps_line(_line_shape(Vector2.ZERO, Vector2(80, 0), 2.0), target):
		failures.append("circle parity: line should hit circle on axis")
	var far_side := _make_body(Vector2(40, 20), 10.0)
	if HitShapeScript.overlaps_line(_line_shape(Vector2.ZERO, Vector2(80, 0), 2.0), far_side):
		failures.append("circle parity: line should miss circle 20 px lateral (radius 10 + width 2)")
	# Out of range along the axis.
	var beyond := _make_body(Vector2(120, 0), 10.0)
	if HitShapeScript.overlaps_line(_line_shape(Vector2.ZERO, Vector2(80, 0), 2.0), beyond):
		failures.append("circle parity: line should miss circle past its range end (dist 40 - 10 - 2 > 0)")
	for node in [target, side_target, far_side, beyond]:
		node.queue_free()

func _check_capsule_geometry(failures: Array[String]) -> void:
	# Alligator-like: radius 14.4, half core length 9.6, axis RIGHT (aim).
	var gator := _make_body(Vector2(60, 0), 14.4, 9.6)
	# A shot ending at x=40 misses the old center circle (60-14.4 > 40) but
	# must hit the capsule (near cap at 60-9.6-14.4 = 36).
	if not HitShapeScript.overlaps_line(_line_shape(Vector2.ZERO, Vector2(40, 0), 2.0), gator):
		failures.append("capsule: short shot should reach the near cap of the capsule")
	# Distance math: from beside the tail cap.
	var hull: Dictionary = HurtboxScript.hull_of(gator)
	var expected := Vector2(69.6, 0)
	var core: Vector2 = HurtboxScript.core_closest_point(hull, Vector2(120, 0))
	if core.distance_to(expected) > 0.01:
		failures.append("capsule: core closest point expected %s got %s" % [expected, core])
	if absf(HurtboxScript.distance_to_hull(hull, Vector2(120, 0)) - (120.0 - 69.6 - 14.4)) > 0.01:
		failures.append("capsule: distance_to_hull wrong along axis")
	# Water-snake-like: radius 6.4, half len 13.6, axis RIGHT; a perpendicular
	# shot passing 20 px above the spine must MISS (slim body), even though a
	# fat circle of the same total length (r=20) would have been hit.
	var snake := _make_body(Vector2(0, 20), 6.4, 13.6)
	if HitShapeScript.overlaps_line(_line_shape(Vector2(-40, 0), Vector2(40, 0), 2.0), snake):
		failures.append("capsule: slim snake should not be hit 20 px off its spine")
	# Melee arc along the body: origin near the tail still connects.
	if not HitShapeScript.overlaps_melee_arc(_melee_shape(Vector2(-25, 20), Vector2.RIGHT, 10.0), snake):
		failures.append("capsule: melee arc at the tail cap should connect (dist to hull < reach)")
	gator.queue_free()
	snake.queue_free()

func _check_axis_rules(failures: Array[String]) -> void:
	var body := _make_body(Vector2.ZERO, 6.4, 13.6)
	body.velocity = Vector2(0, 100)
	body.last_aim_direction = Vector2.RIGHT
	var hull: Dictionary = HurtboxScript.hull_of(body)
	if (hull.axis as Vector2).distance_to(Vector2(0, 1)) > 0.001:
		failures.append("axis: moving body should orient the capsule along velocity")
	body.velocity = Vector2.ZERO
	hull = HurtboxScript.hull_of(body)
	if (hull.axis as Vector2).distance_to(Vector2(1, 0)) > 0.001:
		failures.append("axis: idle body should orient the capsule along last aim")
	body.queue_free()

func _check_authored_regions(failures: Array[String]) -> void:
	var snake := _make_body(Vector2.ZERO, 6.4, 13.6)
	snake.creature_data = {
		"hurtbox_regions": [
			{"name": "head", "offset_units": [1.25, 0.0], "radius_units": 0.45, "mult": 1.35, "open_when": "always"}
		]
	}
	var head: Dictionary = HurtboxScript.region_at(snake, Vector2(20.0, 0.0))
	if String(head.get("region", "")) != "head" or absf(float(head.get("region_mult", 0.0)) - 1.35) > 0.001:
		failures.append("authored regions: snake head expected 1.35 got %s" % str(head))
	var hull: Dictionary = HurtboxScript.region_at(snake, Vector2(-20.0, 0.0))
	if String(hull.get("region", "")) != "hull" or absf(float(hull.get("region_mult", 0.0)) - 1.0) > 0.001:
		failures.append("authored regions: snake tail should fall back to hull got %s" % str(hull))
	var turtle := _make_body(Vector2.ZERO, 25.6)
	turtle.creature_data = {
		"hurtbox_regions": [
			{"name": "shell_rear", "offset_units": [-0.75, 0.0], "radius_units": 0.55, "mult": 0.75, "open_when": "always"}
		]
	}
	var shell: Dictionary = HurtboxScript.region_at(turtle, Vector2(-12.0, 0.0))
	if String(shell.get("region", "")) != "shell_rear" or absf(float(shell.get("region_mult", 0.0)) - 0.75) > 0.001:
		failures.append("authored regions: turtle rear shell expected 0.75 got %s" % str(shell))
	snake.queue_free()
	turtle.queue_free()

func _check_roster_parse(failures: Array[String]) -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null:
		failures.append("roster parse: CreatureCatalog autoload missing")
		return
	for expectation in [
		{"id": "water_snake", "radius": 0.4 * 16.0, "half_len": (2.5 * 16.0) * 0.5 - 0.4 * 16.0},
		{"id": "alligator", "radius": 0.9 * 16.0, "half_len": (3.0 * 16.0) * 0.5 - 0.9 * 16.0}
	]:
		var data: Dictionary = catalog.get_creature(String(expectation.id))
		var footprint: Dictionary = data.get("footprint", {})
		var radius_px: float = catalog.units_to_px(float(footprint.get("radius_units", 0.0)))
		var length_px: float = catalog.units_to_px(float(footprint.get("length_units", 0.0)))
		var half_len_px: float = maxf(0.0, length_px * 0.5 - radius_px)
		if absf(radius_px - float(expectation.radius)) > 0.01:
			failures.append("roster parse: %s radius expected %.2f got %.2f" % [expectation.id, expectation.radius, radius_px])
		if absf(half_len_px - float(expectation.half_len)) > 0.01:
			failures.append("roster parse: %s half_len expected %.2f got %.2f" % [expectation.id, expectation.half_len, half_len_px])
		if String(footprint.get("shape", "")) != "capsule":
			failures.append("roster parse: %s footprint shape should be capsule" % expectation.id)
	var snake_data: Dictionary = catalog.get_creature("water_snake")
	var snake_regions: Array = snake_data.get("hurtbox_regions", [])
	if snake_regions.is_empty() or String((snake_regions[0] as Dictionary).get("name", "")) != "head":
		failures.append("roster parse: water_snake should define a head hurtbox region")
	var turtle_data: Dictionary = catalog.get_creature("snapping_turtle")
	var turtle_regions: Array = turtle_data.get("hurtbox_regions", [])
	if turtle_regions.is_empty() or String((turtle_regions[0] as Dictionary).get("name", "")) != "shell_rear":
		failures.append("roster parse: snapping_turtle should define a shell_rear hurtbox region")
