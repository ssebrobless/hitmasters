extends RefCounted

var max_charges := 0
var charges := 0
var recharge_seconds := 0.0
var recharge_timer := 0.0

func setup(next_max_charges: int, next_recharge_seconds: float) -> void:
	max_charges = next_max_charges
	charges = max_charges
	recharge_seconds = next_recharge_seconds
	recharge_timer = 0.0

func tick(delta: float) -> void:
	if charges >= max_charges or max_charges <= 0:
		return
	recharge_timer = maxf(recharge_timer - delta, 0.0)
	if recharge_timer <= 0.0:
		charges += 1
		if charges < max_charges:
			recharge_timer = recharge_seconds

func can_spend() -> bool:
	return charges > 0

func spend() -> bool:
	if charges <= 0:
		return false
	charges -= 1
	if charges < max_charges and recharge_timer <= 0.0:
		recharge_timer = recharge_seconds
	return true

