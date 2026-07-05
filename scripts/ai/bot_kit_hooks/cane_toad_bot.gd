extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.q_timer <= 0.0 and distance <= actor.body_radius * 5.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and (distance <= actor.body_radius * 4.0 or float(actor.health) <= float(actor.max_health) * 0.35):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
