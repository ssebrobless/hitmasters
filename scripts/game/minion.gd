extends CharacterBody2D
class_name Minion

const VisualStyle := preload("res://scripts/visual/visual_style.gd")

var arena: Node = null
var team := 0
var max_health := 80.0
var health := 80.0
var speed := 145.0
var damage := 14.0
var attack_range := 34.0
var attack_cooldown := 0.9
var attack_timer := 0.0
var body_radius := 13.0

func setup(minion_arena: Node, minion_team: int, spawn_position: Vector2) -> void:
	arena = minion_arena
	team = minion_team
	position = spawn_position
	health = max_health
	queue_redraw()

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	var target: Node = arena.get_closest_enemy(self, 260.0) if arena != null else null
	var enemy_core: Node = arena.get_enemy_core(team) if arena != null else null

	if target == null:
		target = enemy_core

	if target == null:
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			var attack_damage: float = damage
			if arena != null and target == enemy_core:
				attack_damage *= arena.get_core_damage_multiplier(team)
			target.take_damage(attack_damage, team, self)
			if arena != null and target == enemy_core:
				arena.record_core_damage(team, attack_damage, self)
			attack_timer = attack_cooldown
	else:
		var move_direction := to_target.normalized()
		if arena != null:
			move_direction = arena.get_steering_direction(global_position, target.global_position, body_radius, team)
		velocity = move_direction * speed
		move_and_slide()
		if arena != null:
			global_position = arena.resolve_body_position(global_position, body_radius)

	queue_redraw()

func take_damage(amount: float, _source_team: int, _source_actor: Node = null) -> void:
	if health <= 0.0:
		return

	health = maxf(health - amount, 0.0)
	queue_redraw()

	if health <= 0.0:
		if arena != null:
			arena.unregister_entity(self)
		queue_free()

func _draw() -> void:
	VisualStyle.draw_pixel_minion(self, team, 4.0)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 8.0), Vector2(body_radius * 2.0, 4.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 8.0), Vector2(body_radius * 2.0 * (health / max_health), 4.0)), Color(0.3, 1.0, 0.45))
