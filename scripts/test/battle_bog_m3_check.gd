extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const DamScript := preload("res://scripts/game/dam.gd")
const DucklingScript := preload("res://scripts/sim/pets/duckling.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

class FakeArena:
	extends Node
	var entities: Array[Node] = []
	var cores := {}
	var terrain := TerrainMapScript.new()
	var cover_rects: Array = []
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

	func clamp_to_arena(point: Vector2) -> Vector2:
		return point

	func record_death(_victim: Node, _killer: Node = null) -> void:
		pass

	func record_vfx_event(event: Dictionary) -> void:
		vfx_events.append(event.duplicate())

func _initialize() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog != null:
		catalog.load_catalog()

	# Kits instantiate for all six slice creatures.
	var kits_ok := true
	for creature_id in ["snapping_turtle", "chorus_frog", "mink", "beaver", "owl", "duck"]:
		var creature := CreatureScript.new()
		root.add_child(creature)
		creature.setup(null, 0, Vector2.ZERO, creature_id)
		if creature.kit == null:
			kits_ok = false
		creature.queue_free()

	# Airborne owl dodges ground melee, but not during its low window,
	# and never dodges ranged.
	var owl := CreatureScript.new()
	root.add_child(owl)
	owl.setup(null, 0, Vector2.ZERO, "owl")
	owl.state = CreatureStateScript.State.AIRBORNE
	var ground_melee := DamageEventScript.new()
	ground_melee.setup(50.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, null, "Bite")
	owl.take_damage_event(ground_melee)
	var dodged := owl.health == owl.max_health
	var ranged := DamageEventScript.new()
	ranged.setup(30.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, null, "Shot")
	owl.take_damage_event(ranged)
	var ranged_hit := owl.health < owl.max_health
	owl.heal(1000.0)
	owl.open_low_window(0.7)
	owl.take_damage_event(ground_melee)
	var low_window_hit := owl.health < owl.max_health

	# Spike rule: heavy ranged hit grounds a flying bird with lockout.
	owl.heal(1000.0)
	owl.state = CreatureStateScript.State.AIRBORNE
	owl.flight_grounded_timer = 0.0
	var spike := DamageEventScript.new()
	spike.setup(35.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, null, "Heavy Shot")
	owl.take_damage_event(spike)
	var spiked: bool = owl.state == CreatureStateScript.State.NORMAL and owl.flight_grounded_timer > 2.9
	owl.heal(1000.0)
	owl.state = CreatureStateScript.State.AIRBORNE
	owl.flight_grounded_timer = 0.0
	var light := DamageEventScript.new()
	light.setup(15.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, null, "Light Shot")
	owl.take_damage_event(light)
	var light_no_spike: bool = owl.state == CreatureStateScript.State.AIRBORNE

	# Stealth set/break.
	owl.begin_stealth(10.0, "Silent Flight")
	var stealth_on := owl.is_stealthed()
	owl.break_stealth()
	var stealth_off := not owl.is_stealthed()

	# Perch pauses flight drain.
	owl.state = CreatureStateScript.State.PERCHED
	var flight_before := owl.flight_time_remaining
	owl.tick_sim(1.0)
	var perch_pause: bool = absf(owl.flight_time_remaining - flight_before) < 0.01

	# Dam takes damage and reports rect.
	var dam := DamScript.new()
	root.add_child(dam)
	dam.setup(null, 0, Rect2(Vector2(-24, -8), Vector2(48, 16)), 200.0)
	dam.take_damage(50.0)
	var dam_ok: bool = dam.health == 150.0 and dam.rect.size.x == 48.0

	# Duckling lives and dies.
	var duckling := DucklingScript.new()
	root.add_child(duckling)
	duckling.setup(null, null, 0, Vector2.ZERO, 0, 80.0)
	duckling.take_damage(30.0)
	var duckling_ok: bool = duckling.is_alive() and duckling.health == 50.0

	var beaver_gnawing_ok := _check_beaver_gnawing()
	var owl_perch_anchor_ok := _check_owl_perch_anchors()

	var passed := kits_ok and dodged and ranged_hit and low_window_hit and stealth_on and stealth_off and perch_pause and dam_ok and duckling_ok and spiked and light_no_spike and beaver_gnawing_ok and owl_perch_anchor_ok
	print("m3 kits=%s dodge=%s ranged_hit=%s low_window=%s stealth=%s/%s perch_pause=%s dam=%s duckling=%s spike=%s/%s beaver_gnawing=%s owl_perch_anchor=%s" % [
		str(kits_ok), str(dodged), str(ranged_hit), str(low_window_hit), str(stealth_on), str(stealth_off), str(perch_pause), str(dam_ok), str(duckling_ok), str(spiked), str(light_no_spike), str(beaver_gnawing_ok), str(owl_perch_anchor_ok)
	])
	quit(0 if passed else 1)

func _check_beaver_gnawing() -> bool:
	var near_arena := FakeArena.new()
	root.add_child(near_arena)
	near_arena.cover_rects = [Rect2(Vector2(12.0, -14.0), Vector2(24.0, 28.0))]
	var beaver := _arena_creature(near_arena, "beaver", Vector2.ZERO)
	beaver.health = beaver.max_health - 100.0
	var before_near: float = beaver.health
	beaver.set_input_frame(_frame(Vector2.ZERO, Vector2(100.0, 0.0), InputFrameScript.BUTTON_PRIMARY))
	beaver.tick_sim(SimConstants.TICK_DELTA)
	var expected_near: float = before_near + beaver.max_health * 0.05
	var healed_near: bool = absf(beaver.health - expected_near) < 0.1
	var feedback_near := _has_event(near_arena, "heal_tick")

	var far_arena := FakeArena.new()
	root.add_child(far_arena)
	far_arena.cover_rects = [Rect2(Vector2(160.0, -14.0), Vector2(24.0, 28.0))]
	var far_beaver := _arena_creature(far_arena, "beaver", Vector2.ZERO)
	far_beaver.health = far_beaver.max_health - 100.0
	var before_far: float = far_beaver.health
	far_beaver.set_input_frame(_frame(Vector2.ZERO, Vector2(100.0, 0.0), InputFrameScript.BUTTON_PRIMARY))
	far_beaver.tick_sim(SimConstants.TICK_DELTA)
	var no_far_heal: bool = absf(far_beaver.health - before_far) < 0.1
	return healed_near and feedback_near and no_far_heal

func _check_owl_perch_anchors() -> bool:
	var arena := FakeArena.new()
	root.add_child(arena)
	var anchors := arena.terrain.get_perch_anchors()
	var cover_rects := arena.terrain.get_cover_rects()
	if anchors.is_empty() or cover_rects.is_empty():
		return false
	var anchor: Vector2 = anchors[0]
	var near_owl := _arena_creature(arena, "owl", anchor + Vector2(8.0, 0.0))
	near_owl.state = CreatureStateScript.State.AIRBORNE
	near_owl.set_input_frame(_frame(Vector2.ZERO, anchor, InputFrameScript.BUTTON_CONTEXT_ACTION))
	near_owl.tick_sim(SimConstants.TICK_DELTA)
	var snapped_to_anchor: bool = near_owl.state == CreatureStateScript.State.PERCHED and near_owl.global_position.distance_to(anchor) < 0.001
	near_owl.set_input_frame(_frame(Vector2.ZERO, anchor, 0))
	near_owl.tick_sim(SimConstants.TICK_DELTA)
	near_owl.set_input_frame(_frame(Vector2.ZERO, anchor, InputFrameScript.BUTTON_CONTEXT_ACTION))
	near_owl.tick_sim(SimConstants.TICK_DELTA)
	var unperched_on_next_edge: bool = near_owl.state == CreatureStateScript.State.AIRBORNE

	var cover_corner: Vector2 = cover_rects[0].position + Vector2(0.5, 0.5) * SimConstants.UNIT_PX
	var far_owl := _arena_creature(arena, "owl", cover_corner)
	far_owl.state = CreatureStateScript.State.AIRBORNE
	far_owl.set_input_frame(_frame(Vector2.ZERO, cover_corner + Vector2.RIGHT, InputFrameScript.BUTTON_CONTEXT_ACTION))
	far_owl.tick_sim(SimConstants.TICK_DELTA)
	var ignored_far_cover: bool = far_owl.state == CreatureStateScript.State.AIRBORNE and far_owl.global_position.distance_to(cover_corner) < 0.001
	return snapped_to_anchor and unperched_on_next_edge and ignored_far_cover

func _arena_creature(arena: FakeArena, creature_id: String, position: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_actor(creature)
	creature.setup(arena, 0, position, creature_id, arena.terrain)
	return creature

func _frame(move: Vector2, aim: Vector2, buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = move
	frame.aim = aim
	frame.buttons = buttons
	return frame

func _has_event(arena: FakeArena, event_type: String) -> bool:
	for event in arena.vfx_events:
		if String(event.get("type", "")) == event_type:
			return true
	return false
