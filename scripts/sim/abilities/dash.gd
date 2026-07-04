extends RefCounted

static func start(actor: Node, direction: Vector2, distance_px: float, duration: float) -> void:
	if direction == Vector2.ZERO:
		return
	actor.break_latch("displacement")
	actor.dash_velocity = direction.normalized() * (distance_px / maxf(duration, 0.01))
	actor.dash_timer = duration

