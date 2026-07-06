extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.state == CreatureStateScript.State.BURROWED:
		if distance <= actor.body_radius * 8.0:
			frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
		return
	if actor.latch_victim != null:
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
		return
	if actor.q_timer <= 0.0 and distance > actor.body_radius * 5.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and actor.health <= actor.max_health * 0.8:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
