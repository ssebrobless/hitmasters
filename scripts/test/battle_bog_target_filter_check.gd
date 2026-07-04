extends SceneTree

const Aura := preload("res://scripts/sim/abilities/aura.gd")
const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Projectile := preload("res://scripts/sim/abilities/projectile.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

class FakeEntity extends Node2D:
	var team := 0
	var health := 100.0
	var max_health := 100.0
	var body_radius := 10.0
	var creature_id := "chorus_frog"
	var q_timer := 10.0
	var e_timer := 10.0
	var primary_timer := 10.0
	var arena: Node = null
	var damage_events := 0
	var modifiers: Array[Dictionary] = []
	var stealthed := false

	func is_alive() -> bool:
		return health > 0.0

	func is_stealthed() -> bool:
		return stealthed

	func take_damage_event(event: Resource) -> void:
		damage_events += 1
		health = maxf(health - float(event.amount), 0.0)

	func add_modifier(source: String, values: Dictionary, duration: float) -> void:
		modifiers.append({"source": source, "values": values, "duration": duration})

	func get_aim_direction() -> Vector2:
		return Vector2.RIGHT

	func make_damage_event(amount: float, delivery: int, plane: int, source_ability: String) -> Resource:
		var event := DamageEventScript.new()
		event.setup(amount, delivery, plane, self, source_ability)
		return event

	func emit_vfx_event(_event_type: String, _payload: Dictionary = {}) -> void:
		pass

	func damage_enemy_cores_near(_center: Vector2, _reach_px: float, _damage: float, _source_ability: String) -> void:
		pass

	func damage_enemy_cores_line(_range_px: float, _damage: float, _source_ability: String) -> void:
		pass

class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var huts: Array[Node] = []
	var cores := {}

	func add_entity(entity: FakeEntity) -> FakeEntity:
		add_child(entity)
		entity.arena = self
		entities.append(entity)
		return entity

	func get_enemy_core(_team: int) -> Node:
		return null

	func can_damage_core(_defending_team: int) -> bool:
		return false

	func get_team_spawn(team: int) -> Vector2:
		return Vector2(-200.0 if team == 0 else 200.0, 0.0)

func _initialize() -> void:
	var failures: Array[String] = []
	var direct_ok := _check_direct_filter(failures)
	var melee_ok := _check_melee_skips_dead(failures)
	var line_ok := _check_line_skips_dead(failures)
	var aura_ok := _check_aura_skips_dead(failures)
	var bot_ok := _check_bot_skips_dead_targets(failures)
	var passed := direct_ok and melee_ok and line_ok and aura_ok and bot_ok
	print("target_filter direct=%s melee=%s line=%s aura=%s bot=%s" % [
		str(direct_ok),
		str(melee_ok),
		str(line_ok),
		str(aura_ok),
		str(bot_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_direct_filter(failures: Array[String]) -> bool:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO))
	var live_enemy := arena.add_entity(_entity(1, Vector2(20.0, 0.0)))
	var dead_enemy := arena.add_entity(_entity(1, Vector2(24.0, 0.0), 0.0))
	var ally := arena.add_entity(_entity(0, Vector2(8.0, 0.0)))
	var stealthed := arena.add_entity(_entity(1, Vector2(28.0, 0.0)))
	stealthed.stealthed = true
	var ok: bool = TargetFilter.is_live_damage_target(actor, live_enemy)
	ok = ok and not TargetFilter.is_live_damage_target(actor, dead_enemy)
	ok = ok and not TargetFilter.is_live_damage_target(actor, ally)
	ok = ok and TargetFilter.is_live_ally_target(actor, ally, {"require_modifier_api": true})
	ok = ok and not TargetFilter.is_live_damage_target(actor, stealthed)
	if not ok:
		failures.append("direct filter expected only live visible enemies for damage and live allies for ally effects")
	return ok

func _check_melee_skips_dead(failures: Array[String]) -> bool:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO))
	var dead_enemy := arena.add_entity(_entity(1, Vector2(18.0, 0.0), 0.0))
	var live_enemy := arena.add_entity(_entity(1, Vector2(24.0, 0.0)))
	var hits := MeleeHit.hit(actor, 24.0, 10.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "test")
	var ok: bool = hits == [live_enemy] and dead_enemy.damage_events == 0 and live_enemy.damage_events == 1
	if not ok:
		failures.append("melee expected only live enemy hit; hits=%d dead_events=%d live_events=%d" % [
			hits.size(),
			dead_enemy.damage_events,
			live_enemy.damage_events
		])
	return ok

func _check_line_skips_dead(failures: Array[String]) -> bool:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO))
	var dead_enemy := arena.add_entity(_entity(1, Vector2(30.0, 0.0), 0.0))
	var live_enemy := arena.add_entity(_entity(1, Vector2(60.0, 0.0)))
	var hits := Projectile.instant_line(actor, 80.0, 10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "test")
	var ok: bool = hits == [live_enemy] and dead_enemy.damage_events == 0 and live_enemy.damage_events == 1
	if not ok:
		failures.append("line expected only live enemy hit; hits=%d dead_events=%d live_events=%d" % [
			hits.size(),
			dead_enemy.damage_events,
			live_enemy.damage_events
		])
	return ok

func _check_aura_skips_dead(failures: Array[String]) -> bool:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO))
	var live_ally := arena.add_entity(_entity(0, Vector2(16.0, 0.0)))
	var dead_ally := arena.add_entity(_entity(0, Vector2(20.0, 0.0), 0.0))
	var live_enemy := arena.add_entity(_entity(1, Vector2(24.0, 0.0)))
	var dead_enemy := arena.add_entity(_entity(1, Vector2(28.0, 0.0), 0.0))
	Aura.apply(actor, 80.0, 1.0, {"move_speed_mult": 1.1}, {"damage_dealt_mult": 0.9}, "test")
	var ok: bool = live_ally.modifiers.size() == 1 and dead_ally.modifiers.is_empty()
	ok = ok and live_enemy.modifiers.size() == 1 and dead_enemy.modifiers.is_empty()
	if not ok:
		failures.append("aura expected live ally/enemy modifiers only; ally=%d dead_ally=%d enemy=%d dead_enemy=%d" % [
			live_ally.modifiers.size(),
			dead_ally.modifiers.size(),
			live_enemy.modifiers.size(),
			dead_enemy.modifiers.size()
		])
	return ok

func _check_bot_skips_dead_targets(failures: Array[String]) -> bool:
	var arena := _arena()
	var bot := arena.add_entity(_entity(0, Vector2.ZERO))
	var dead_enemy := arena.add_entity(_entity(1, Vector2(30.0, 0.0), 0.0))
	var live_enemy := arena.add_entity(_entity(1, Vector2(120.0, 0.0)))
	var frame := BotBrainScript.new().build_frame(bot)
	var ok: bool = frame.aim.distance_to(live_enemy.global_position) < 0.001 and dead_enemy.damage_events == 0
	if not ok:
		failures.append("bot expected aim at live enemy, not closer KO body; aim=%s live=%s" % [
			str(frame.aim),
			str(live_enemy.global_position)
		])
	return ok

func _arena() -> FakeArena:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	return arena

func _entity(team: int, position: Vector2, health := 100.0) -> FakeEntity:
	var entity := FakeEntity.new()
	entity.team = team
	entity.global_position = position
	entity.health = health
	return entity
