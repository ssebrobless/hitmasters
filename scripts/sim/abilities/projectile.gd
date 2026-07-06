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
	if int(plane) == 0 and bool(opts.get("allow_harvest", true)) and actor.arena.has_method("try_harvest_food_with_hit_shape"):
		actor.arena.try_harvest_food_with_hit_shape(actor, shape, source_ability)
	var target_opts := {"allow_wildlife": bool(opts.get("allow_wildlife", true))}
	for target in actor.arena.entities:
		if not TargetFilter.is_live_blind_damage_target(actor, target, target_opts):
			continue
		var hit_info := HitShape.line_hit(shape, target)
		if not bool(hit_info.hit):
			continue
		var event: Resource = actor.make_damage_event(damage, delivery, plane, source_ability)
		event.set_hit(hit_info.point, hit_info.normal, String(hit_info.get("region", "hull")), float(hit_info.get("region_mult", 1.0)))
		target.take_damage_event(event)
		hits.append(target)
	actor.damage_enemy_cores_line(range_px, damage, source_ability)
	return hits
