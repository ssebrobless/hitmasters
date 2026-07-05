extends RefCounted

const HitShape := preload("res://scripts/sim/combat/hit_shape.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

static func hit(actor: Node, reach_px: float, damage: float, delivery: int, plane: int, source_ability: String, opts: Dictionary = {}) -> Array:
	var hits := []
	if actor.arena == null:
		return hits
	var shape := HitShape.melee_arc(actor, reach_px)
	if actor.has_method("emit_vfx_event"):
		var payload := shape.duplicate()
		payload.merge({
			"actor": actor,
			"position": actor.global_position,
			"source_ability": source_ability
		})
		actor.emit_vfx_event("attack_swung", payload)
	var max_hits := int(opts.get("max_hits", 0))
	for target in actor.arena.entities:
		if not TargetFilter.is_live_blind_damage_target(actor, target):
			continue
		if not HitShape.overlaps_melee_arc(shape, target):
			continue
		target.take_damage_event(actor.make_damage_event(damage, delivery, plane, source_ability))
		hits.append(target)
		if max_hits > 0 and hits.size() >= max_hits:
			break
	actor.damage_enemy_cores_near(shape.get("center", actor.global_position), reach_px, damage, source_ability)
	return hits
