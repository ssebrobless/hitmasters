extends RefCounted

const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

static func instant_line(actor: Node, range_px: float, damage: float, delivery: int, plane: int, source_ability: String) -> Array:
	var hits := []
	if actor.arena == null:
		return hits
	var aim: Vector2 = actor.get_aim_direction()
	if actor.has_method("emit_vfx_event"):
		actor.emit_vfx_event("projectile_tracer", {
			"actor": actor,
			"from": actor.global_position,
			"to": actor.global_position + aim * range_px,
			"duration": 0.18,
			"source_ability": source_ability
		})
	for target in actor.arena.entities:
		if not TargetFilter.is_live_damage_target(actor, target):
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
