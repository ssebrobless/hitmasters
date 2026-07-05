extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.e_charges > 0 and distance < actor.body_radius * 7.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	if actor.q_timer <= 0.0 and distance > actor.body_radius * 7.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
