extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

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

	var turtle := CreatureScript.new()
	root.add_child(turtle)
	turtle.setup(null, 0, Vector2.ZERO, "snapping_turtle", terrain)
	var turtle_ground_speed: float = turtle._speed_px_for_ground()
	var turtle_water_speed: float = turtle.get_speed_px()
	var turtle_start_hp: float = turtle.health
	_tick_creature(turtle, _frame(Vector2.ZERO, false), delta, turtle.swim_time_max + 1.0)
	var turtle_loss: float = turtle_start_hp - turtle.health

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

	var water_boost_ratio := turtle_water_speed / turtle_ground_speed
	var bullfrog_took_dot := bullfrog_loss > bullfrog_start_hp * 0.1
	var turtle_boosted := absf(water_boost_ratio - 1.15) < 0.001
	var turtle_drowned_after_timer := turtle.swim_time_remaining <= 0.0 and turtle_loss > 0.0
	var passed := bullfrog_took_dot and turtle_boosted and turtle_drowned_after_timer and took_off and grounded_by_depletion and stayed_grounded

	print("land_walker_dot_loss=%.2f semi_water_speed_ratio=%.3f semi_swim_remaining=%.2f semi_dot_loss=%.2f owl_took_off=%s takeoff_seconds=%.2f owl_grounded_timer=%.2f stayed_grounded=%s" % [
		bullfrog_loss,
		water_boost_ratio,
		turtle.swim_time_remaining,
		turtle_loss,
		str(took_off),
		takeoff_seconds,
		owl.flight_grounded_timer,
		str(stayed_grounded)
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
