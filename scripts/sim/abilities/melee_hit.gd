extends RefCounted

const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

static func hit(actor: Node, reach_px: float, damage: float, delivery: int, plane: int, source_ability: String) -> Array:
	var hits := []
	if actor.arena == null:
		return hits
	var aim: Vector2 = actor.get_aim_direction()
	var center: Vector2 = actor.global_position + aim * reach_px
	var radius: float = reach_px + actor.body_radius
	if actor.has_method("emit_vfx_event"):
		actor.emit_vfx_event("attack_swung", {
			"actor": actor,
			"position": actor.global_position,
			"center": center,
			"aim": aim,
			"reach_px": reach_px,
			"radius": radius,
			"source_ability": source_ability
		})
	for target in actor.arena.entities:
		if not TargetFilter.is_live_damage_target(actor, target):
			continue
		var to_target: Vector2 = target.global_position - actor.global_position
		if to_target.length() > radius + target.body_radius:
			continue
		if to_target.normalized().dot(aim) < 0.15:
			continue
		target.take_damage_event(actor.make_damage_event(damage, delivery, plane, source_ability))
		hits.append(target)
	actor.damage_enemy_cores_near(center, reach_px, damage, source_ability)
	return hits
