extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	# Tail Slap when a fight is on top of us; drop a dam at mid range.
	if actor.q_timer <= 0.0 and distance < actor.body_radius * 8.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and distance > actor.body_radius * 5.0 and distance < actor.body_radius * 12.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
