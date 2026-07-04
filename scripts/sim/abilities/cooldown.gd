extends RefCounted

var duration := 0.0
var remaining := 0.0

func setup(next_duration: float) -> void:
	duration = next_duration
	remaining = 0.0

func tick(delta: float) -> void:
	remaining = maxf(remaining - delta, 0.0)

func ready() -> bool:
	return remaining <= 0.0

func start(next_duration := -1.0) -> void:
	remaining = duration if next_duration < 0.0 else next_duration

