extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")

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
	if actor != null and actor.has_method("get_body_axis"):
		var body_axis_value: Variant = actor.get_body_axis()
		if body_axis_value is Vector2 and (body_axis_value as Vector2) != Vector2.ZERO:
			return (body_axis_value as Vector2).normalized()
	var body_heading: Variant = actor.get("body_heading")
	if body_heading is Vector2 and (body_heading as Vector2) != Vector2.ZERO:
		return (body_heading as Vector2).normalized()
	var velocity: Variant = actor.get("velocity")
	if velocity is Vector2 and (velocity as Vector2).length() > AXIS_SPEED_THRESHOLD_PX:
		return (velocity as Vector2).normalized()
	var aim: Variant = actor.get("last_aim_direction")
	if aim is Vector2 and (aim as Vector2) != Vector2.ZERO:
		return (aim as Vector2).normalized()
	return Vector2.RIGHT

static func region_at(actor: Node, hit_point: Vector2) -> Dictionary:
	var fallback := {"region": "hull", "region_mult": 1.0, "center": hit_point, "radius": 0.0}
	if actor == null or not is_instance_valid(actor):
		return fallback
	var data_value: Variant = actor.get("creature_data")
	if typeof(data_value) != TYPE_DICTIONARY:
		return fallback
	var creature_data: Dictionary = data_value
	var regions_value: Variant = creature_data.get("hurtbox_regions", [])
	if typeof(regions_value) != TYPE_ARRAY:
		return fallback
	var axis := body_axis(actor)
	var center: Vector2 = (actor as Node2D).global_position if actor is Node2D else Vector2.ZERO
	var best := fallback
	var best_radius := INF
	for region_value: Variant in regions_value:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		if not _region_open(actor, String(region.get("open_when", "always"))):
			continue
		var radius := maxf(0.0, _float_or(region.get("radius_units", 0.0), 0.0) * SimConstants.UNIT_PX)
		if radius <= 0.0 or radius >= best_radius:
			continue
		var region_center := center + _region_offset_px(region.get("offset_units", [0.0, 0.0]), axis)
		if hit_point.distance_to(region_center) <= radius:
			best_radius = radius
			best = {
				"region": String(region.get("name", "hull")),
				"region_mult": clampf(_float_or(region.get("mult", 1.0), 1.0), 0.75, 1.35),
				"center": region_center,
				"radius": radius
			}
	return best

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
	var entry := _first_segment_hull_entry(hull, from, to, radius)
	var entry_core := core_closest_point(hull, entry)
	var point := surface_point(hull, entry)
	var normal := (entry - entry_core).normalized() if entry.distance_to(entry_core) > 0.0001 else (from - to).normalized()
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

# Soft body separation (decision #27): penetration vector pushing `a` away
# from `b`, ZERO when the hulls don't overlap. Capsule-aware via the core
# segments; exact coincidence falls back to a deterministic axis.
static func separation_push(a: Node, b: Node) -> Vector2:
	return separation_push_hulls(hull_of(a), hull_of(b))

static func separation_push_hulls(hull_a: Dictionary, hull_b: Dictionary) -> Vector2:
	var a_core: Vector2 = core_closest_point(hull_a, hull_b.center)
	var b_core: Vector2 = core_closest_point(hull_b, a_core)
	a_core = core_closest_point(hull_a, b_core)
	var offset := a_core - b_core
	var distance := offset.length()
	var min_distance := float(hull_a.radius) + float(hull_b.radius)
	if distance >= min_distance:
		return Vector2.ZERO
	var direction := offset / distance if distance > 0.001 else Vector2.RIGHT
	return direction * (min_distance - distance)

static func _get_float(node: Node, property: String, fallback: float) -> float:
	if node == null or not is_instance_valid(node):
		return fallback
	var value: Variant = node.get(property)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback

static func _first_segment_hull_entry(hull: Dictionary, from: Vector2, to: Vector2, expanded_radius: float) -> Vector2:
	if from.distance_to(core_closest_point(hull, from)) <= expanded_radius:
		return from
	var low := 0.0
	var high := 1.0
	for _i in 18:
		var mid := (low + high) * 0.5
		var point := from.lerp(to, mid)
		if point.distance_to(core_closest_point(hull, point)) <= expanded_radius:
			high = mid
		else:
			low = mid
	return from.lerp(to, high)

static func _region_open(actor: Node, open_when: String) -> bool:
	if open_when == "always":
		return true
	if actor != null and is_instance_valid(actor) and actor.has_method("is_region_open"):
		return bool(actor.is_region_open(open_when))
	return false

static func _region_offset_px(offset_value: Variant, axis: Vector2) -> Vector2:
	var forward := 0.0
	var side := 0.0
	if typeof(offset_value) == TYPE_ARRAY:
		var offset_array: Array = offset_value
		if offset_array.size() >= 2:
			forward = _float_or(offset_array[0], 0.0)
			side = _float_or(offset_array[1], 0.0)
	elif typeof(offset_value) == TYPE_DICTIONARY:
		var offset_dict: Dictionary = offset_value
		forward = _float_or(offset_dict.get("forward", offset_dict.get("x", 0.0)), 0.0)
		side = _float_or(offset_dict.get("side", offset_dict.get("y", 0.0)), 0.0)
	var side_axis := Vector2(-axis.y, axis.x)
	return (axis * forward + side_axis * side) * SimConstants.UNIT_PX

static func _float_or(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback
