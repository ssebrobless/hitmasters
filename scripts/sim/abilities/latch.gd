extends RefCounted

static func start(attacker: Node, victim: Node, duration: float, source_ability: String, execute_after := 0.0) -> bool:
	if attacker == null or victim == null or not is_instance_valid(victim):
		return false
	if not victim.has_method("receive_latch") or not attacker.has_method("attach_to_victim"):
		return false
	attacker.attach_to_victim(victim, duration, source_ability, execute_after)
	victim.receive_latch(attacker, duration, source_ability)
	return true

static func release(attacker: Node, reason: String) -> void:
	if attacker != null and attacker.has_method("release_latch"):
		attacker.release_latch(reason)

