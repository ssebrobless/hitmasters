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
		var hit_info := HitShape.melee_arc_hit(shape, target)
		if not bool(hit_info.hit):
			continue
		var event: Resource = actor.make_damage_event(damage, delivery, plane, source_ability)
		event.set_hit(hit_info.point, hit_info.normal, String(hit_info.get("region", "hull")), float(hit_info.get("region_mult", 1.0)))
		target.take_damage_event(event)
		hits.append(target)
		if max_hits > 0 and hits.size() >= max_hits:
			break
	# Thrashing (decision #33): a victim's melee always connects with its own
	# latcher, regardless of facing or arc — you can't miss what's clamped on.
	var latcher_value: Variant = actor.get("latched_attacker")
	if latcher_value is Node:
		var latcher := latcher_value as Node
		if is_instance_valid(latcher) and latcher.get("latch_victim") == actor and not hits.has(latcher) and TargetFilter.is_live_blind_damage_target(actor, latcher):
			latcher.take_damage_event(actor.make_damage_event(damage, delivery, plane, source_ability))
			hits.append(latcher)
	actor.damage_enemy_cores_near(shape.get("center", actor.global_position), reach_px, damage, source_ability)
	return hits
