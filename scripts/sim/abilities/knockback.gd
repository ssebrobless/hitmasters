extends RefCounted

static func apply(source: Node, target: Node, direction: Vector2, distance_px: float, duration := 0.18) -> void:
	if target == null or not is_instance_valid(target) or direction == Vector2.ZERO:
		return
	if target.has_method("break_latch"):
		target.break_latch("knockback")
	target.dash_velocity = direction.normalized() * (distance_px / maxf(duration, 0.01))
	target.dash_timer = duration
	if source != null and source.has_method("emit_vfx_event"):
		source.emit_vfx_event("dash_started", {
			"actor": target,
			"from": target.global_position,
			"to": target.global_position + direction.normalized() * distance_px,
			"duration": duration
		})
