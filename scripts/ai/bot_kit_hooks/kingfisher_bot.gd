extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.e_timer <= 0.0 and float(actor.health) <= float(actor.max_health) * 0.35:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	if actor.q_timer <= 0.0 and actor.state != CreatureStateScript.State.AIRBORNE and distance > actor.body_radius * 5.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
