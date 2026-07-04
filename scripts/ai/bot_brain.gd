extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TurtleHook := preload("res://scripts/ai/bot_kit_hooks/snapping_turtle_bot.gd")
const FrogHook := preload("res://scripts/ai/bot_kit_hooks/chorus_frog_bot.gd")
const MinkHook := preload("res://scripts/ai/bot_kit_hooks/mink_bot.gd")
const BeaverHook := preload("res://scripts/ai/bot_kit_hooks/beaver_bot.gd")
const OwlHook := preload("res://scripts/ai/bot_kit_hooks/owl_bot.gd")
const DuckHook := preload("res://scripts/ai/bot_kit_hooks/duck_bot.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const FIGHT_SCAN_RANGE := 620.0
const RETREAT_HEALTH_RATIO := 0.28
const RETREAT_THREAT_RANGE := 360.0
const DEFEND_HUT_RADIUS := 430.0
const DEFEND_ACTOR_RANGE := 980.0

var hooks := {}

func build_frame(actor: Node) -> Resource:
	var frame := InputFrameScript.new()
	if actor == null or actor.arena == null:
		frame.move = Vector2.ZERO
		return frame

	var intent := _choose_intent(actor)
	var target: Node = intent.get("target", null)
	var point: Vector2 = intent.get("point", actor.global_position + Vector2.RIGHT)
	var mode := String(intent.get("mode", "idle"))
	var target_position: Vector2 = target.global_position if _valid_target(target) else point
	if mode == "retreat":
		target_position = point
	if target_position == actor.global_position:
		target_position += Vector2.RIGHT

	var offset: Vector2 = target_position - actor.global_position
	var distance: float = offset.length()
	var direction: Vector2 = offset.normalized() if distance > 0.001 else Vector2.RIGHT
	frame.aim = _aim_point(actor, target, target_position, mode)

	if mode == "retreat":
		frame.move = direction
		return frame

	var hold_range: float = _preferred_range(actor) + _target_radius(target)
	frame.move = direction if distance > hold_range else _strafe_direction(direction, actor.team)
	if _valid_target(target):
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, distance <= _primary_range(actor, target))
		_hook(actor).apply(actor, target, frame, distance)
	return frame

func _choose_intent(actor: Node) -> Dictionary:
	var close_threat: Node = _closest_live_enemy(actor, RETREAT_THREAT_RANGE)
	if _health_ratio(actor) <= RETREAT_HEALTH_RATIO and close_threat != null:
		return {
			"mode": "retreat",
			"target": close_threat,
			"point": _retreat_point(actor)
		}

	var defense: Dictionary = _defense_intent(actor)
	if not defense.is_empty():
		return defense

	var objective: Node = _objective_target(actor)
	var enemy: Node = _closest_live_enemy(actor, FIGHT_SCAN_RANGE)
	if enemy != null and not _is_hut(actor, enemy):
		return {"mode": "fight", "target": enemy}

	if objective != null:
		return {"mode": "objective", "target": objective}

	if enemy != null:
		return {"mode": "fight", "target": enemy}

	return {"mode": "idle", "point": actor.global_position + Vector2.RIGHT}

func _defense_intent(actor: Node) -> Dictionary:
	if actor.arena.get("huts") == null:
		return {}
	var best_enemy: Node = null
	var best_hut: Node = null
	var best_score: float = INF
	for hut in actor.arena.huts:
		if not _valid_target(hut) or hut.team != actor.team:
			continue
		var enemy: Node = _closest_enemy_near_point(actor, hut.global_position, DEFEND_HUT_RADIUS)
		if enemy == null:
			continue
		var distance_to_hut: float = actor.global_position.distance_to(hut.global_position)
		if distance_to_hut > DEFEND_ACTOR_RANGE:
			continue
		var hut_ratio: float = _health_ratio(hut)
		var score: float = distance_to_hut + hut_ratio * 220.0
		if score < best_score:
			best_score = score
			best_hut = hut
			best_enemy = enemy
	if best_enemy != null:
		return {
			"mode": "defend",
			"target": best_enemy,
			"point": best_hut.global_position
		}
	return {}

func _objective_target(actor: Node) -> Node:
	var core: Node = actor.arena.get_enemy_core(actor.team) if actor.arena.has_method("get_enemy_core") else null
	if core != null and (not actor.arena.has_method("can_damage_core") or actor.arena.can_damage_core(core.team)):
		return core

	var hut: Node = _best_enemy_hut(actor)
	if hut != null:
		return hut
	return core

func _best_enemy_hut(actor: Node) -> Node:
	if actor.arena.get("huts") == null:
		return null
	var best_hut: Node = null
	var best_score: float = INF
	for hut in actor.arena.huts:
		if not _valid_target(hut) or hut.team == actor.team:
			continue
		var distance: float = actor.global_position.distance_to(hut.global_position)
		var score: float = distance + _health_ratio(hut) * 320.0
		if score < best_score:
			best_score = score
			best_hut = hut
	return best_hut

func _closest_enemy_near_point(actor: Node, point: Vector2, radius: float) -> Node:
	var closest: Node = null
	var closest_distance: float = radius
	for entity in actor.arena.entities:
		if not TargetFilter.is_live_damage_target(actor, entity, {"require_damage_api": false}):
			continue
		var distance: float = entity.global_position.distance_to(point)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _closest_live_enemy(actor: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance: float = max_distance
	if actor.arena == null:
		return null
	if _has_property(actor.arena, "entities"):
		for entity in actor.arena.entities:
			if not TargetFilter.is_live_damage_target(actor, entity, {"require_damage_api": false}):
				continue
			var distance: float = actor.global_position.distance_to(entity.global_position)
			if distance < closest_distance:
				closest = entity
				closest_distance = distance
		return closest
	if actor.arena.has_method("get_closest_enemy"):
		var candidate: Node = actor.arena.get_closest_enemy(actor, max_distance)
		if TargetFilter.is_live_damage_target(actor, candidate, {"require_damage_api": false}):
			return candidate
	return null

func _retreat_point(actor: Node) -> Vector2:
	var best_point: Vector2 = actor.global_position
	var best_distance: float = INF
	if actor.arena.has_method("get_team_spawn"):
		best_point = actor.arena.get_team_spawn(actor.team)
	for hut in actor.arena.huts if actor.arena.get("huts") != null else []:
		if not _valid_target(hut) or hut.team != actor.team:
			continue
		var distance: float = actor.global_position.distance_to(hut.global_position)
		if distance < best_distance:
			best_distance = distance
			best_point = hut.global_position
	return best_point

func _aim_point(actor: Node, target: Node, fallback: Vector2, mode: String) -> Vector2:
	if mode == "retreat" and _valid_target(target):
		return target.global_position
	return fallback

func _valid_target(target: Node) -> bool:
	return TargetFilter.is_live_damage_target(null, target, {
		"ignore_team": true,
		"require_damage_api": false,
		"allow_self": true,
		"allow_stealthed": true
	})

func _health_ratio(target: Node) -> float:
	var max_health := float(target.max_health)
	if max_health <= 0.0:
		return 1.0
	var health := float(target.health)
	return clampf(health / max_health, 0.0, 1.0)

func _target_radius(target: Node) -> float:
	if not _valid_target(target):
		return 0.0
	if _has_property(target, "body_radius"):
		return float(target.body_radius)
	if _has_property(target, "radius"):
		return float(target.radius)
	return 0.0

func _is_hut(actor: Node, target: Node) -> bool:
	if actor.arena.get("huts") == null:
		return false
	return actor.arena.huts.has(target)

func _has_property(target: Object, property_name: String) -> bool:
	for property: Dictionary in target.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false

func _strafe_direction(direction: Vector2, team: int) -> Vector2:
	return Vector2(-direction.y, direction.x) * (1.0 if team == 0 else -1.0)

func _hook(actor: Node) -> RefCounted:
	if hooks.has(actor.creature_id):
		return hooks[actor.creature_id]
	var hook: RefCounted
	match actor.creature_id:
		"snapping_turtle":
			hook = TurtleHook.new()
		"chorus_frog":
			hook = FrogHook.new()
		"mink":
			hook = MinkHook.new()
		"beaver":
			hook = BeaverHook.new()
		"owl":
			hook = OwlHook.new()
		"duck":
			hook = DuckHook.new()
		_:
			hook = FrogHook.new()
	hooks[actor.creature_id] = hook
	return hook

func _preferred_range(actor: Node) -> float:
	match actor.creature_id:
		"chorus_frog":
			return 46.0
		"snapping_turtle":
			return 24.0
		"mink":
			return 18.0
		"beaver":
			return 22.0
		"owl":
			return 60.0
		"duck":
			return 20.0
		_:
			return 32.0

func _primary_range(actor: Node, target: Node) -> float:
	return _preferred_range(actor) + actor.body_radius * 1.5 + _target_radius(target)
