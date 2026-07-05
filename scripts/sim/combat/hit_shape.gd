extends RefCounted

const DEFAULT_MELEE_DOT_MIN := 0.15

static func melee_arc(actor: Node, reach_px: float, facing_dot_min := DEFAULT_MELEE_DOT_MIN) -> Dictionary:
	var aim := _aim_direction(actor)
	var origin := _node_position(actor)
	var actor_radius := _body_radius(actor)
	var radius := reach_px + actor_radius
	return {
		"kind": "melee_arc",
		"origin": origin,
		"position": origin,
		"center": origin + aim * reach_px,
		"aim": aim,
		"reach_px": reach_px,
		"radius": radius,
		"facing_dot_min": facing_dot_min
	}

static func instant_line(actor: Node, range_px: float, half_width_px: float) -> Dictionary:
	var aim := _aim_direction(actor)
	var origin := _node_position(actor)
	return {
		"kind": "line",
		"from": origin,
		"to": origin + aim * range_px,
		"origin": origin,
		"aim": aim,
		"range_px": range_px,
		"half_width_px": half_width_px
	}

static func overlaps_melee_arc(shape: Dictionary, target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var origin: Vector2 = shape.get("origin", Vector2.ZERO)
	var aim: Vector2 = shape.get("aim", Vector2.RIGHT)
	var to_target: Vector2 = target.global_position - origin
	if to_target.length() > float(shape.get("radius", 0.0)) + _body_radius(target):
		return false
	return to_target.normalized().dot(aim) >= float(shape.get("facing_dot_min", DEFAULT_MELEE_DOT_MIN))

static func overlaps_line(shape: Dictionary, target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var origin: Vector2 = shape.get("origin", Vector2.ZERO)
	var aim: Vector2 = shape.get("aim", Vector2.RIGHT)
	var offset: Vector2 = target.global_position - origin
	var along := offset.dot(aim)
	if along < 0.0 or along > float(shape.get("range_px", 0.0)):
		return false
	var lateral := absf(offset.cross(aim))
	return lateral <= _body_radius(target) + float(shape.get("half_width_px", 0.0))

static func _aim_direction(actor: Node) -> Vector2:
	if actor != null and is_instance_valid(actor) and actor.has_method("get_aim_direction"):
		var aim: Vector2 = actor.get_aim_direction()
		if aim != Vector2.ZERO:
			return aim.normalized()
	return Vector2.RIGHT

static func _node_position(node: Node) -> Vector2:
	if node != null and is_instance_valid(node) and node is Node2D:
		return node.global_position
	return Vector2.ZERO

static func _body_radius(node: Node) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	var value: Variant = node.get("body_radius")
	return float(value) if value != null else 0.0
