extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	# Nest when no enemy is close (channel requires standing still).
	if actor.q_timer <= 0.0 and distance > 14.0 * SimConstants.UNIT_PX:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
		frame.move = Vector2.ZERO
	# Mob before committing to melee.
	if actor.e_timer <= 0.0 and distance < 4.0 * SimConstants.UNIT_PX:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
