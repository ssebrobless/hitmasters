extends CharacterBody2D
class_name Player

signal hero_changed(hero_id: String)

const VisualStyle := preload("res://scripts/visual/visual_style.gd")
const LocalInputScript := preload("res://scripts/ui/local_input.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const HERO_ORDER := [
	"iron_vanguard",
	"blinkblade",
	"burst_rifle",
	"longshot",
	"lifewarden",
	"chorus"
]

var arena: Node = null
var team := 0
var hero_data: Dictionary = {}
var hero_index := 2
var max_health := 100.0
var health := 100.0
var speed := 300.0
var primary_damage := 10.0
var body_radius := 18.0
var primary_cooldown := 0.28
var primary_timer := 0.0
var dash_cooldown := 3.0
var dash_timer := 0.0
var ability_cooldown := 5.0
var ability_timer := 0.0
var dash_velocity := Vector2.ZERO
var dash_time := 0.0
var actor_name := "You"
var alive := true
var respawn_timer := 0.0
var respawn_duration := 4.0
var local_input: Node = LocalInputScript.new()
var input_frame: Resource = null

func setup(player_arena: Node, player_team: int, spawn_position: Vector2, hero_id: String) -> void:
	arena = player_arena
	team = player_team
	position = spawn_position
	var index := HERO_ORDER.find(hero_id)
	hero_index = index if index >= 0 else 2
	apply_hero(HERO_ORDER[hero_index])

func _physics_process(delta: float) -> void:
	if not alive:
		respawn_timer = maxf(respawn_timer - delta, 0.0)
		if respawn_timer <= 0.0:
			_respawn()
		queue_redraw()
		return

	primary_timer = maxf(primary_timer - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	ability_timer = maxf(ability_timer - delta, 0.0)
	dash_time = maxf(dash_time - delta, 0.0)
	input_frame = local_input.build_frame(get_global_mouse_position())

	_handle_hero_hotkeys()
	_handle_movement(delta)
	_handle_combat()
	queue_redraw()

func apply_hero(hero_id: String) -> void:
	hero_data = arena.get_hero_data(hero_id) if arena != null else {}
	max_health = float(hero_data.get("health", 100))
	health = max_health
	speed = float(hero_data.get("speed", 300))
	primary_damage = float(hero_data.get("primary_damage", 10))
	primary_cooldown = _get_primary_cooldown(hero_id)
	hero_changed.emit(hero_id)
	queue_redraw()

func get_actor_name() -> String:
	return actor_name

func is_scored_actor() -> bool:
	return true

func is_alive() -> bool:
	return alive

func take_damage(amount: float, _source_team: int, source_actor: Node = null) -> void:
	if not alive:
		return

	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		if arena != null:
			arena.record_death(self, source_actor)
			arena.unregister_entity(self)
		alive = false
		respawn_timer = respawn_duration
		visible = false
		velocity = Vector2.ZERO

func heal(amount: float) -> void:
	if alive:
		health = minf(health + amount, max_health)

func _handle_hero_hotkeys() -> void:
	if input_frame == null:
		return
	var slot: int = input_frame.legacy_hero_slot
	if slot >= 0 and slot < HERO_ORDER.size() and hero_index != slot:
		hero_index = slot
		apply_hero(HERO_ORDER[hero_index])

func _handle_movement(delta: float) -> void:
	if dash_time > 0.0:
		velocity = dash_velocity
	else:
		var input_vector: Vector2 = input_frame.move.normalized() if input_frame != null else Vector2.ZERO
		velocity = input_vector * speed

		if input_frame != null and input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE) and dash_timer <= 0.0 and input_vector != Vector2.ZERO:
			dash_velocity = input_vector * 850.0
			dash_time = 0.14
			dash_timer = dash_cooldown

	move_and_slide()
	if arena != null:
		global_position = arena.resolve_body_position(global_position, body_radius)

func _handle_combat() -> void:
	if arena == null:
		return

	var aim: Vector2 = (input_frame.aim - global_position).normalized() if input_frame != null else Vector2.RIGHT
	if input_frame != null and input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and primary_timer <= 0.0:
		_fire_primary(aim)
		primary_timer = primary_cooldown

	if input_frame != null and input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and ability_timer <= 0.0:
		_use_ability(aim)
		ability_timer = ability_cooldown

func _fire_primary(aim: Vector2) -> void:
	var hero_id: String = hero_data.get("id", "burst_rifle")
	match hero_id:
		"iron_vanguard":
			arena.add_circle_telegraph(global_position + aim * 28.0, 48.0, Color(0.75, 0.85, 1.0, 0.75), 0.18, 3.0, true)
			arena.damage_enemies_in_radius(team, global_position + aim * 28.0, 48.0, primary_damage, self)
		"blinkblade":
			arena.add_circle_telegraph(global_position + aim * 24.0, 38.0, Color(1.0, 0.58, 0.25, 0.75), 0.14, 3.0, true)
			arena.damage_enemies_in_radius(team, global_position + aim * 24.0, 38.0, primary_damage, self)
		"longshot":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 760.0, Color(1.0, 0.95, 0.35, 0.85), 0.18, 3.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, primary_damage, 980.0, Color(1.0, 0.95, 0.35), true, 5.0, 1.2, self)
		"lifewarden":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 460.0, Color(0.65, 1.0, 0.95, 0.8), 0.14, 3.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, primary_damage, 680.0, Color(0.65, 1.0, 0.95), false, 7.0, 1.4, self)
		"chorus":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 430.0, Color(0.95, 0.55, 1.0, 0.8), 0.16, 4.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, primary_damage, 640.0, Color(0.95, 0.55, 1.0), false, 8.0, 1.35, self)
		_:
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 480.0, Color(1.0, 0.9, 0.45, 0.75), 0.12, 5.0)
			for spread in [-0.08, 0.0, 0.08]:
				arena.spawn_projectile(team, global_position + aim * 24.0, aim.rotated(spread), primary_damage, 760.0, Color(1.0, 0.9, 0.45), false, 6.0, 1.1, self)

func _use_ability(aim: Vector2) -> void:
	var hero_id: String = hero_data.get("id", "burst_rifle")
	match hero_id:
		"iron_vanguard":
			dash_velocity = aim * 640.0
			dash_time = 0.18
			arena.add_line_telegraph(global_position, global_position + aim * 130.0, Color(0.75, 0.85, 1.0, 0.85), 0.24, 9.0)
			arena.add_circle_telegraph(global_position + aim * 58.0, 66.0, Color(0.75, 0.85, 1.0, 0.75), 0.25, 4.0, true)
			arena.damage_enemies_in_radius(team, global_position + aim * 58.0, 66.0, 30.0, self)
		"blinkblade":
			arena.add_line_telegraph(global_position, global_position + aim * 165.0, Color(1.0, 0.58, 0.25, 0.85), 0.22, 7.0)
			global_position = arena.resolve_body_position(global_position + aim * 165.0, body_radius)
			arena.add_circle_telegraph(global_position, 58.0, Color(1.0, 0.58, 0.25, 0.75), 0.2, 4.0, true)
			arena.damage_enemies_in_radius(team, global_position, 58.0, 34.0, self)
		"longshot":
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 880.0, Color(1.0, 0.35, 0.25, 0.9), 0.24, 6.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, 62.0, 1250.0, Color(1.0, 0.35, 0.25), true, 6.0, 1.1, self)
		"lifewarden":
			heal(45.0)
			arena.add_circle_telegraph(global_position, 110.0, Color(0.55, 1.0, 0.8, 0.8), 0.34, 4.0, true)
			arena.heal_allies_in_radius(team, global_position, 110.0, 22.0)
		"chorus":
			arena.add_circle_telegraph(global_position, 150.0, Color(0.95, 0.45, 1.0, 0.78), 0.36, 4.0, true)
			arena.damage_enemies_in_radius(team, global_position, 150.0, 12.0, self)
			arena.heal_allies_in_radius(team, global_position, 150.0, 12.0)
		_:
			arena.add_line_telegraph(global_position + aim * 24.0, global_position + aim * 620.0, Color(1.0, 0.65, 0.25, 0.85), 0.2, 5.0)
			arena.spawn_projectile(team, global_position + aim * 24.0, aim, 30.0, 900.0, Color(1.0, 0.65, 0.25), true, 8.0, 1.2, self)

func _get_primary_cooldown(hero_id: String) -> float:
	match hero_id:
		"iron_vanguard":
			return 0.62
		"blinkblade":
			return 0.32
		"longshot":
			return 0.9
		"lifewarden":
			return 0.42
		"chorus":
			return 0.48
		_:
			return 0.38

func _respawn() -> void:
	alive = true
	visible = true
	health = max_health
	position = arena.resolve_body_position(arena.get_team_spawn(team), body_radius) if arena != null else Vector2.ZERO
	dash_timer = 1.0
	ability_timer = 1.0
	primary_timer = 0.4
	if arena != null:
		arena.register_entity(self)
		arena.add_circle_telegraph(global_position, 78.0, Color(0.45, 0.72, 1.0, 0.75), 0.55, 4.0, true)

func _draw() -> void:
	if not alive:
		return
	VisualStyle.draw_pixel_hero(self, hero_data.get("id", "burst_rifle"), team, 5.0)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0, 5.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0 * (health / max_health), 5.0)), Color(0.3, 1.0, 0.45))
	_draw_cooldown_bar(Vector2(-body_radius, body_radius + 7.0), body_radius * 2.0, 4.0, primary_timer, primary_cooldown, Color(1.0, 0.9, 0.45))
	_draw_cooldown_bar(Vector2(-body_radius, body_radius + 13.0), body_radius * 2.0, 4.0, dash_timer, dash_cooldown, Color(0.45, 0.72, 1.0))
	_draw_cooldown_bar(Vector2(-body_radius, body_radius + 19.0), body_radius * 2.0, 4.0, ability_timer, ability_cooldown, Color(0.95, 0.45, 1.0))

func _draw_cooldown_bar(start: Vector2, width: float, height: float, timer: float, cooldown: float, color: Color) -> void:
	var ready_ratio := 1.0 - clampf(timer / maxf(cooldown, 0.01), 0.0, 1.0)
	draw_rect(Rect2(start, Vector2(width, height)), Color(0.06, 0.06, 0.07))
	draw_rect(Rect2(start, Vector2(width * ready_ratio, height)), color)
