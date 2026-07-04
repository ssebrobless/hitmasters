extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

class BlockingArena:
	extends Node
	var anchor := Vector2.ZERO

	func get_terrain_zone(_point: Vector2) -> String:
		return "land"

	func resolve_body_position(_point: Vector2, _radius: float) -> Vector2:
		return anchor

func _initialize() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog != null:
		catalog.load_catalog()
	var terrain := TerrainMapScript.new()
	terrain.configure("3v3")
	var root := get_root()
	var delta := SimConstants.TICK_DELTA

	var bullfrog := CreatureScript.new()
	root.add_child(bullfrog)
	bullfrog.setup(null, 0, Vector2.ZERO, "bullfrog", terrain)
	var bullfrog_start_hp: float = bullfrog.health
	_tick_creature(bullfrog, _frame(Vector2.ZERO, false), delta, 4.0)
	var bullfrog_loss: float = bullfrog_start_hp - bullfrog.health

	var shallow_point := Vector2(12.0 * SimConstants.UNIT_PX, -13.0 * SimConstants.UNIT_PX)
	var shallow_frog := CreatureScript.new()
	root.add_child(shallow_frog)
	shallow_frog.setup(null, 0, shallow_point, "bullfrog", terrain)
	var shallow_frog_ground_speed: float = shallow_frog._speed_px_for_ground()
	var shallow_frog_speed: float = shallow_frog.get_speed_px()
	var shallow_frog_start_hp: float = shallow_frog.health
	_tick_creature(shallow_frog, _frame(Vector2.ZERO, false), delta, 4.0)
	var shallow_frog_loss: float = shallow_frog_start_hp - shallow_frog.health

	var turtle := CreatureScript.new()
	root.add_child(turtle)
	turtle.setup(null, 0, Vector2.ZERO, "snapping_turtle", terrain)
	var turtle_ground_speed: float = turtle._speed_px_for_ground()
	var turtle_water_speed: float = turtle.get_speed_px()
	var turtle_start_hp: float = turtle.health
	_tick_creature(turtle, _frame(Vector2.ZERO, false), delta, turtle.swim_time_max + 1.0)
	var turtle_loss: float = turtle_start_hp - turtle.health

	var shallow_turtle := CreatureScript.new()
	root.add_child(shallow_turtle)
	shallow_turtle.setup(null, 0, shallow_point, "snapping_turtle", terrain)
	var shallow_turtle_speed: float = shallow_turtle.get_speed_px()
	var shallow_turtle_swim_before: float = shallow_turtle.swim_time_remaining
	_tick_creature(shallow_turtle, _frame(Vector2.ZERO, false), delta, 1.0)
	var shallow_turtle_swim_safe := absf(shallow_turtle.swim_time_remaining - shallow_turtle_swim_before) < 0.001

	var mink := CreatureScript.new()
	root.add_child(mink)
	mink.setup(null, 0, Vector2(-40.0 * SimConstants.UNIT_PX, 0.0), "mink", terrain)
	var mink_ground_speed: float = mink.get_speed_px()
	mink.global_position = shallow_point
	mink.set_input_frame(_frame(Vector2.ZERO, false))
	mink.tick_sim(delta)
	var mink_first_shallow_speed: float = mink.get_speed_px()
	_tick_creature(mink, _frame(Vector2.ZERO, false), delta, 0.8)
	var mink_settled_shallow_speed: float = mink.get_speed_px()

	var owl := CreatureScript.new()
	root.add_child(owl)
	owl.setup(null, 0, Vector2(-7.0 * SimConstants.UNIT_PX, 0.0), "owl", terrain)
	var takeoff_seconds := 0.0
	while takeoff_seconds < 2.0 and not owl.is_airborne():
		owl.set_input_frame(_frame(Vector2.RIGHT, true))
		owl.tick_sim(delta)
		takeoff_seconds += delta
	var took_off := owl.is_airborne()
	_tick_creature(owl, _frame(Vector2.ZERO, false), delta, owl.flight_time_max + 0.25)
	var grounded_by_depletion := not owl.is_airborne() and owl.flight_grounded_timer > 2.6
	_tick_creature(owl, _frame(Vector2.RIGHT, true), delta, 1.0)
	var stayed_grounded := not owl.is_airborne() and owl.flight_grounded_timer > 1.5

	var blocking_arena := BlockingArena.new()
	blocking_arena.anchor = Vector2(-7.0 * SimConstants.UNIT_PX, -12.0 * SimConstants.UNIT_PX)
	root.add_child(blocking_arena)
	var blocked_owl := CreatureScript.new()
	root.add_child(blocked_owl)
	blocked_owl.setup(blocking_arena, 0, blocking_arena.anchor, "owl", terrain)
	_tick_creature(blocked_owl, _frame(Vector2.RIGHT, true), delta, 2.0)
	var blocked_takeoff_stayed_grounded := not blocked_owl.is_airborne() and blocked_owl.takeoff_distance_px < 0.1

	var water_boost_ratio := turtle_water_speed / turtle_ground_speed
	var shallow_frog_ratio := shallow_frog_speed / shallow_frog_ground_speed
	var shallow_turtle_ratio := shallow_turtle_speed / shallow_turtle._speed_px_for_ground()
	var bullfrog_took_dot := bullfrog_loss > bullfrog_start_hp * 0.1
	var shallow_frog_safe_slow := shallow_frog_loss <= 0.001 and shallow_frog_ratio < 0.95
	var turtle_boosted := absf(water_boost_ratio - 1.15) < 0.001
	var shallow_turtle_comfort := shallow_turtle_ratio > 1.02 and shallow_turtle_swim_safe
	var turtle_drowned_after_timer := turtle.swim_time_remaining <= 0.0 and turtle_loss > 0.0
	var mink_smoothing_ok := mink_first_shallow_speed < mink_ground_speed and mink_first_shallow_speed > mink_settled_shallow_speed and absf(mink_settled_shallow_speed - mink._speed_px_for_ground() * 0.92) < 0.5
	var passed := bullfrog_took_dot and shallow_frog_safe_slow and turtle_boosted and shallow_turtle_comfort and turtle_drowned_after_timer and took_off and grounded_by_depletion and stayed_grounded and blocked_takeoff_stayed_grounded and mink_smoothing_ok

	print("land_walker_dot_loss=%.2f shallow_frog_ratio=%.3f shallow_loss=%.2f semi_water_speed_ratio=%.3f shallow_turtle_ratio=%.3f shallow_swim_safe=%s semi_swim_remaining=%.2f semi_dot_loss=%.2f owl_took_off=%s takeoff_seconds=%.2f owl_grounded_timer=%.2f stayed_grounded=%s blocked_takeoff=%s mink_smoothing=%s/%.2f/%.2f" % [
		bullfrog_loss,
		shallow_frog_ratio,
		shallow_frog_loss,
		water_boost_ratio,
		shallow_turtle_ratio,
		str(shallow_turtle_swim_safe),
		turtle.swim_time_remaining,
		turtle_loss,
		str(took_off),
		takeoff_seconds,
		owl.flight_grounded_timer,
		str(stayed_grounded),
		str(blocked_takeoff_stayed_grounded),
		str(mink_smoothing_ok),
		mink_first_shallow_speed,
		mink_settled_shallow_speed
	])
	quit(0 if passed else 1)

func _tick_creature(creature: Node, frame: Resource, delta: float, seconds: float) -> void:
	var ticks := int(ceil(seconds / delta))
	for _i in range(ticks):
		creature.set_input_frame(frame)
		creature.tick_sim(delta)

func _frame(move: Vector2, flight_pressed: bool) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = move
	frame.aim = Vector2.RIGHT
	frame.set_button(InputFrameScript.BUTTON_FLIGHT_TOGGLE, flight_pressed)
	return frame
