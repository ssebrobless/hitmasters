extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.q_charges > 0 and distance < actor.body_radius * 18.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_charges > 0 and actor.kit != null and actor.kit.get("basking_ally") != null and float(actor.health) < float(actor.max_health):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	if actor.kit != null and actor.kit.get("basking_ally") == null:
		frame.set_button(InputFrameScript.BUTTON_CONTEXT_ACTION, true)
