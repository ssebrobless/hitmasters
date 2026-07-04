extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const Dash := preload("res://scripts/sim/abilities/dash.gd")

class FakeArena:
	extends Node
	var entities: Array[Node] = []
	var cores := {}
	var terrain := TerrainMapScript.new()
	var vfx_events: Array[Dictionary] = []

	func _init() -> void:
		terrain.configure("3v3")

	func add_actor(actor: Node) -> void:
		add_child(actor)
		entities.append(actor)

	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)

	func get_terrain_zone(point: Vector2) -> String:
		return terrain.get_zone_at(point)

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func record_death(_victim: Node, _killer: Node = null) -> void:
		pass

	func record_vfx_event(event: Dictionary) -> void:
		vfx_events.append(event.duplicate())

func _initialize() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog != null:
		catalog.load_catalog()

	var windup_hit_ok := _check_windup_and_hit_events()
	var aura_ok := _check_aura_events()
	var latch_ok := _check_latch_events()
	var heal_ok := _check_heal_event()
	print("m2r windup_hit=%s aura=%s latch=%s heal=%s" % [str(windup_hit_ok), str(aura_ok), str(latch_ok), str(heal_ok)])
	quit(0 if windup_hit_ok and aura_ok and latch_ok and heal_ok else 1)

func _check_windup_and_hit_events() -> bool:
	var arena := _arena()
	var turtle := _creature(arena, "snapping_turtle", 0, Vector2(-220.0, 0.0))
	var target := _creature(arena, "chorus_frog", 1, Vector2(-196.0, 0.0))
	turtle.set_input_frame(_frame(Vector2.ZERO, target.global_position, InputFrameScript.BUTTON_PRIMARY))
	turtle.tick_sim(SimConstants.TICK_DELTA)
	_tick(turtle, _frame(Vector2.ZERO, target.global_position, 0), float(turtle.stats["windup_sec"]) + SimConstants.TICK_DELTA)
	return _has_event(arena, "windup_started") and _has_event(arena, "attack_swung") and _has_event(arena, "hit_landed")

func _check_aura_events() -> bool:
	var arena := _arena()
	var frog := _creature(arena, "chorus_frog", 0, Vector2(-220.0, 0.0))
	_creature(arena, "snapping_turtle", 0, Vector2(-200.0, 0.0))
	_creature(arena, "mink", 1, Vector2(-196.0, 0.0))
	frog.set_input_frame(_frame(Vector2.ZERO, Vector2.RIGHT, InputFrameScript.BUTTON_ABILITY_Q | InputFrameScript.BUTTON_ABILITY_E))
	frog.tick_sim(SimConstants.TICK_DELTA)
	return _has_event(arena, "aura_applied")

func _check_latch_events() -> bool:
	var arena := _arena()
	var mink := _creature(arena, "mink", 0, Vector2(-220.0, 0.0))
	var victim := _creature(arena, "chorus_frog", 1, Vector2(-202.0, 0.0))
	mink.set_input_frame(_frame(Vector2.ZERO, victim.global_position, InputFrameScript.BUTTON_ABILITY_Q))
	mink.tick_sim(SimConstants.TICK_DELTA)
	_tick(mink, _frame(Vector2.ZERO, victim.global_position, 0), 0.25)
	var started := _has_event(arena, "latch_started")
	Dash.start(victim, Vector2.RIGHT, 16.0, 0.1)
	victim.tick_sim(SimConstants.TICK_DELTA)
	return started and _has_event(arena, "latch_ended")

func _check_heal_event() -> bool:
	var arena := _arena()
	var mink := _creature(arena, "mink", 0, Vector2(-220.0, 0.0))
	var victim := _creature(arena, "chorus_frog", 1, Vector2(-210.0, 0.0))
	mink.health = mink.max_health * 0.5
	mink.on_kill(victim)
	_tick(mink, _frame(Vector2.ZERO, Vector2.RIGHT, 0), SimConstants.TICK_DELTA * 2.0)
	return _has_event(arena, "heal_tick")

func _has_event(arena: FakeArena, event_type: String) -> bool:
	for event in arena.vfx_events:
		if String(event.get("type", "")) == event_type:
			return true
	return false

func _arena() -> FakeArena:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	return arena

func _creature(arena: FakeArena, creature_id: String, team: int, position: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_actor(creature)
	creature.setup(arena, team, position, creature_id, arena.terrain)
	return creature

func _frame(move: Vector2, aim: Vector2, buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = move
	frame.aim = aim
	frame.buttons = buttons
	return frame

func _tick(creature: Node, frame: Resource, seconds: float) -> void:
	var ticks := int(ceil(seconds / SimConstants.TICK_DELTA))
	for _i in range(ticks):
		creature.set_input_frame(frame)
		creature.tick_sim(SimConstants.TICK_DELTA)
