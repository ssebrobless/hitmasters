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

func _initialize() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog != null:
		catalog.load_catalog()

	var windup_ok := _check_windup()
	var aura_ok := _check_auras()
	var latch_ok := _check_latch()
	var heal_ok := _check_kill_heal()
	var dr_ok := _check_dr()
	print("windup=%s aura=%s latch=%s kill_heal=%s dr=%s" % [str(windup_ok), str(aura_ok), str(latch_ok), str(heal_ok), str(dr_ok)])
	quit(0 if windup_ok and aura_ok and latch_ok and heal_ok and dr_ok else 1)

func _check_windup() -> bool:
	var arena := _arena()
	var turtle := _creature(arena, "snapping_turtle", 0, Vector2(-220.0, 0.0))
	var target := _creature(arena, "chorus_frog", 1, Vector2(-196.0, 0.0))
	turtle.set_input_frame(_frame(Vector2.ZERO, target.global_position, InputFrameScript.BUTTON_PRIMARY))
	turtle.tick_sim(SimConstants.TICK_DELTA)
	var immediate_hp: float = target.health
	_tick(turtle, _frame(Vector2.ZERO, target.global_position, 0), float(turtle.stats["windup_sec"]) - SimConstants.TICK_DELTA * 2.0)
	var before_land_hp: float = target.health
	_tick(turtle, _frame(Vector2.ZERO, target.global_position, 0), SimConstants.TICK_DELTA * 3.0)
	return immediate_hp == target.max_health and before_land_hp == target.max_health and target.health < target.max_health

func _check_auras() -> bool:
	var arena := _arena()
	var frog := _creature(arena, "chorus_frog", 0, Vector2(-220.0, 0.0))
	var ally := _creature(arena, "snapping_turtle", 0, Vector2(-200.0, 0.0))
	var enemy := _creature(arena, "mink", 1, Vector2(-196.0, 0.0))
	frog.set_input_frame(_frame(Vector2.ZERO, enemy.global_position, InputFrameScript.BUTTON_ABILITY_Q | InputFrameScript.BUTTON_ABILITY_E))
	frog.tick_sim(SimConstants.TICK_DELTA)
	var ally_speed: float = ally.get_modifier_value("move_speed_mult", 1.0)
	var ally_attack: float = ally.get_modifier_value("attack_speed_mult", 1.0)
	var enemy_damage: float = enemy.get_modifier_value("damage_dealt_mult", 1.0)
	var enemy_speed: float = enemy.get_modifier_value("move_speed_mult", 1.0)
	return absf(ally_speed - 1.1) < 0.001 and absf(ally_attack - 1.1) < 0.001 and absf(enemy_damage - 0.9) < 0.001 and absf(enemy_speed - 0.9) < 0.001

func _check_latch() -> bool:
	var arena := _arena()
	var mink := _creature(arena, "mink", 0, Vector2(-220.0, 0.0))
	var victim := _creature(arena, "chorus_frog", 1, Vector2(-202.0, 0.0))
	mink.set_input_frame(_frame(Vector2.ZERO, victim.global_position, InputFrameScript.BUTTON_ABILITY_Q))
	mink.tick_sim(SimConstants.TICK_DELTA)
	_tick(mink, _frame(Vector2.ZERO, victim.global_position, 0), 0.25)
	var latched: bool = mink.latch_victim == victim and victim.latched_attacker == mink
	var victim_start: Vector2 = victim.global_position
	_tick(victim, _frame(Vector2.RIGHT, mink.global_position, 0), 0.25)
	var victim_moved: bool = victim.global_position.distance_to(victim_start) > 1.0
	Dash.start(victim, Vector2.RIGHT, 16.0, 0.1)
	victim.tick_sim(SimConstants.TICK_DELTA)
	var broke := mink.latch_victim == null and victim.latched_attacker == null
	return latched and victim_moved and broke

func _check_kill_heal() -> bool:
	var arena := _arena()
	var mink := _creature(arena, "mink", 0, Vector2(-220.0, 0.0))
	var victim := _creature(arena, "chorus_frog", 1, Vector2(-210.0, 0.0))
	mink.health = mink.max_health * 0.5
	var before: float = mink.health
	mink.on_kill(victim)
	_tick(mink, _frame(Vector2.ZERO, Vector2.RIGHT, 0), 2.0)
	var expected: float = before + mink.max_health * 0.05
	return absf(mink.health - expected) < 0.1

func _check_dr() -> bool:
	var arena := _arena()
	var turtle := _creature(arena, "snapping_turtle", 0, Vector2(-220.0, 0.0))
	var mink := _creature(arena, "mink", 1, Vector2(-210.0, 0.0))
	var before_turtle: float = turtle.health
	turtle.add_modifier("test", {"damage_taken_mult": 0.9}, 1.0)
	turtle.take_damage_event(mink.make_damage_event(100.0, preload("res://scripts/sim/damage_event.gd").DELIVERY_MELEE, preload("res://scripts/sim/damage_event.gd").PLANE_GROUND, "test"))
	var turtle_loss: float = before_turtle - turtle.health
	var before_mink: float = mink.health
	mink.take_damage_event(turtle.make_damage_event(100.0, preload("res://scripts/sim/damage_event.gd").DELIVERY_MELEE, preload("res://scripts/sim/damage_event.gd").PLANE_GROUND, "test"))
	var mink_loss: float = before_mink - mink.health
	return absf(turtle_loss - 76.5) < 0.1 and absf(mink_loss - 85.0) < 0.1

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
