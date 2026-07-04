extends CharacterBody2D
class_name Minion

# Mud minions. Kinds:
#   lane   — marches down its lane toward the opposing hut (then core)
#   tank   — hut defender, slow and beefy
#   melee  — hut defender, standard chomper
#   pebble — hut defender, ranged pebble thrower
# Defenders leash to their hut and respawn via the hut, not here.

const VisualStyle := preload("res://scripts/visual/visual_style.gd")

const LEASH_RANGE := 130.0
const AGGRO_RANGE := 260.0

var arena: Node = null
var team := 0
var kind := "lane"
var max_health := 80.0
var health := 80.0
var speed := 145.0
var damage := 14.0
var attack_range := 34.0
var attack_cooldown := 0.9
var attack_timer := 0.0
var body_radius := 13.0
var march_target := Vector2.ZERO
var leash_hut: Node = null
var defender_slot := 0
var target_refresh_timer := 0.0
var cached_target: Node = null

func setup(minion_arena: Node, minion_team: int, spawn_position: Vector2, minion_kind := "lane", lane_target := Vector2.ZERO, hut: Node = null, slot := 0) -> void:
	arena = minion_arena
	team = minion_team
	position = spawn_position
	kind = minion_kind
	march_target = lane_target
	leash_hut = hut
	defender_slot = slot
	match kind:
		"tank":
			max_health = 220.0
			damage = 10.0
			speed = 105.0
			body_radius = 17.0
			attack_cooldown = 1.2
		"pebble":
			max_health = 70.0
			damage = 10.0
			speed = 125.0
			attack_range = 96.0
			attack_cooldown = 1.4
		"melee":
			max_health = 90.0
		_:
			pass
	health = max_health
	queue_redraw()

func is_alive() -> bool:
	return health > 0.0

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	# Re-query targets on a timer, not every frame — O(n) scans are the cost.
	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0:
		cached_target = arena.get_closest_enemy(self, AGGRO_RANGE) if arena != null else null
		target_refresh_timer = 0.2 + float(get_instance_id() % 7) * 0.015
	if cached_target != null and (not is_instance_valid(cached_target) or (cached_target.has_method("is_alive") and not cached_target.is_alive())):
		cached_target = null
	var target: Node = cached_target

	# Defenders stay home: drop distant targets and walk back when leashed out.
	if leash_hut != null and is_instance_valid(leash_hut):
		var from_home: float = global_position.distance_to(leash_hut.global_position)
		if from_home > LEASH_RANGE:
			target = null
			_move_toward_point(leash_hut.global_position)
			_request_redraw()
			return

	if target == null:
		if kind == "lane":
			_march(delta)
		elif leash_hut != null and is_instance_valid(leash_hut) and global_position.distance_to(leash_hut.global_position) > 60.0:
			_move_toward_point(leash_hut.global_position)
		else:
			velocity = Vector2.ZERO
		_request_redraw()
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	if distance <= attack_range + target.body_radius:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			_attack(target)
			attack_timer = attack_cooldown
	else:
		_move_toward_point(target.global_position)
	_request_redraw()

func _attack(target: Node) -> void:
	if kind == "pebble":
		var direction: Vector2 = (target.global_position - global_position).normalized()
		if arena != null:
			arena.spawn_projectile(team, global_position + direction * (body_radius + 4.0), direction, damage, 340.0, Color(0.6, 0.55, 0.45), false, 5.0, 0.6, self)
		return
	if _is_enemy_core(target):
		if arena != null and not arena.can_damage_core(target.team):
			return
		var core_damage: float = damage * arena.get_core_damage_multiplier(team)
		target.take_damage(core_damage, team, self)
		arena.record_core_damage(team, core_damage, self)
		return
	target.take_damage(damage, team, self)

func _march(_delta: float) -> void:
	var destination := march_target
	if arena != null and arena.has_method("get_lane_destination"):
		destination = arena.get_lane_destination(team, march_target)
	# When the lane is clear the destination becomes the enemy core: attack
	# it on arrival instead of idling next to it.
	var enemy_core: Node = arena.get_enemy_core(team) if arena != null else null
	if enemy_core != null and destination.distance_to(enemy_core.global_position) < 1.0:
		var core_distance: float = global_position.distance_to(enemy_core.global_position)
		if core_distance <= attack_range + enemy_core.radius:
			velocity = Vector2.ZERO
			if attack_timer <= 0.0:
				_attack(enemy_core)
				attack_timer = attack_cooldown
			return
	if global_position.distance_to(destination) < 40.0:
		velocity = Vector2.ZERO
		return
	_move_toward_point(destination)

func _move_toward_point(point: Vector2) -> void:
	var move_direction := (point - global_position).normalized()
	if arena != null:
		move_direction = arena.get_steering_direction(global_position, point, body_radius, team)
	velocity = move_direction * speed
	move_and_slide()
	if arena != null:
		global_position = arena.resolve_body_position(global_position, body_radius)

func _is_enemy_core(target: Node) -> bool:
	return arena != null and target == arena.get_enemy_core(team)

func _request_redraw() -> void:
	if arena == null or not arena.has_method("is_near_view") or arena.is_near_view(global_position):
		queue_redraw()

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	if health <= 0.0:
		return

	health = maxf(health - amount, 0.0)
	queue_redraw()

	if health <= 0.0:
		if leash_hut != null and is_instance_valid(leash_hut) and leash_hut.has_method("on_defender_died"):
			leash_hut.on_defender_died(kind, defender_slot)
		if arena != null:
			arena.unregister_entity(self)
		queue_free()

func take_damage_event(event: Resource) -> void:
	take_damage(event.amount, -1, event.source_actor)

func _draw() -> void:
	var pixel_size := 5.0 if kind == "tank" else 4.0
	VisualStyle.draw_pixel_minion(self, team, pixel_size)
	if kind == "pebble":
		draw_circle(Vector2(0.0, -body_radius - 3.0), 3.0, Color(0.6, 0.55, 0.45))
	elif kind == "tank":
		draw_arc(Vector2.ZERO, body_radius + 2.0, 0.0, TAU, 20, Color(0.5, 0.45, 0.35), 2.0)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 8.0), Vector2(body_radius * 2.0, 4.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 8.0), Vector2(body_radius * 2.0 * (health / max_health), 4.0)), Color(0.3, 1.0, 0.45))
