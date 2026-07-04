extends RefCounted

static func apply(actor: Node, radius_px: float, duration: float, ally_mods: Dictionary, enemy_mods: Dictionary, source_ability: String) -> void:
	if actor.arena == null:
		return
	for target in actor.arena.entities:
		if target == null or not is_instance_valid(target) or not target.has_method("add_modifier"):
			continue
		if target.global_position.distance_to(actor.global_position) > radius_px + target.body_radius:
			continue
		if target.team == actor.team and not ally_mods.is_empty():
			target.add_modifier(source_ability, ally_mods, duration)
			if actor.has_method("emit_vfx_event"):
				actor.emit_vfx_event("aura_applied", {
					"actor": actor,
					"target": target,
					"radius_px": radius_px,
					"duration": duration,
					"source_ability": source_ability,
					"friendly": true
				})
		elif target.team != actor.team and not enemy_mods.is_empty():
			target.add_modifier(source_ability, enemy_mods, duration)
			if actor.has_method("emit_vfx_event"):
				actor.emit_vfx_event("aura_applied", {
					"actor": actor,
					"target": target,
					"radius_px": radius_px,
					"duration": duration,
					"source_ability": source_ability,
					"friendly": false
				})
