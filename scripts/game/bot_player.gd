extends CharacterBody2D

const VisualStyle := preload("res://scripts/visual/visual_style.gd")

const HERO_ORDER := [
	"iron_vanguard",
	"blinkblade",
	"burst_rifle",
	"longshot",
	"lifewarden",
	"chorus"
]

var arena: Node = null
var team := 1
var hero_data: Dictionary = {}
var bot_name := "Bot"
var max_health := 100.0
var health := 100.0
var speed := 300.0
var primary_damage := 10.0
var body_radius := 18.0
var primary_cooldown := 0.45
var primary_timer := 0.0
var ability_cooldown := 5.0
var ability_timer := 1.0
var respawn_timer := 0.0
var respawn_duration := 4.0
var alive := true

func setup(bot_arena: Node, bot_team: int, spawn_position: Vector2, hero_id: String, display_name: String) -> void:
	arena = bot_arena
	team = bot_team
	position = spawn_position
	bot_name = display_name
	apply_hero(hero_id)

func _physics_process(delta: float) -> void:
	if not alive:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	primary_timer = maxf(primary_timer - delta, 0.0)
	ability_timer = maxf(ability_timer - delta, 0.0)

	if arena != null and arena.should_seek_objective(self):
		_move_toward_position(arena.get_objective_position())
		queue_redraw()
		return

	var target: Node = arena.get_closest_enemy(self, 920.0) if arena != null else null
	if target == null and arena != null:
		target = arena.get_enemy_core(team)
	if target == null:
		return

	var aim: Vector2 = (target.global_position - global_position).normalized()
	_move_for_range(target, aim)
	_try_attack(target, aim)
	queue_redraw()

func apply_hero(hero_id: String) -> void:
	hero_data = arena.get_hero_data(hero_id) if arena != null else {}
	max_health = float(hero_data.get("health", 100))
	health = max_health
	speed = float(hero_data.get("speed", 300)) * 0.92
	primary_damage = float(hero_data.get("primary_damage", 10))
	primary_cooldown = _get_primary_cooldown(hero_id)
	ability_cooldown = _get_ability_cooldown(hero_id)
	queue_redraw()

func get_actor_name() -> String:
	return bot_name

func is_scored_actor() -> bool:
	return true

func is_alive() -> bool:
	return alive

func take_damage(amount: float, _source_team: int, source_actor: Node = null) -> void:
	if not alive:
		return

	health = maxf(health - amount, 0.0)
	queue_redraw()

	if health <= 0.0:
		if arena != null:
			arena.record_death(self, source_actor)
		alive = false
		visible = false
		respawn_timer = respawn_duration
		if arena != null:
			arena.unregister_entity(self)

func heal(amount: float) -> void:
	if alive:
		health = minf(health + amount, max_health)

func _move_for_range(target: Node, aim: Vector2) -> void:
	var hero_id: String = hero_data.get("id", "burst_rifle")
	var distance: float = global_position.distance_to(target.global_position)
	var preferred_range := _get_preferred_range(hero_id)
	var lane_bias := Vector2(0.0, 1.0 if team == 0 else -1.0)
	var move_direction := Vector2.ZERO

	if distance > preferred_range + 40.0:
		move_direction = aim
	elif distance < preferred_range - 80.0 and hero_id not in ["iron_vanguard", "blinkblade"]:
		move_direction = -aim + lane_bias * 0.35
	elif hero_id in ["iron_vanguard", "blinkblade"] and distance > 58.0:
		move_direction = aim
	else:
		move_direction = Vector2(-aim.y, aim.x) * (1.0 if team == 0 else -1.0)

	if arena != null:
		move_direction = arena.get_steering_direction(global_position, global_position + move_direction.normalized() * 100.0, body_radius, team)

	velocity = move_direction.normalized() * speed
	move_and_slide()
	if arena != null:
		global_position = arena.resolve_body_position(global_position, body_radius)

func _move_toward_position(target_position: Vector2) -> void:
	var move_direction := (target_position - global_position).normalized()
	if arena != null:
		move_direction = arena.get_steering_direction(global_position, target_position, body_radius, team)

	velocity = move_direction * speed
	move_and_slide()
	if arena != null:
		global_position = arena.resolve_body_position(global_position, body_radius)

func _try_attack(target: Node, aim: Vector2) -> void:
	var hero_id: String = hero_data.get("id", "burst_rifle")
	var distance: float = global_position.distance_to(target.global_position)
	var can_see_target: bool = arena.has_line_of_sight(global_position, target.global_position, 5.0) if arena != null else true
	if distance <= _get_primary_range(hero_id) and primary_timer <= 0.0:
		if can_see_target or hero_id in ["iron_vanguard", "blinkblade"]:
			_fire_primary(aim)
			primary_timer = primary_cooldown

	if ability_timer <= 0.0 and distance <= _get_ability_range(hero_id) and can_see_target:
		_use_ability(aim)
		ability_timer = ability_cooldown

func _fire_primary(aim: Vector2) -> void:
	var hero_id: String = hero_data.get("id", "burst_rifle")
	match hero_id:
		"iron_vanguard":
			arena.add_circle_telegraph(global_position + aim * 28.0, 48.0, Color(0.75, 0.85, 1.0, 0.45), 0.16, 3.0, true)
			arena.damage_enemies_in_radius(team, global_position + aim * 28.0, 48.0, primary_damage, self)
		"blinkblade":
			arena.add_circle_telegraph(global_position + aim * 24.0, 38.0, Color(1.0, 0.58, 0.25, 0.45), 0.14, 3.0, true)
			arena.damage_enemies_in_radius(team, global_position + aim * 24.0, 38.0, primary_damage, self)
		"longshot":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 760.0, Color(1.0, 0.95, 0.35, 0.65), 0.18, 3.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, primary_damage, 980.0, Color(1.0, 0.95, 0.35), true, 5.0, 1.2, self)
		"lifewarden":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 460.0, Color(0.65, 1.0, 0.95, 0.6), 0.14, 3.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, primary_damage, 680.0, Color(0.65, 1.0, 0.95), false, 7.0, 1.4, self)
		"chorus":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 430.0, Color(0.95, 0.55, 1.0, 0.6), 0.16, 4.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, primary_damage, 640.0, Color(0.95, 0.55, 1.0), false, 8.0, 1.35, self)
		_:
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 480.0, Color(1.0, 0.9, 0.45, 0.55), 0.12, 5.0)
			for spread in [-0.08, 0.0, 0.08]:
				arena.spawn_projectile(team, global_position + aim * 24.0, aim.rotated(spread), primary_damage, 760.0, Color(1.0, 0.9, 0.45), false, 6.0, 1.1, self)

func _use_ability(aim: Vector2) -> void:
	var hero_id: String = hero_data.get("id", "burst_rifle")
	match hero_id:
		"iron_vanguard":
			arena.add_circle_telegraph(global_position + aim * 58.0, 66.0, Color(0.75, 0.85, 1.0, 0.55), 0.24, 4.0, true)
			arena.damage_enemies_in_radius(team, global_position + aim * 58.0, 66.0, 30.0, self)
		"blinkblade":
			arena.add_line_telegraph(global_position, global_position + aim * 140.0, Color(1.0, 0.58, 0.25, 0.65), 0.22, 7.0)
			global_position = arena.resolve_body_position(global_position + aim * 140.0, body_radius)
			arena.add_circle_telegraph(global_position, 58.0, Color(1.0, 0.58, 0.25, 0.55), 0.2, 4.0, true)
			arena.damage_enemies_in_radius(team, global_position, 58.0, 34.0, self)
		"longshot":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 880.0, Color(1.0, 0.35, 0.25, 0.75), 0.24, 6.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, 62.0, 1250.0, Color(1.0, 0.35, 0.25), true, 6.0, 1.1, self)
		"lifewarden":
			heal(36.0)
			arena.add_circle_telegraph(global_position, 120.0, Color(0.55, 1.0, 0.8, 0.55), 0.34, 4.0, true)
			arena.heal_allies_in_radius(team, global_position, 120.0, 20.0)
		"chorus":
			arena.add_circle_telegraph(global_position, 150.0, Color(0.95, 0.45, 1.0, 0.55), 0.36, 4.0, true)
			arena.damage_enemies_in_radius(team, global_position, 150.0, 12.0, self)
			arena.heal_allies_in_radius(team, global_position, 150.0, 12.0)
		_:
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 620.0, Color(1.0, 0.65, 0.25, 0.65), 0.2, 5.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, 30.0, 900.0, Color(1.0, 0.65, 0.25), true, 8.0, 1.2, self)

func _respawn() -> void:
	alive = true
	visible = true
	health = max_health
	position = arena.resolve_body_position(arena.get_bot_spawn(team, bot_name), body_radius) if arena != null else Vector2.ZERO
	primary_timer = 0.6
	ability_timer = 1.2
	if arena != null:
		arena.register_entity(self)
		arena.add_circle_telegraph(global_position, 72.0, Color(0.45, 0.72, 1.0, 0.45) if team == 0 else Color(1.0, 0.28, 0.25, 0.45), 0.45, 4.0, true)

func _get_primary_cooldown(hero_id: String) -> float:
	match hero_id:
		"iron_vanguard":
			return 0.72
		"blinkblade":
			return 0.4
		"longshot":
			return 1.05
		"lifewarden":
			return 0.52
		"chorus":
			return 0.58
		_:
			return 0.45

func _get_ability_cooldown(hero_id: String) -> float:
	match hero_id:
		"blinkblade":
			return 4.4
		"longshot":
			return 5.8
		"lifewarden", "chorus":
			return 5.0
		_:
			return 4.8

func _get_preferred_range(hero_id: String) -> float:
	match hero_id:
		"iron_vanguard", "blinkblade":
			return 54.0
		"longshot":
			return 520.0
		"lifewarden", "chorus":
			return 340.0
		_:
			return 300.0

func _get_primary_range(hero_id: String) -> float:
	match hero_id:
		"iron_vanguard", "blinkblade":
			return 72.0
		"longshot":
			return 680.0
		_:
			return 460.0

func _get_ability_range(hero_id: String) -> float:
	match hero_id:
		"iron_vanguard", "blinkblade":
			return 100.0
		"longshot":
			return 720.0
		"lifewarden", "chorus":
			return 230.0
		_:
			return 500.0

func _draw() -> void:
	if not alive:
		var timer_text := "%.0f" % ceili(respawn_timer)
		draw_string(ThemeDB.fallback_font, Vector2(-12.0, 4.0), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 1.0, 1.0, 0.75))
		return
	VisualStyle.draw_pixel_hero(self, hero_data.get("id", "burst_rifle"), team, 5.0)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 13.0), Vector2(body_radius * 2.0, 5.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 13.0), Vector2(body_radius * 2.0 * (health / max_health), 5.0)), Color(0.3, 1.0, 0.45))
