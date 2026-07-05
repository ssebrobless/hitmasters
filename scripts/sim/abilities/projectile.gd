extends RefCounted

const HitShape := preload("res://scripts/sim/combat/hit_shape.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

static func instant_line(actor: Node, range_px: float, damage: float, delivery: int, plane: int, source_ability: String, opts: Dictionary = {}) -> Array:
	var hits := []
	if actor.arena == null:
		return hits
	var half_width_px := float(opts.get("half_width_px", actor.body_radius * 0.5))
	var shape := HitShape.instant_line(actor, range_px, half_width_px)
	if actor.has_method("emit_vfx_event"):
		var payload := shape.duplicate()
		payload.merge({
			"actor": actor,
			"duration": 0.18,
			"source_ability": source_ability
		})
		actor.emit_vfx_event("projectile_tracer", payload)
	for target in actor.arena.entities:
		if not TargetFilter.is_live_blind_damage_target(actor, target):
			continue
		if not HitShape.overlaps_line(shape, target):
			continue
		target.take_damage_event(actor.make_damage_event(damage, delivery, plane, source_ability))
		hits.append(target)
	actor.damage_enemy_cores_line(range_px, damage, source_ability)
	return hits
