extends Node2D

const BLUE := 0
const RED := 1
const ARENA_RECT := Rect2(Vector2(-1120.0, -620.0), Vector2(2240.0, 1240.0))
const WAVE_INTERVAL := 20.0
const OBJECTIVE_POSITION := Vector2(0.0, 0.0)
const OBJECTIVE_RADIUS := 118.0
const OBJECTIVE_CAPTURE_SECONDS := 4.0
const OBJECTIVE_RESPAWN_SECONDS := 42.0
const SURGE_SECONDS := 22.0
const SURGE_CORE_DAMAGE_MULTIPLIER := 1.35
const COVER_RECTS := [
	Rect2(Vector2(-210.0, -265.0), Vector2(130.0, 105.0)),
	Rect2(Vector2(80.0, 160.0), Vector2(130.0, 105.0)),
	Rect2(Vector2(-50.0, -42.0), Vector2(100.0, 84.0))
]
const CoreScript := preload("res://scripts/game/core.gd")
const MinionScript := preload("res://scripts/game/minion.gd")
const PlayerScript := preload("res://scripts/game/player.gd")
const BotPlayerScript := preload("res://scripts/game/bot_player.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")

var heroes_by_id: Dictionary = {}
var entities: Array[Node] = []
var minions: Array[Node] = []
var bots: Array[Node] = []
var cores: Dictionary = {}
var player: Node
var wave_timer := 2.0
var elapsed := 0.0
var match_over := false
var telegraphs: Array[Dictionary] = []
var actor_stats: Dictionary = {}
var team_stats := {
	BLUE: {"kills": 0, "deaths": 0, "core_damage": 0.0, "objectives": 0},
	RED: {"kills": 0, "deaths": 0, "core_damage": 0.0, "objectives": 0}
}
var kill_feed: Array[Dictionary] = []
var objective_active := true
var objective_capture := 0.0
var objective_respawn_timer := 0.0
var surge_timers := {
	BLUE: 0.0,
	RED: 0.0
}
var arena_rect := ARENA_RECT
var cover_rects: Array = []
var wave_interval := WAVE_INTERVAL
var wave_minion_offsets: Array = []
var blue_core_position := Vector2(-910.0, 0.0)
var red_core_position := Vector2(910.0, 0.0)
var blue_minion_spawn := Vector2(-760.0, 0.0)
var red_minion_spawn := Vector2(760.0, 0.0)
var team_spawns := {}
var bot_spawns := {}
var objective_position := OBJECTIVE_POSITION
var objective_radius := OBJECTIVE_RADIUS
var objective_capture_seconds := OBJECTIVE_CAPTURE_SECONDS
var objective_respawn_seconds := OBJECTIVE_RESPAWN_SECONDS
var surge_seconds := SURGE_SECONDS
var camera_zoom := Vector2(0.9, 0.9)

var status_label: Label
var core_label: Label
var cooldown_label: Label
var scoreboard_label: Label
var kill_feed_label: Label
var end_summary_label: Label
var help_label: Label

func _ready() -> void:
	_configure_mode()
	_load_hero_data()
	_build_ui()
	_spawn_match()

func _configure_mode() -> void:
	if GameConfig.selected_mode == "1v1" or GameConfig.selected_mode == "Hero Lab":
		arena_rect = Rect2(Vector2(-820.0, -460.0), Vector2(1640.0, 920.0))
		cover_rects = [
			Rect2(Vector2(-110.0, -190.0), Vector2(95.0, 80.0)),
			Rect2(Vector2(30.0, 115.0), Vector2(95.0, 80.0)),
			Rect2(Vector2(-42.0, -34.0), Vector2(84.0, 68.0))
		]
		wave_interval = 18.0
		wave_minion_offsets = [Vector2(0.0, -32.0), Vector2(0.0, 32.0)]
		blue_core_position = Vector2(-660.0, 0.0)
		red_core_position = Vector2(660.0, 0.0)
		blue_minion_spawn = Vector2(-525.0, 0.0)
		red_minion_spawn = Vector2(525.0, 0.0)
		team_spawns = {
			BLUE: Vector2(-520.0, 145.0),
			RED: Vector2(520.0, -145.0)
		}
		bot_spawns = {
			"Red Rival": Vector2(520.0, -145.0)
		}
		objective_position = Vector2(0.0, 0.0)
		objective_radius = 92.0
		objective_capture_seconds = 3.2
		objective_respawn_seconds = 34.0
		surge_seconds = 18.0
		camera_zoom = Vector2(1.08, 1.08)
	else:
		arena_rect = ARENA_RECT
		cover_rects = COVER_RECTS.duplicate()
		wave_interval = WAVE_INTERVAL
		wave_minion_offsets = [Vector2(0.0, -46.0), Vector2(0.0, 0.0), Vector2(0.0, 46.0)]
		blue_core_position = Vector2(-910.0, 0.0)
		red_core_position = Vector2(910.0, 0.0)
		blue_minion_spawn = Vector2(-760.0, 0.0)
		red_minion_spawn = Vector2(760.0, 0.0)
		team_spawns = {
			BLUE: Vector2(-720.0, 180.0),
			RED: Vector2(720.0, -180.0)
		}
		bot_spawns = {
			"Blue Guard": Vector2(-700.0, -160.0),
			"Blue Ward": Vector2(-740.0, 60.0),
			"Red Blade": Vector2(700.0, -150.0),
			"Red Scope": Vector2(740.0, 55.0),
			"Red Chorus": Vector2(700.0, 185.0),
			"Red Rival": Vector2(700.0, -180.0)
		}
		objective_position = OBJECTIVE_POSITION
		objective_radius = OBJECTIVE_RADIUS
		objective_capture_seconds = OBJECTIVE_CAPTURE_SECONDS
		objective_respawn_seconds = OBJECTIVE_RESPAWN_SECONDS
		surge_seconds = SURGE_SECONDS
		camera_zoom = Vector2(0.9, 0.9)

	wave_timer = 2.0

func _process(delta: float) -> void:
	if match_over:
		if Input.is_key_pressed(KEY_ENTER):
			get_tree().reload_current_scene()
		if Input.is_key_pressed(KEY_ESCAPE):
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return

	elapsed += delta
	wave_timer -= delta
	_tick_telegraphs(delta)
	_tick_kill_feed(delta)
	_tick_objective(delta)
	if wave_timer <= 0.0:
		spawn_wave()
		wave_timer = wave_interval

	_update_ui()
	queue_redraw()

func _draw() -> void:
	draw_rect(arena_rect, Color(0.08, 0.1, 0.11))
	draw_rect(arena_rect, Color(0.22, 0.28, 0.31), false, 5.0)

	for x in range(int(arena_rect.position.x), int(arena_rect.end.x), 80):
		draw_line(Vector2(x, arena_rect.position.y), Vector2(x, arena_rect.end.y), Color(0.1, 0.13, 0.14), 1.0)
	for y in range(int(arena_rect.position.y), int(arena_rect.end.y), 80):
		draw_line(Vector2(arena_rect.position.x, y), Vector2(arena_rect.end.x, y), Color(0.1, 0.13, 0.14), 1.0)

	draw_rect(Rect2(Vector2(arena_rect.position.x, -120.0), Vector2(arena_rect.size.x, 240.0)), Color(0.12, 0.15, 0.16))
	draw_rect(Rect2(blue_core_position - Vector2(150.0, 190.0), Vector2(330.0, 380.0)), Color(0.07, 0.13, 0.19))
	draw_rect(Rect2(red_core_position - Vector2(180.0, 190.0), Vector2(330.0, 380.0)), Color(0.18, 0.08, 0.08))
	draw_line(Vector2(arena_rect.position.x, 0.0), Vector2(arena_rect.end.x, 0.0), Color(0.32, 0.36, 0.37), 2.0)
	draw_line(Vector2(blue_minion_spawn.x, -90.0), Vector2(red_minion_spawn.x, -90.0), Color(0.22, 0.26, 0.27), 1.0)
	draw_line(Vector2(blue_minion_spawn.x, 90.0), Vector2(red_minion_spawn.x, 90.0), Color(0.22, 0.26, 0.27), 1.0)
	_draw_objective()

	for cover in cover_rects:
		draw_rect(cover, Color(0.18, 0.22, 0.24))
		draw_rect(cover.grow(-2.0), Color(0.28, 0.33, 0.35), false, 2.0)
		draw_line(cover.position + Vector2(8.0, 8.0), cover.end - Vector2(8.0, 8.0), Color(0.12, 0.15, 0.16), 2.0)

	_draw_telegraphs()

	draw_string(ThemeDB.fallback_font, blue_core_position + Vector2(-110.0, -150.0), "BLUE CORE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.45, 0.72, 1.0))
	draw_string(ThemeDB.fallback_font, red_core_position + Vector2(-15.0, -150.0), "RED CORE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.45, 0.4))

func _load_hero_data() -> void:
	var file := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	if file == null:
		push_error("Missing hero data.")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	for hero: Dictionary in parsed.get("heroes", []):
		heroes_by_id[hero.get("id", "")] = hero

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = 18.0
	root.offset_top = 14.0
	root.add_theme_constant_override("separation", 6)
	canvas.add_child(root)

	status_label = Label.new()
	core_label = Label.new()
	cooldown_label = Label.new()
	scoreboard_label = Label.new()
	kill_feed_label = Label.new()
	end_summary_label = Label.new()
	help_label = Label.new()
	help_label.text = "WASD move | mouse aim | LMB primary | RMB ability | Shift dash | 1-6 swap hero | Esc menu"

	root.add_child(status_label)
	root.add_child(core_label)
	root.add_child(cooldown_label)
	root.add_child(scoreboard_label)
	root.add_child(kill_feed_label)
	root.add_child(end_summary_label)
	root.add_child(help_label)

func _spawn_match() -> void:
	var blue_core = CoreScript.new()
	add_child(blue_core)
	blue_core.setup(BLUE, blue_core_position)
	blue_core.destroyed.connect(_on_core_destroyed)
	cores[BLUE] = blue_core

	var red_core = CoreScript.new()
	add_child(red_core)
	red_core.setup(RED, red_core_position)
	red_core.destroyed.connect(_on_core_destroyed)
	cores[RED] = red_core

	player = PlayerScript.new()
	add_child(player)
	player.setup(self, BLUE, get_team_spawn(BLUE), GameConfig.selected_hero_id)
	player.hero_changed.connect(_on_player_hero_changed)
	register_entity(player)
	_spawn_bots_for_mode()

	var camera := Camera2D.new()
	camera.zoom = camera_zoom
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	camera.make_current()

	spawn_wave()
	_update_ui()

func _spawn_bots_for_mode() -> void:
	if GameConfig.selected_mode == "3v3":
		_spawn_bot(BLUE, "iron_vanguard", get_bot_spawn(BLUE, "Blue Guard"), "Blue Guard")
		_spawn_bot(BLUE, "lifewarden", get_bot_spawn(BLUE, "Blue Ward"), "Blue Ward")
		_spawn_bot(RED, "blinkblade", get_bot_spawn(RED, "Red Blade"), "Red Blade")
		_spawn_bot(RED, "longshot", get_bot_spawn(RED, "Red Scope"), "Red Scope")
		_spawn_bot(RED, "chorus", get_bot_spawn(RED, "Red Chorus"), "Red Chorus")
	else:
		_spawn_bot(RED, "burst_rifle", get_bot_spawn(RED, "Red Rival"), "Red Rival")

func _spawn_bot(team: int, hero_id: String, spawn_position: Vector2, bot_name: String) -> void:
	var bot = BotPlayerScript.new()
	add_child(bot)
	bot.setup(self, team, spawn_position, hero_id, bot_name)
	bots.append(bot)
	register_entity(bot)

func spawn_wave() -> void:
	for i in wave_minion_offsets.size():
		_spawn_minion(BLUE, blue_minion_spawn + wave_minion_offsets[i] + Vector2(-i * 18.0, 0.0))
		_spawn_minion(RED, red_minion_spawn + wave_minion_offsets[i] + Vector2(i * 18.0, 0.0))

func _spawn_minion(team: int, spawn_position: Vector2) -> void:
	var minion = MinionScript.new()
	add_child(minion)
	minion.setup(self, team, spawn_position)
	minions.append(minion)
	register_entity(minion)

func register_entity(entity: Node) -> void:
	if not entities.has(entity):
		entities.append(entity)
	if entity.has_method("is_scored_actor") and entity.is_scored_actor():
		_ensure_actor_stats(entity)

func unregister_entity(entity: Node) -> void:
	entities.erase(entity)
	minions.erase(entity)

func spawn_projectile(projectile_team: int, start_position: Vector2, direction: Vector2, damage: float, speed: float, color: Color, pierce := false, radius := 7.0, lifetime := 1.6, source_actor: Node = null) -> void:
	var projectile = ProjectileScript.new()
	add_child(projectile)
	projectile.setup(self, projectile_team, start_position, direction, damage, speed, color, pierce, radius, lifetime, source_actor)

func add_line_telegraph(from: Vector2, to: Vector2, color: Color, duration := 0.16, width := 4.0) -> void:
	telegraphs.append({
		"type": "line",
		"from": from,
		"to": to,
		"color": color,
		"duration": duration,
		"remaining": duration,
		"width": width
	})

func add_circle_telegraph(center: Vector2, radius: float, color: Color, duration := 0.22, width := 3.0, filled := false) -> void:
	telegraphs.append({
		"type": "circle",
		"center": center,
		"radius": radius,
		"color": color,
		"duration": duration,
		"remaining": duration,
		"width": width,
		"filled": filled
	})

func resolve_projectile_hits(projectile: Node) -> void:
	if projectile_crosses_cover(projectile.previous_position, projectile.global_position, projectile.radius):
		projectile.queue_free()
		return

	for entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.team == projectile.team or projectile.hit_entities.has(entity):
			continue
		if entity.global_position.distance_to(projectile.global_position) <= projectile.radius + entity.body_radius:
			entity.take_damage(projectile.damage, projectile.team, projectile.source_actor)
			projectile.hit_entities.append(entity)
			if not projectile.pierce:
				projectile.queue_free()
				return

	for core_team in cores.keys():
		var core = cores[core_team]
		if core.team == projectile.team:
			continue
		if core.global_position.distance_to(projectile.global_position) <= projectile.radius + core.radius:
			var core_damage: float = projectile.damage * get_core_damage_multiplier(projectile.team)
			core.take_damage(core_damage, projectile.team, projectile.source_actor)
			record_core_damage(projectile.team, core_damage, projectile.source_actor)
			projectile.queue_free()
			return

func get_closest_enemy(source: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance := max_distance
	for entity in entities:
		if entity == source or entity == null or not is_instance_valid(entity):
			continue
		if entity.team == source.team:
			continue
		if not has_line_of_sight(source.global_position, entity.global_position, source.body_radius):
			continue
		var distance: float = source.global_position.distance_to(entity.global_position)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func damage_enemies_in_radius(source_team: int, center: Vector2, radius: float, damage: float, source_actor: Node = null) -> void:
	for entity in entities:
		if entity == null or not is_instance_valid(entity) or entity.team == source_team:
			continue
		if cover_blocks_point(center, entity.global_position, minf(radius, 18.0)):
			continue
		if entity.global_position.distance_to(center) <= radius + entity.body_radius:
			entity.take_damage(damage, source_team, source_actor)

	for core_team in cores.keys():
		var core = cores[core_team]
		if core.team != source_team and core.global_position.distance_to(center) <= radius + core.radius:
			var core_damage: float = damage * get_core_damage_multiplier(source_team)
			core.take_damage(core_damage, source_team, source_actor)
			record_core_damage(source_team, core_damage, source_actor)

func heal_allies_in_radius(source_team: int, center: Vector2, radius: float, amount: float) -> void:
	for entity in entities:
		if entity == null or not is_instance_valid(entity) or entity.team != source_team:
			continue
		if entity.has_method("heal") and entity.global_position.distance_to(center) <= radius + entity.body_radius:
			entity.heal(amount)

func record_death(victim: Node, killer: Node = null) -> void:
	if victim == null or not victim.has_method("is_scored_actor") or not victim.is_scored_actor():
		return

	var victim_key := _get_actor_key(victim)
	_ensure_actor_stats(victim)
	actor_stats[victim_key]["deaths"] += 1
	team_stats[victim.team]["deaths"] += 1

	if killer != null and is_instance_valid(killer) and killer.has_method("is_scored_actor") and killer.is_scored_actor() and killer.team != victim.team:
		var killer_key := _get_actor_key(killer)
		_ensure_actor_stats(killer)
		actor_stats[killer_key]["kills"] += 1
		team_stats[killer.team]["kills"] += 1
		add_kill_feed("%s eliminated %s" % [killer.get_actor_name(), victim.get_actor_name()])
	else:
		add_kill_feed("%s was eliminated" % victim.get_actor_name())

func record_core_damage(source_team: int, amount: float, source_actor: Node = null) -> void:
	team_stats[source_team]["core_damage"] += amount
	if source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("is_scored_actor") and source_actor.is_scored_actor():
		_ensure_actor_stats(source_actor)
		actor_stats[_get_actor_key(source_actor)]["core_damage"] += amount

func record_objective_capture(team: int) -> void:
	team_stats[team]["objectives"] += 1
	surge_timers[team] = surge_seconds
	surge_timers[RED if team == BLUE else BLUE] = 0.0
	objective_active = false
	objective_respawn_timer = objective_respawn_seconds
	objective_capture = 0.0
	add_kill_feed("%s captured the Shrine" % _team_name(team))
	add_circle_telegraph(objective_position, objective_radius + 34.0, Color(0.45, 0.72, 1.0, 0.8) if team == BLUE else Color(1.0, 0.28, 0.25, 0.8), 0.8, 5.0, true)

func get_core_damage_multiplier(team: int) -> float:
	return SURGE_CORE_DAMAGE_MULTIPLIER if float(surge_timers.get(team, 0.0)) > 0.0 else 1.0

func get_objective_position() -> Vector2:
	return objective_position

func should_seek_objective(actor: Node) -> bool:
	if not objective_active or actor == null or not is_instance_valid(actor):
		return false
	if actor.global_position.distance_to(objective_position) <= objective_radius * 0.7:
		return false
	var nearest_enemy := get_closest_enemy(actor, 330.0)
	return nearest_enemy == null

func add_kill_feed(message: String) -> void:
	kill_feed.push_front({
		"message": message,
		"remaining": 4.5
	})
	while kill_feed.size() > 5:
		kill_feed.pop_back()

func get_enemy_core(team: int):
	return cores.get(RED if team == BLUE else BLUE)

func get_team_spawn(team: int) -> Vector2:
	return team_spawns.get(team, Vector2.ZERO)

func get_bot_spawn(team: int, bot_name: String) -> Vector2:
	return bot_spawns.get(bot_name, get_team_spawn(team))

func get_hero_data(hero_id: String) -> Dictionary:
	return heroes_by_id.get(hero_id, heroes_by_id.get("burst_rifle", {}))

func is_inside_arena(point: Vector2) -> bool:
	return arena_rect.has_point(point)

func clamp_to_arena(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, arena_rect.position.x + 24.0, arena_rect.end.x - 24.0), clampf(point.y, arena_rect.position.y + 24.0, arena_rect.end.y - 24.0))

func resolve_body_position(point: Vector2, radius: float) -> Vector2:
	var resolved := Vector2(clampf(point.x, arena_rect.position.x + radius, arena_rect.end.x - radius), clampf(point.y, arena_rect.position.y + radius, arena_rect.end.y - radius))
	for cover in cover_rects:
		var expanded: Rect2 = cover.grow(radius)
		if not expanded.has_point(resolved):
			continue

		var left_distance := absf(resolved.x - expanded.position.x)
		var right_distance := absf(expanded.end.x - resolved.x)
		var top_distance := absf(resolved.y - expanded.position.y)
		var bottom_distance := absf(expanded.end.y - resolved.y)
		var smallest := minf(minf(left_distance, right_distance), minf(top_distance, bottom_distance))

		if smallest == left_distance:
			resolved.x = expanded.position.x
		elif smallest == right_distance:
			resolved.x = expanded.end.x
		elif smallest == top_distance:
			resolved.y = expanded.position.y
		else:
			resolved.y = expanded.end.y

	return resolved

func get_steering_direction(from: Vector2, to: Vector2, radius: float, team: int) -> Vector2:
	var direct := (to - from).normalized()
	if direct == Vector2.ZERO:
		return Vector2.ZERO

	if not _body_step_hits_cover(from, direct, radius):
		return direct

	var options := [
		direct.rotated(PI * 0.5),
		direct.rotated(-PI * 0.5),
		(direct + Vector2(0.0, 1.0 if team == BLUE else -1.0) * 0.75).normalized(),
		(direct + Vector2(0.0, -1.0 if team == BLUE else 1.0) * 0.75).normalized(),
		-direct
	]
	var best_direction := Vector2.ZERO
	var best_score := -2.0
	for option in options:
		if option == Vector2.ZERO or _body_step_hits_cover(from, option, radius):
			continue
		var score: float = option.dot(direct)
		if score > best_score:
			best_score = score
			best_direction = option
	return best_direction

func has_line_of_sight(from: Vector2, to: Vector2, radius := 4.0) -> bool:
	return not cover_blocks_point(from, to, radius)

func cover_blocks_point(from: Vector2, to: Vector2, radius := 4.0) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, ceili(distance / 20.0))
	for i in range(steps + 1):
		var point := from.lerp(to, float(i) / float(steps))
		for cover in cover_rects:
			if cover.grow(radius).has_point(point):
				return true
	return false

func projectile_crosses_cover(from: Vector2, to: Vector2, radius: float) -> bool:
	return cover_blocks_point(from, to, radius)

func _body_step_hits_cover(from: Vector2, direction: Vector2, radius: float) -> bool:
	var next_position := from + direction.normalized() * 34.0
	if not arena_rect.grow(-radius).has_point(next_position):
		return true
	for cover in cover_rects:
		if cover.grow(radius).has_point(next_position):
			return true
	return false

func _tick_telegraphs(delta: float) -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		telegraphs[i]["remaining"] = float(telegraphs[i]["remaining"]) - delta
		if float(telegraphs[i]["remaining"]) <= 0.0:
			telegraphs.remove_at(i)

func _draw_telegraphs() -> void:
	for telegraph in telegraphs:
		var remaining: float = telegraph.get("remaining", 0.0)
		var duration: float = maxf(telegraph.get("duration", 0.01), 0.01)
		var fade := clampf(remaining / duration, 0.0, 1.0)
		var color: Color = telegraph.get("color", Color.WHITE)
		color.a *= fade

		match String(telegraph.get("type", "")):
			"line":
				draw_line(telegraph["from"], telegraph["to"], color, float(telegraph.get("width", 4.0)))
			"circle":
				var center: Vector2 = telegraph["center"]
				var radius: float = telegraph["radius"]
				var width: float = telegraph.get("width", 3.0)
				if bool(telegraph.get("filled", false)):
					var fill_color := color
					fill_color.a *= 0.18
					draw_circle(center, radius, fill_color)
				draw_arc(center, radius, 0.0, TAU, 48, color, width)

func _on_player_hero_changed(hero_id: String) -> void:
	GameConfig.selected_hero_id = hero_id
	_update_ui()

func _on_core_destroyed(core) -> void:
	match_over = true
	var winner := "Red" if core.team == BLUE else "Blue"
	status_label.text = "%s wins! Press Enter to restart or Esc for menu." % winner
	end_summary_label.text = _get_match_summary(winner)

func _update_ui() -> void:
	var blue_core = cores[BLUE]
	var red_core = cores[RED]
	var hero_name: String = player.hero_data.get("name", "Unknown") if player != null else "Unknown"
	if not match_over:
		status_label.text = "%s | %s | Hero: %s | Bots: %d | Next wave: %ds" % [GameConfig.selected_mode, _format_match_time(elapsed), hero_name, bots.size(), ceili(wave_timer)]
	core_label.text = "Blue Core %d / %d    Red Core %d / %d    %s" % [blue_core.health, blue_core.max_health, red_core.health, red_core.max_health, _get_objective_text()]
	cooldown_label.text = _get_cooldown_text()
	scoreboard_label.text = _get_scoreboard_text()
	kill_feed_label.text = _get_kill_feed_text()

func _get_cooldown_text() -> String:
	if player == null:
		return ""
	if player.has_method("is_alive") and not player.is_alive():
		return "RESPAWNING IN %.1fs" % player.respawn_timer
	return "Primary %s | Dash %s | Ability %s" % [
		_format_cooldown(player.primary_timer),
		_format_cooldown(player.dash_timer),
		_format_cooldown(player.ability_timer)
	]

func _format_cooldown(timer: float) -> String:
	if timer <= 0.05:
		return "READY"
	return "%.1fs" % timer

func _get_kill_feed_text() -> String:
	if kill_feed.is_empty():
		return ""

	var lines := ["Feed"]
	for entry in kill_feed:
		lines.append(entry["message"])
	return "\n".join(lines)

func _ensure_actor_stats(actor: Node) -> void:
	var key := _get_actor_key(actor)
	if actor_stats.has(key):
		return

	actor_stats[key] = {
		"name": actor.get_actor_name() if actor.has_method("get_actor_name") else "Actor",
		"team": actor.team,
		"kills": 0,
		"deaths": 0,
		"core_damage": 0.0
	}

func _get_actor_key(actor: Node) -> String:
	return str(actor.get_instance_id())

func _get_scoreboard_text() -> String:
	var blue: Dictionary = team_stats[BLUE]
	var red: Dictionary = team_stats[RED]
	var lines := [
		"Score  Blue %dK/%dD/%dDmg/%dObj    Red %dK/%dD/%dDmg/%dObj" % [
			blue["kills"], blue["deaths"], int(blue["core_damage"]),
			blue["objectives"],
			red["kills"], red["deaths"], int(red["core_damage"]),
			red["objectives"]
		],
		"Players"
	]

	for key in actor_stats.keys():
		var stats: Dictionary = actor_stats[key]
		var team_name := "Blue" if int(stats["team"]) == BLUE else "Red"
		lines.append("%s %-11s  %d / %d / %d CoreDmg" % [
			team_name,
			stats["name"],
			stats["kills"],
			stats["deaths"],
			int(stats["core_damage"])
		])

	return "\n".join(lines)

func _get_match_summary(winner: String) -> String:
	var blue: Dictionary = team_stats[BLUE]
	var red: Dictionary = team_stats[RED]
	return "Match Summary: %s victory at %s | Blue %dK %dDmg %dObj | Red %dK %dDmg %dObj" % [
		winner,
		_format_match_time(elapsed),
		blue["kills"],
		int(blue["core_damage"]),
		blue["objectives"],
		red["kills"],
		int(red["core_damage"]),
		red["objectives"]
	]

func _format_match_time(seconds: float) -> String:
	var total_seconds := int(floor(seconds))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _tick_kill_feed(delta: float) -> void:
	for i in range(kill_feed.size() - 1, -1, -1):
		kill_feed[i]["remaining"] = float(kill_feed[i]["remaining"]) - delta
		if float(kill_feed[i]["remaining"]) <= 0.0:
			kill_feed.remove_at(i)

func _tick_objective(delta: float) -> void:
	surge_timers[BLUE] = maxf(float(surge_timers[BLUE]) - delta, 0.0)
	surge_timers[RED] = maxf(float(surge_timers[RED]) - delta, 0.0)

	if not objective_active:
		objective_respawn_timer = maxf(objective_respawn_timer - delta, 0.0)
		if objective_respawn_timer <= 0.0:
			objective_active = true
			objective_capture = 0.0
			add_kill_feed("Shrine is active")
		return

	var presence := _get_objective_presence()
	var blue_count: int = presence[BLUE]
	var red_count: int = presence[RED]

	if blue_count > 0 and red_count == 0:
		objective_capture = minf(objective_capture + delta / objective_capture_seconds, 1.0)
	elif red_count > 0 and blue_count == 0:
		objective_capture = maxf(objective_capture - delta / objective_capture_seconds, -1.0)
	else:
		objective_capture = move_toward(objective_capture, 0.0, delta / (objective_capture_seconds * 1.6))

	if objective_capture >= 1.0:
		record_objective_capture(BLUE)
	elif objective_capture <= -1.0:
		record_objective_capture(RED)

func _get_objective_presence() -> Dictionary:
	var presence := {
		BLUE: 0,
		RED: 0
	}
	for entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if entity.global_position.distance_to(objective_position) <= objective_radius:
			presence[entity.team] += 1
	return presence

func _draw_objective() -> void:
	var base_color := Color(0.7, 0.72, 0.62, 0.5)
	if not objective_active:
		base_color = Color(0.32, 0.32, 0.32, 0.35)
	elif objective_capture > 0.0:
		base_color = Color(0.25, 0.65, 1.0, 0.42)
	elif objective_capture < 0.0:
		base_color = Color(1.0, 0.28, 0.25, 0.42)

	draw_circle(objective_position, objective_radius, base_color)
	draw_arc(objective_position, objective_radius, 0.0, TAU, 64, Color(0.74, 0.76, 0.7), 3.0)
	draw_rect(Rect2(objective_position - Vector2(38.0, 38.0), Vector2(76.0, 76.0)), Color(0.12, 0.14, 0.14))
	draw_rect(Rect2(objective_position - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), Color(0.32, 0.34, 0.32))

	if objective_active:
		var progress_width := 180.0
		var progress_origin := objective_position + Vector2(-progress_width * 0.5, objective_radius + 14.0)
		draw_rect(Rect2(progress_origin, Vector2(progress_width, 8.0)), Color(0.05, 0.055, 0.06))
		if objective_capture > 0.0:
			draw_rect(Rect2(progress_origin + Vector2(progress_width * 0.5, 0.0), Vector2(progress_width * 0.5 * objective_capture, 8.0)), Color(0.25, 0.65, 1.0))
		elif objective_capture < 0.0:
			draw_rect(Rect2(progress_origin + Vector2(progress_width * 0.5 * (1.0 + objective_capture), 0.0), Vector2(progress_width * 0.5 * absf(objective_capture), 8.0)), Color(1.0, 0.28, 0.25))
	else:
		draw_string(ThemeDB.fallback_font, objective_position + Vector2(-56.0, objective_radius + 26.0), "Shrine %ds" % ceili(objective_respawn_timer), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.72, 0.72, 0.72))

func _get_objective_text() -> String:
	var blue_surge: float = float(surge_timers[BLUE])
	var red_surge: float = float(surge_timers[RED])
	if blue_surge > 0.0:
		return "Shrine: Blue Surge %.0fs" % ceili(blue_surge)
	if red_surge > 0.0:
		return "Shrine: Red Surge %.0fs" % ceili(red_surge)
	if not objective_active:
		return "Shrine respawns %.0fs" % ceili(objective_respawn_timer)
	if objective_capture > 0.05:
		return "Shrine Blue %d%%" % int(objective_capture * 100.0)
	if objective_capture < -0.05:
		return "Shrine Red %d%%" % int(absf(objective_capture) * 100.0)
	return "Shrine active"

func _team_name(team: int) -> String:
	return "Blue" if team == BLUE else "Red"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
