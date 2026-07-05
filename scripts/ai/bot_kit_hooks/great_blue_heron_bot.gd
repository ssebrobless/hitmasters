extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.q_timer <= 0.0 and _has_negative_modifier(actor):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and actor.state != CreatureStateScript.State.AIRBORNE and distance <= actor.body_radius * 9.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)

func _has_negative_modifier(actor: Node) -> bool:
	for modifier: Dictionary in actor.modifiers:
		var values: Dictionary = modifier.get("values", {})
		if values.has("can_act_mult") or values.has("ability_use_mult"):
			return true
		if values.has("move_speed_mult") and float(values["move_speed_mult"]) < 1.0:
			return true
		if values.has("damage_dealt_mult") and float(values["damage_dealt_mult"]) < 1.0:
			return true
		if values.has("damage_taken_mult") and float(values["damage_taken_mult"]) > 1.0:
			return true
	return false
