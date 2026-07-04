extends RefCounted

static func start(actor: Node, direction: Vector2, distance_px: float, duration: float) -> void:
	if direction == Vector2.ZERO:
		return
	var dash_direction := direction.normalized()
	if actor.has_method("emit_vfx_event"):
		actor.emit_vfx_event("dash_started", {
			"actor": actor,
			"from": actor.global_position,
			"to": actor.global_position + dash_direction * distance_px,
			"duration": duration
		})
	actor.break_latch("displacement")
	actor.dash_velocity = dash_direction * (distance_px / maxf(duration, 0.01))
	actor.dash_timer = duration
