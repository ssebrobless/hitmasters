extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	var airborne: bool = actor.state == CreatureStateScript.State.AIRBORNE
	# Take off when grounded with meter and no immediate threat window.
	if not airborne and actor.flight_grounded_timer <= 0.0 and actor.get_flight_ratio() > 0.5:
		frame.set_button(InputFrameScript.BUTTON_FLIGHT_TOGGLE, true)
		if frame.move == Vector2.ZERO:
			frame.move = Vector2.RIGHT
	# Swoop from the air when in range; brain's default primary only fires
	# at melee range, so extend it for the aerial strike.
	if airborne:
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, distance <= 6.0 * SimConstants.UNIT_PX and actor.primary_timer <= 0.0)
		if actor.q_timer <= 0.0 and actor.get_flight_ratio() < 0.5:
			frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and distance < 12.0 * SimConstants.UNIT_PX:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
