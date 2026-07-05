extends SceneTree

const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const DamScript := preload("res://scripts/game/dam.gd")
const DuckKitScript := preload("res://scripts/sim/kits/duck.gd")
const DucklingScript := preload("res://scripts/sim/pets/duckling.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const MinkKitScript := preload("res://scripts/sim/kits/mink.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")

class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var cores := {}

	func register_entity(entity: Node) -> void:
		if not entities.has(entity):
			entities.append(entity)

	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func record_vfx_event(_event: Dictionary) -> void:
		pass

class FakeActor extends Node2D:
	var arena: Node = null
	var team := 0
	var health := 100.0
	var max_health := 100.0
	var body_radius := 10.0
	var input_frame: Resource = null
	var creature_data := {
		"abilities": [
			{"slot": "Q", "name": "Choke", "summary": "Dash 2 units; on contact deal 20 and latch to neck. If 10s countdown completes, target dies."},
			{"slot": "E", "name": "Scent Marking", "summary": "Allies in 8 units gain 15% DR and 10% damage for 4s; enemies receive 20% less healing for 4s."}
		]
	}
	var stats := {"primary_damage": 20.0, "attack_interval_sec": 1.0}
	var primary_timer := 0.0
	var q_timer := 0.0
	var e_timer := 999.0
	var dash_velocity := Vector2.ZERO
	var dash_timer := 0.0
	var latch_victim: Node = null
	var latch_source := ""
	var latch_timer := 0.0
	var latch_execute_timer := 0.0
	var latched_attacker: Node = null
	var latch_move_multiplier := 1.0
	var aim_direction := Vector2.RIGHT

	func is_alive() -> bool:
		return health > 0.0

	func can_act() -> bool:
		return true

	func is_airborne() -> bool:
		return false

	func get_aim_direction() -> Vector2:
		return aim_direction

	func get_speed_px() -> float:
		return 140.0

	func get_modifier_value(_key: String, fallback: float) -> float:
		return fallback

	func get_passive_percent(_passive_name: String, _index: int = 0, fallback: float = 0.0) -> float:
		return fallback

	func make_damage_event(amount: float, delivery: int, plane: int, source_ability: String) -> Resource:
		var event := DamageEventScript.new()
		event.setup(amount, delivery, plane, self, source_ability)
		return event

	func emit_vfx_event(_event_type: String, _payload: Dictionary = {}) -> void:
		pass

	func damage_enemy_cores_near(_center: Vector2, _radius: float, _damage: float, _source_ability: String) -> void:
		pass

	func break_latch(_reason: String) -> void:
		pass

	func attach_to_victim(victim: Node, duration: float, source_ability: String, execute_after := 0.0) -> void:
		latch_victim = victim
		latch_timer = duration
		latch_source = source_ability
		latch_execute_timer = execute_after

	func release_latch(_reason: String) -> void:
		if latch_victim != null and is_instance_valid(latch_victim):
			latch_victim.latched_attacker = null
		latch_victim = null
		latch_source = ""
		latch_timer = 0.0
		latch_execute_timer = 0.0

class FakeTarget extends Node2D:
	var team := 1
	var health := 100.0
	var max_health := 100.0
	var body_radius := 10.0
	var damage_events := 0
	var latched_attacker: Node = null
	var latch_timer := 0.0
	var latch_source := ""
	var latch_move_multiplier := 1.0

	func is_alive() -> bool:
		return health > 0.0

	func take_damage_event(event: Resource) -> void:
		damage_events += 1
		health = maxf(health - float(event.amount), 0.0)

	func receive_latch(attacker: Node, duration: float, source_ability: String) -> void:
		latched_attacker = attacker
		latch_timer = duration
		latch_source = source_ability

class FakeOwner extends Node2D:
	var team := 0
	var alive := true

	func is_alive() -> bool:
		return alive

func _initialize() -> void:
	var failures: Array[String] = []
	var choke_ok := _check_mink_choke_single_contact(failures)
	var duckling_ok := _check_duckling_retirement(failures)
	var dam_ok := _check_dam_blocker_rect_api(failures)
	var passed := choke_ok and duckling_ok and dam_ok
	print("combat_fairness choke_single=%s duckling_retire=%s dam_blocker=%s" % [
		str(choke_ok),
		str(duckling_ok),
		str(dam_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_mink_choke_single_contact(failures: Array[String]) -> bool:
	var arena := _arena()
	var mink := FakeActor.new()
	arena.add_child(mink)
	mink.arena = arena
	arena.register_entity(mink)
	var first := _target(arena, Vector2(18.0, 0.0))
	var second := _target(arena, Vector2(20.0, 2.0))
	var kit := MinkKitScript.new()
	kit.setup(mink)
	mink.input_frame = _frame(Vector2.ZERO, mink.global_position + Vector2.RIGHT * 80.0, InputFrameScript.BUTTON_ABILITY_Q)
	kit.tick(mink, SimConstants.TICK_DELTA)
	mink.input_frame = _frame(Vector2.ZERO, mink.global_position + Vector2.RIGHT * 80.0, 0)
	kit.tick(mink, SimConstants.TICK_DELTA)
	var first_after_contact: float = first.health
	var second_after_contact: float = second.health
	kit.tick(mink, SimConstants.TICK_DELTA)
	var latched: bool = mink.latch_victim == first and first.latched_attacker == mink
	var first_one_hit: bool = first.damage_events == 1 and first.health == first_after_contact and first_after_contact < first.max_health
	var second_unhit: bool = second.damage_events == 0 and second.health == second.max_health and second_after_contact == second.max_health
	var ok := latched and first_one_hit and second_unhit
	if not ok:
		failures.append("mink choke expected one contact target per dash; latched=%s first events/hp=%d/%.3f second events/hp=%d/%.3f" % [
			str(latched),
			first.damage_events,
			first.health,
			second.damage_events,
			second.health
		])
	return ok

func _check_duckling_retirement(failures: Array[String]) -> bool:
	var death_arena := _arena()
	var death_owner := _owner(death_arena)
	var death_pet := _duckling(death_arena, death_owner, Vector2(12.0, 0.0))
	death_owner.alive = false
	death_pet._physics_process(SimConstants.TICK_DELTA)
	var death_ok: bool = not death_pet.is_alive() and not death_arena.entities.has(death_pet)

	var respawn_arena := _arena()
	var respawn_owner := _owner(respawn_arena)
	var respawn_pet := _duckling(respawn_arena, respawn_owner, Vector2(12.0, 0.0))
	var duck_kit := DuckKitScript.new()
	duck_kit.ducklings.append(respawn_pet)
	duck_kit.reset_for_respawn(respawn_owner)
	var respawn_ok: bool = not respawn_pet.is_alive() and not respawn_arena.entities.has(respawn_pet) and duck_kit.ducklings.is_empty()

	var invalid_arena := _arena()
	var invalid_owner := _owner(invalid_arena)
	var invalid_pet := _duckling(invalid_arena, invalid_owner, Vector2(12.0, 0.0))
	invalid_owner.free()
	invalid_pet._physics_process(SimConstants.TICK_DELTA)
	var invalid_ok: bool = not invalid_pet.is_alive() and not invalid_arena.entities.has(invalid_pet)

	var ok := death_ok and respawn_ok and invalid_ok
	if not ok:
		failures.append("ducklings expected retire on owner death/respawn/invalidation; death=%s respawn=%s invalid=%s" % [
			str(death_ok),
			str(respawn_ok),
			str(invalid_ok)
		])
	return ok

func _check_dam_blocker_rect_api(failures: Array[String]) -> bool:
	var rect := Rect2(Vector2(-24.0, -8.0), Vector2(48.0, 16.0))
	var dam := DamScript.new()
	get_root().add_child(dam)
	dam.setup(null, 0, rect, 200.0)
	var ok: bool = dam.has_method("get_blocker_rect") and dam.get_blocker_rect() == rect
	if not ok:
		failures.append("dam expected get_blocker_rect API to return placement rect")
	return ok

func _arena() -> FakeArena:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	return arena

func _target(arena: FakeArena, position: Vector2) -> FakeTarget:
	var target := FakeTarget.new()
	arena.add_child(target)
	target.global_position = position
	arena.register_entity(target)
	return target

func _owner(arena: FakeArena) -> FakeOwner:
	var owner := FakeOwner.new()
	arena.add_child(owner)
	return owner

func _duckling(arena: FakeArena, owner: Node, position: Vector2) -> Node:
	var duckling := DucklingScript.new()
	arena.add_child(duckling)
	duckling.setup(arena, owner, owner.team if owner != null and owner.get("team") != null else 0, position, 0, 80.0)
	arena.register_entity(duckling)
	return duckling

func _frame(move: Vector2, aim: Vector2, buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = move
	frame.aim = aim
	frame.buttons = buttons
	return frame
