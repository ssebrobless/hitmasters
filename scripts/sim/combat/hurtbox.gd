extends RefCounted

# Authored hurtbox hulls (decision #21, RESEARCH_COMBAT_DEPTH.md Phase A).
# A hull is the broad "did this credibly hit the creature?" shape derived from
# the roster footprint: a circle for most creatures, an oriented capsule for
# long bodies (Water Snake, Alligator). Deterministic: the capsule axis comes
# from sim state only (velocity heading, falling back to last aim direction).

const AXIS_SPEED_THRESHOLD_PX := 20.0

static func hull_of(actor: Node) -> Dictionary:
	var center: Vector2 = (actor as Node2D).global_position if actor is Node2D else Vector2.ZERO
	var radius := _get_float(actor, "body_radius", 0.0)
	var half_len := _get_float(actor, "body_capsule_half_len_px", 0.0)
	if half_len <= 0.0:
		return {"kind": "circle", "center": center, "radius": radius, "half_len": 0.0, "axis": Vector2.RIGHT}
	return {"kind": "capsule", "center": center, "radius": radius, "half_len": half_len, "axis": body_axis(actor)}

static func body_axis(actor: Node) -> Vector2:
	var velocity: Variant = actor.get("velocity")
	if velocity is Vector2 and (velocity as Vector2).length() > AXIS_SPEED_THRESHOLD_PX:
		return (velocity as Vector2).normalized()
	var aim: Variant = actor.get("last_aim_direction")
	if aim is Vector2 and (aim as Vector2) != Vector2.ZERO:
		return (aim as Vector2).normalized()
	return Vector2.RIGHT

# Closest point on the hull's core segment (circle => center). Facing checks
# and distance math both route through this so circles keep exact legacy
# behavior while capsules gain length.
static func core_closest_point(hull: Dictionary, from: Vector2) -> Vector2:
	var center: Vector2 = hull.get("center", Vector2.ZERO)
	var half_len := float(hull.get("half_len", 0.0))
	if half_len <= 0.0:
		return center
	var axis: Vector2 = hull.get("axis", Vector2.RIGHT)
	var along := clampf((from - center).dot(axis), -half_len, half_len)
	return center + axis * along

static func distance_to_hull(hull: Dictionary, from: Vector2) -> float:
	return maxf(0.0, from.distance_to(core_closest_point(hull, from)) - float(hull.get("radius", 0.0)))

static func overlaps_circle(hull: Dictionary, center: Vector2, radius: float) -> bool:
	return distance_to_hull(hull, center) <= radius

# Point on the hull surface nearest `from` (== `from` clamped in if inside).
# Used for hit position/normal metadata (Phase B) and latch anchors (#30).
static func surface_point(hull: Dictionary, from: Vector2) -> Vector2:
	var core := core_closest_point(hull, from)
	var offset := from - core
	var radius := float(hull.get("radius", 0.0))
	if offset.length() <= 0.0001:
		return core + Vector2.RIGHT * radius
	return core + offset.normalized() * minf(radius, offset.length())

# Swept segment (hitscan line / projectile step) vs hull. Returns
# {hit: bool, point: Vector2, normal: Vector2}.
static func segment_hit(hull: Dictionary, from: Vector2, to: Vector2, half_width: float) -> Dictionary:
	var radius := float(hull.get("radius", 0.0)) + half_width
	var half_len := float(hull.get("half_len", 0.0))
	var core_a: Vector2 = hull.get("center", Vector2.ZERO)
	var core_b := core_a
	if half_len > 0.0:
		var axis: Vector2 = hull.get("axis", Vector2.RIGHT)
		core_a = hull.center - axis * half_len
		core_b = hull.center + axis * half_len
	var pair := _closest_segment_points(from, to, core_a, core_b)
	var on_shot: Vector2 = pair[0]
	var on_core: Vector2 = pair[1]
	if on_shot.distance_to(on_core) > radius:
		return {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}
	var point := surface_point(hull, on_shot)
	var normal := (on_shot - on_core).normalized() if on_shot.distance_to(on_core) > 0.0001 else (from - to).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.RIGHT
	return {"hit": true, "point": point, "normal": normal}

# Closest points between two segments (Ericson, clamped) — pure float math,
# deterministic, no physics engine.
static func _closest_segment_points(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> Array[Vector2]:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 0.0001 and e <= 0.0001:
		return [p1, p2]
	if a <= 0.0001:
		t = clampf(f / e, 0.0, 1.0)
	elif e <= 0.0001:
		s = clampf(-d1.dot(r) / a, 0.0, 1.0)
	else:
		var b := d1.dot(d2)
		var c := d1.dot(r)
		var denom := a * e - b * b
		if denom > 0.0001:
			s = clampf((b * f - c * e) / denom, 0.0, 1.0)
		t = (b * s + f) / e
		if t < 0.0:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((b - c) / a, 0.0, 1.0)
	return [p1 + d1 * s, p2 + d2 * t]

static func _get_float(node: Node, property: String, fallback: float) -> float:
	if node == null or not is_instance_valid(node):
		return fallback
	var value: Variant = node.get(property)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback
