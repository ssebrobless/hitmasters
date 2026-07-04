extends RefCounted

static func instant_line(actor: Node, range_px: float, damage: float, delivery: int, plane: int, source_ability: String) -> Array:
	var hits := []
	if actor.arena == null:
		return hits
	var aim: Vector2 = actor.get_aim_direction()
	for target in actor.arena.entities:
		if target == actor or target == null or not is_instance_valid(target):
			continue
		if target.team == actor.team or not target.has_method("take_damage_event"):
			continue
		var offset: Vector2 = target.global_position - actor.global_position
		var along := offset.dot(aim)
		if along < 0.0 or along > range_px:
			continue
		var lateral := absf(offset.cross(aim))
		if lateral > target.body_radius + actor.body_radius * 0.5:
			continue
		target.take_damage_event(actor.make_damage_event(damage, delivery, plane, source_ability))
		hits.append(target)
	actor.damage_enemy_cores_line(range_px, damage, source_ability)
	return hits
