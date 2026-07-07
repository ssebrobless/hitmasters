extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.q_timer <= 0.0 and float(actor.health) <= float(actor.max_health) - 2.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and _is_in_water(actor) and distance < actor.body_radius * 24.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)

func _is_in_water(actor: Node) -> bool:
	if actor == null or actor.get("terrain_map") == null:
		return false
	var terrain_map: RefCounted = actor.get("terrain_map")
	return terrain_map.has_method("get_zone_at") and terrain_map.get_zone_at(actor.global_position) == TerrainMapScript.WATER
