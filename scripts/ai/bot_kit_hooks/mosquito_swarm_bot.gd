extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	if actor.q_timer <= 0.0 and distance <= actor.body_radius * 12.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and actor.secondary_resource > actor.secondary_resource_max * 0.35 and _has_hurt_ally(actor):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)

func _has_hurt_ally(actor: Node) -> bool:
	if actor.arena == null:
		return false
	for entity in actor.arena.entities:
		if entity == actor or entity == null or not is_instance_valid(entity):
			continue
		if not ("team" in entity) or int(entity.team) != actor.team:
			continue
		if "health" in entity and "max_health" in entity and float(entity.health) < float(entity.max_health):
			if entity.global_position.distance_to(actor.global_position) <= actor.body_radius + entity.body_radius + 16.0:
				return true
	return false
