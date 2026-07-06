extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TurtleHook := preload("res://scripts/ai/bot_kit_hooks/snapping_turtle_bot.gd")
const WaterSnakeHook := preload("res://scripts/ai/bot_kit_hooks/water_snake_bot.gd")
const AlligatorHook := preload("res://scripts/ai/bot_kit_hooks/alligator_bot.gd")
const WolfSpiderHook := preload("res://scripts/ai/bot_kit_hooks/wolf_spider_bot.gd")
const FireflyHook := preload("res://scripts/ai/bot_kit_hooks/firefly_bot.gd")
const FrogHook := preload("res://scripts/ai/bot_kit_hooks/chorus_frog_bot.gd")
const NewtHook := preload("res://scripts/ai/bot_kit_hooks/newt_bot.gd")
const MinkHook := preload("res://scripts/ai/bot_kit_hooks/mink_bot.gd")
const BullfrogHook := preload("res://scripts/ai/bot_kit_hooks/bullfrog_bot.gd")
const CaneToadHook := preload("res://scripts/ai/bot_kit_hooks/cane_toad_bot.gd")
const CrayfishHook := preload("res://scripts/ai/bot_kit_hooks/crayfish_bot.gd")
const WaterShrewHook := preload("res://scripts/ai/bot_kit_hooks/water_shrew_bot.gd")
const BeaverHook := preload("res://scripts/ai/bot_kit_hooks/beaver_bot.gd")
const OwlHook := preload("res://scripts/ai/bot_kit_hooks/owl_bot.gd")
const HeronHook := preload("res://scripts/ai/bot_kit_hooks/great_blue_heron_bot.gd")
const KingfisherHook := preload("res://scripts/ai/bot_kit_hooks/kingfisher_bot.gd")
const DuckHook := preload("res://scripts/ai/bot_kit_hooks/duck_bot.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const FIGHT_SCAN_RANGE := 620.0
const RETREAT_HEALTH_RATIO := 0.28
const RETREAT_EXIT_HEALTH_RATIO := 0.42
const RETREAT_THREAT_RANGE := 360.0
const DEFEND_HUT_RADIUS := 430.0
const DEFEND_ACTOR_RANGE := 980.0
const TARGET_STICKINESS_BONUS := 60.0

var hooks := {}
var sticky_targets := {}
var retreating_actors := {}

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
		frame.move = _steered_move(actor, target_position, direction)
		return frame

	var hold_range: float = _preferred_range(actor) + _target_radius(target)
	frame.move = _steered_move(actor, target_position, direction) if distance > hold_range else _strafe_direction(direction, actor.team)
	if _valid_target(target):
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, distance <= _primary_range(actor, target))
		_hook(actor).apply(actor, target, frame, distance)
	return frame

func _choose_intent(actor: Node) -> Dictionary:
	var close_threat: Node = _closest_live_enemy(actor, RETREAT_THREAT_RANGE)
	var health_ratio := _health_ratio(actor)
	var should_retreat := close_threat != null and (
		health_ratio <= RETREAT_HEALTH_RATIO or (
			_is_retreating(actor) and health_ratio <= RETREAT_EXIT_HEALTH_RATIO
		)
	)
	if should_retreat:
		_set_retreating(actor, true)
		return {
			"mode": "retreat",
			"target": close_threat,
			"point": _retreat_point(actor)
		}
	_set_retreating(actor, false)

	var defense: Dictionary = _defense_intent(actor)
	if not defense.is_empty():
		return defense

	var target_intent := _best_target_intent(actor)
	if not target_intent.is_empty():
		return target_intent

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

func _best_target_intent(actor: Node) -> Dictionary:
	var best_target: Node = null
	var best_mode := "fight"
	var best_score := -INF
	var sticky_target := _sticky_target(actor)
	for candidate in _target_candidates(actor):
		var score := _target_candidate_score(actor, candidate, sticky_target)
		if score > best_score:
			best_score = score
			best_target = candidate
			best_mode = "objective" if _is_objective_target(actor, candidate) else "fight"
	if best_target == null:
		_set_sticky_target(actor, null)
		return {}
	_set_sticky_target(actor, best_target)
	return {"mode": best_mode, "target": best_target}

func _target_candidates(actor: Node) -> Array[Node]:
	var candidates: Array[Node] = []
	if actor.arena == null:
		return candidates
	if actor.arena.get("entities") != null:
		for entity in actor.arena.entities:
			if not TargetFilter.is_live_damage_target(actor, entity, {"require_damage_api": false}):
				continue
			var distance: float = actor.global_position.distance_to(entity.global_position)
			if not _is_hut(actor, entity) and distance > FIGHT_SCAN_RANGE:
				continue
			candidates.append(entity)
	var core := _open_enemy_core(actor)
	if core != null:
		candidates.append(core)
	return candidates

func _target_candidate_score(actor: Node, target: Node, sticky_target: Node) -> float:
	var distance: float = actor.global_position.distance_to(target.global_position)
	var missing_health := 1.0 - _health_ratio(target)
	var score := 0.0
	if _is_core(actor, target):
		score = 1500.0 - distance * 0.2 + missing_health * 120.0
	elif _is_hut(actor, target):
		score = 850.0 - distance * 0.25 + missing_health * 220.0
	elif _is_combatant_target(target):
		score = 520.0 - distance * 0.45 + missing_health * 220.0 + _target_threat_score(target)
	else:
		score = 140.0 - distance * 0.45 + missing_health * 90.0
	if target == sticky_target:
		score += TARGET_STICKINESS_BONUS
	return score

func _target_threat_score(target: Node) -> float:
	var score := 0.0
	if target.has_method("is_scored_actor") and target.is_scored_actor():
		score += 90.0
	if _has_property(target, "creature_id") and String(target.get("creature_id")) != "":
		score += 70.0
	if _has_property(target, "damage"):
		score += clampf(float(target.get("damage")) * 2.5, 0.0, 120.0)
	if _has_property(target, "attack_range"):
		score += clampf(float(target.get("attack_range")) * 0.25, 0.0, 55.0)
	if _has_property(target, "kind"):
		match String(target.get("kind")):
			"tank":
				score += 70.0
			"pebble":
				score += 60.0
			"melee":
				score += 45.0
			"lane":
				score += 35.0
			_:
				score += 25.0
	return score

func _open_enemy_core(actor: Node) -> Node:
	if actor.arena == null or not actor.arena.has_method("get_enemy_core"):
		return null
	var core: Node = actor.arena.get_enemy_core(actor.team)
	if not _valid_target(core) or not _has_property(core, "team") or int(core.get("team")) == actor.team:
		return null
	if actor.arena.has_method("can_damage_core") and not actor.arena.can_damage_core(int(core.get("team"))):
		return null
	return core

func _is_objective_target(actor: Node, target: Node) -> bool:
	return _is_hut(actor, target) or _is_core(actor, target)

func _is_core(actor: Node, target: Node) -> bool:
	if actor.arena == null or not actor.arena.has_method("get_enemy_core"):
		return false
	return target == actor.arena.get_enemy_core(actor.team)

func _is_combatant_target(target: Node) -> bool:
	if target.has_method("is_scored_actor") and target.is_scored_actor():
		return true
	if _has_property(target, "creature_id") and String(target.get("creature_id")) != "":
		return true
	return _has_property(target, "kind")

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

# PERF: O(1) `in` check — see target_filter.gd note; get_property_list()
# here cost ~110 ms per bot per tick (the 2026-07-05 unplayable-lag bug).
func _has_property(target: Object, property_name: String) -> bool:
	return property_name in target

func _sticky_target(actor: Node) -> Node:
	var key := int(actor.get_instance_id())
	var target: Node = sticky_targets.get(key, null)
	if TargetFilter.is_live_damage_target(actor, target, {"require_damage_api": false}):
		return target
	sticky_targets.erase(key)
	return null

func _set_sticky_target(actor: Node, target: Node) -> void:
	var key := int(actor.get_instance_id())
	if target == null:
		sticky_targets.erase(key)
		return
	sticky_targets[key] = target

func _is_retreating(actor: Node) -> bool:
	return bool(retreating_actors.get(int(actor.get_instance_id()), false))

func _set_retreating(actor: Node, retreating: bool) -> void:
	var key := int(actor.get_instance_id())
	if retreating:
		retreating_actors[key] = true
	else:
		retreating_actors.erase(key)

# Bots route long moves through the arena's cover-aware steering so they
# slide around walls instead of walking into them (2026-07-05 playtest fix).
func _steered_move(actor: Node, destination: Vector2, fallback: Vector2) -> Vector2:
	if actor.arena != null and actor.arena.has_method("get_steering_direction"):
		var steered: Vector2 = actor.arena.get_steering_direction(actor.global_position, destination, float(actor.body_radius), actor.team)
		if steered != Vector2.ZERO:
			return steered
	return fallback

func _strafe_direction(direction: Vector2, team: int) -> Vector2:
	return Vector2(-direction.y, direction.x) * (1.0 if team == 0 else -1.0)

func _hook(actor: Node) -> RefCounted:
	if hooks.has(actor.creature_id):
		return hooks[actor.creature_id]
	var hook: RefCounted
	match actor.creature_id:
		"snapping_turtle":
			hook = TurtleHook.new()
		"water_snake":
			hook = WaterSnakeHook.new()
		"alligator":
			hook = AlligatorHook.new()
		"wolf_spider":
			hook = WolfSpiderHook.new()
		"firefly":
			hook = FireflyHook.new()
		"chorus_frog":
			hook = FrogHook.new()
		"newt":
			hook = NewtHook.new()
		"mink":
			hook = MinkHook.new()
		"bullfrog":
			hook = BullfrogHook.new()
		"cane_toad":
			hook = CaneToadHook.new()
		"crayfish":
			hook = CrayfishHook.new()
		"water_shrew":
			hook = WaterShrewHook.new()
		"beaver":
			hook = BeaverHook.new()
		"owl":
			hook = OwlHook.new()
		"great_blue_heron":
			hook = HeronHook.new()
		"kingfisher":
			hook = KingfisherHook.new()
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
		"newt":
			return 26.0
		"snapping_turtle":
			return 24.0
		"water_snake":
			return 22.0
		"alligator":
			return 24.0
		"wolf_spider":
			return 26.0
		"firefly":
			return 88.0
		"mink":
			return 18.0
		"bullfrog":
			return 34.0
		"cane_toad":
			return 58.0
		"crayfish":
			return 28.0
		"water_shrew":
			return 20.0
		"beaver":
			return 22.0
		"owl":
			return 60.0
		"great_blue_heron":
			return 52.0
		"kingfisher":
			return 24.0
		"duck":
			return 20.0
		_:
			return 32.0

func _primary_range(actor: Node, target: Node) -> float:
	return _preferred_range(actor) + actor.body_radius * 1.5 + _target_radius(target)
