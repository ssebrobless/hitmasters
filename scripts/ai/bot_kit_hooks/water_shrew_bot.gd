extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.q_timer <= 0.0 and (actor.get_current_zone() == TerrainMapScript.WATER or distance > actor.body_radius * 8.0):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_charges > 0 and distance <= actor.body_radius * 6.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
