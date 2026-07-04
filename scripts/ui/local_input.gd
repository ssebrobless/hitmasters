extends Node
class_name LocalInput

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func build_frame(aim_world: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	frame.aim = aim_world
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, Input.is_action_pressed("primary"))
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, Input.is_action_pressed("ability_q"))
	frame.set_button(InputFrameScript.BUTTON_ABILITY_E, Input.is_action_pressed("ability_e"))
	frame.set_button(InputFrameScript.BUTTON_HUT_DEFEND, Input.is_action_pressed("hut_defend"))
	frame.set_button(InputFrameScript.BUTTON_HABITAT_DEPOSIT, Input.is_action_pressed("habitat_deposit"))
	frame.set_button(InputFrameScript.BUTTON_CONTEXT_ACTION, Input.is_action_pressed("context_action"))
	frame.set_button(InputFrameScript.BUTTON_FLIGHT_TOGGLE, Input.is_action_pressed("flight_toggle"))
	return frame
