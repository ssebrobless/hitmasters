extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func apply(actor: Node, target: Node, frame: Resource, distance: float) -> void:
	if actor.q_timer <= 0.0 and _near_hurt_ally(actor):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if int(actor.e_charges) > 0 and distance <= actor.body_radius * 12.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	if target != null and is_instance_valid(target):
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)

func _near_hurt_ally(actor: Node) -> bool:
	if actor.arena == null:
		return false
	for entity in actor.arena.entities:
		if entity == null or not is_instance_valid(entity) or entity == actor:
			continue
		if not ("team" in entity) or int(entity.team) != actor.team:
			continue
		if not ("health" in entity) or not ("max_health" in entity):
			continue
		if float(entity.health) < float(entity.max_health) * 0.8 and entity.global_position.distance_to(actor.global_position) <= 7.5 * 16.0:
			return true
	return false

