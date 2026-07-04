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
const CreatureScript := preload("res://scripts/sim/creature.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const LocalInputScript := preload("res://scripts/ui/local_input.gd")
const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")
const MinimapScript := preload("res://scripts/ui/minimap.gd")
const MudHutScript := preload("res://scripts/game/mud_hut.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

var entities: Array[Node] = []
var minions: Array[Node] = []
var bots: Array[Node] = []
var cores: Dictionary = {}
var player: Node
var wave_timer := 2.0
var elapsed := 0.0
var match_over := false
var telegraphs: Array[Dictionary] = []
var vfx_events: Array[Dictionary] = []
var dams: Array[Node] = []
var huts: Array[Node] = []
var huts_lost := {0: 0, 1: 0}
var hut_defend_hint_timer := 0.0
var camera: Camera2D = null

const CAMERA_LEAD_DEADZONE := 70.0
const CAMERA_LEAD_FRACTION := 0.32
const CAMERA_LEAD_MAX := 150.0
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
var terrain_map: RefCounted = TerrainMapScript.new()
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
var local_input: Node = LocalInputScript.new()
var bot_brain: RefCounted = BotBrainScript.new()

func _ready() -> void:
	_configure_mode()
	_build_ui()
	_setup_crosshair_cursor()
	_spawn_match()

func _configure_mode() -> void:
	terrain_map.configure(GameConfig.selected_mode)
	arena_rect = terrain_map.arena_rect
	cover_rects = terrain_map.get_cover_rects()
	wave_minion_offsets = terrain_map.wave_minion_offsets
	blue_core_position = terrain_map.blue_core_position
	red_core_position = terrain_map.red_core_position
	blue_minion_spawn = terrain_map.blue_minion_spawn
	red_minion_spawn = terrain_map.red_minion_spawn
	team_spawns = terrain_map.team_spawns
	bot_spawns = terrain_map.bot_spawns
	objective_position = terrain_map.objective_position
	objective_radius = terrain_map.objective_radius

	if GameConfig.selected_mode == "1v1" or GameConfig.selected_mode == "Hero Lab":
		wave_interval = 18.0
		objective_capture_seconds = 3.2
		objective_respawn_seconds = 34.0
		surge_seconds = 18.0
		camera_zoom = Vector2(2.6, 2.6)
	else:
		wave_interval = WAVE_INTERVAL
		objective_capture_seconds = OBJECTIVE_CAPTURE_SECONDS
		objective_respawn_seconds = OBJECTIVE_RESPAWN_SECONDS
		surge_seconds = SURGE_SECONDS
		camera_zoom = Vector2(2.4, 2.4)

	wave_timer = 2.0

func _physics_process(delta: float) -> void:
	if match_over:
		return

	hut_defend_hint_timer = maxf(hut_defend_hint_timer - delta, 0.0)
	if player != null and is_instance_valid(player):
		var player_frame: Resource = local_input.build_frame(player.get_global_mouse_position())
		player.set_input_frame(player_frame)
		if player_frame.is_pressed(InputFrameScript.BUTTON_HUT_DEFEND) and hut_defend_hint_timer <= 0.0 and _player_near_own_hut():
			hut_defend_hint_timer = 2.5
			add_kill_feed("Hut defense assignment needs 3+ habitat stocks (coming with the stock system)")
	for bot in bots:
		if bot != null and is_instance_valid(bot):
			bot.set_input_frame(bot_brain.build_frame(bot))

	elapsed += delta
	wave_timer -= delta
	_tick_telegraphs(delta)
	_tick_kill_feed(delta)
	_tick_objective(delta)
	if wave_timer <= 0.0:
		spawn_wave()
		wave_timer = wave_interval

	_update_ui()

func _process(delta: float) -> void:
	_update_camera_lead(delta)
	queue_redraw()

func _update_camera_lead(delta: float) -> void:
	# Supervive-style cursor-led camera: past a deadzone, the view drifts a
	# fraction of the way toward the cursor so you can see where you aim.
	if camera == null or player == null or not is_instance_valid(player):
		return
	var to_cursor: Vector2 = player.get_global_mouse_position() - player.global_position
	var lead := Vector2.ZERO
	var cursor_distance := to_cursor.length()
	if cursor_distance > CAMERA_LEAD_DEADZONE:
		lead = to_cursor.normalized() * minf((cursor_distance - CAMERA_LEAD_DEADZONE) * CAMERA_LEAD_FRACTION, CAMERA_LEAD_MAX)
	camera.offset = camera.offset.lerp(lead, minf(delta * 7.0, 1.0))

func _draw() -> void:
	_draw_terrain()
	draw_rect(arena_rect, Color(0.28, 0.33, 0.24), false, 6.0)
	_draw_objective()
	_draw_telegraphs()

	draw_string(ThemeDB.fallback_font, blue_core_position + Vector2(-42.0, -110.0), "BLUE HABITAT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.45, 0.72, 1.0))
	draw_string(ThemeDB.fallback_font, red_core_position + Vector2(-42.0, -110.0), "RED HABITAT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.45, 0.4))

func _draw_terrain() -> void:
	for layer in terrain_map.zone_layers:
		var zone := String(layer["zone"])
		for rect: Rect2 in layer["rects"]:
			draw_rect(rect, _terrain_color(zone))
			_draw_zone_detail(zone, rect)

func _draw_zone_detail(zone: String, rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(rect.position.x), int(rect.position.y)))
	match zone:
		TerrainMapScript.LAND:
			for i in int(rect.get_area() / 9000.0):
				var spot := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				var tone := rng.randf_range(-0.02, 0.03)
				draw_circle(spot, rng.randf_range(6.0, 18.0), Color(0.16 + tone, 0.2 + tone * 1.4, 0.11 + tone))
			for i in int(rect.get_area() / 26000.0):
				var tuft := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				draw_line(tuft, tuft + Vector2(-1.5, -4.0), Color(0.24, 0.32, 0.16), 1.5)
				draw_line(tuft + Vector2(2.5, 0.0), tuft + Vector2(3.5, -4.5), Color(0.22, 0.3, 0.15), 1.5)
		TerrainMapScript.WATER:
			var phase := elapsed * 0.9
			for i in int(rect.get_area() / 14000.0) + 2:
				var ripple_origin := Vector2(rng.randf_range(rect.position.x + 10.0, rect.end.x - 10.0), rng.randf_range(rect.position.y + 6.0, rect.end.y - 6.0))
				var drift := fmod(phase * 14.0 + rng.randf() * 60.0, 60.0) - 30.0
				var ripple := ripple_origin + Vector2(0.0, drift)
				if rect.grow(-4.0).has_point(ripple):
					draw_line(ripple + Vector2(-7.0, 0.0), ripple + Vector2(7.0, 0.0), Color(0.32, 0.55, 0.62, 0.5), 1.5)
		TerrainMapScript.SHALLOW:
			for i in int(rect.get_area() / 11000.0) + 1:
				var speck := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
				draw_circle(speck, rng.randf_range(2.0, 5.0), Color(0.24, 0.38, 0.3, 0.7))
			for i in int(rect.get_area() / 30000.0) + 1:
				var reed := Vector2(rng.randf_range(rect.position.x + 6.0, rect.end.x - 6.0), rng.randf_range(rect.position.y + 6.0, rect.end.y - 6.0))
				draw_line(reed, reed + Vector2(-1.0, -7.0), Color(0.28, 0.42, 0.2), 2.0)
				draw_line(reed + Vector2(3.0, 0.0), reed + Vector2(4.0, -6.0), Color(0.25, 0.38, 0.18), 2.0)
		TerrainMapScript.COVER:
			draw_rect(rect, Color(0.1, 0.16, 0.09))
			for i in maxi(int(rect.get_area() / 2600.0), 3):
				var bush := Vector2(rng.randf_range(rect.position.x + 8.0, rect.end.x - 8.0), rng.randf_range(rect.position.y + 8.0, rect.end.y - 8.0))
				draw_circle(bush, rng.randf_range(7.0, 13.0), Color(0.14 + rng.randf() * 0.04, 0.24 + rng.randf() * 0.05, 0.12))
				draw_circle(bush + Vector2(-2.0, -3.0), rng.randf_range(3.0, 6.0), Color(0.2, 0.32, 0.16))
			draw_rect(rect, Color(0.05, 0.09, 0.05), false, 2.0)
		TerrainMapScript.HABITAT_BLUE, TerrainMapScript.HABITAT_RED:
			var team_tint := Color(0.3, 0.55, 0.85, 0.5) if zone == TerrainMapScript.HABITAT_BLUE else Color(0.85, 0.4, 0.35, 0.5)
			draw_rect(rect, team_tint, false, 4.0)
			var post_gap := 28.0
			var x := rect.position.x
			while x <= rect.end.x:
				draw_rect(Rect2(Vector2(x - 2.0, rect.position.y - 5.0), Vector2(4.0, 8.0)), Color(0.32, 0.24, 0.14))
				draw_rect(Rect2(Vector2(x - 2.0, rect.end.y - 3.0), Vector2(4.0, 8.0)), Color(0.32, 0.24, 0.14))
				x += post_gap
			var y := rect.position.y
			while y <= rect.end.y:
				draw_rect(Rect2(Vector2(rect.position.x - 5.0, y - 2.0), Vector2(8.0, 4.0)), Color(0.32, 0.24, 0.14))
				draw_rect(Rect2(Vector2(rect.end.x - 3.0, y - 2.0), Vector2(8.0, 4.0)), Color(0.32, 0.24, 0.14))
				y += post_gap
			for i in 7:
				var patch := Vector2(rng.randf_range(rect.position.x + 12.0, rect.end.x - 12.0), rng.randf_range(rect.position.y + 12.0, rect.end.y - 12.0))
				draw_circle(patch, rng.randf_range(6.0, 12.0), Color(0.2, 0.19, 0.1, 0.55))

func _terrain_color(zone: String) -> Color:
	match zone:
		TerrainMapScript.HABITAT_BLUE:
			return Color(0.13, 0.17, 0.13)
		TerrainMapScript.HABITAT_RED:
			return Color(0.17, 0.14, 0.11)
		TerrainMapScript.WATER:
			return Color(0.1, 0.26, 0.34)
		TerrainMapScript.SHALLOW:
			return Color(0.16, 0.3, 0.26)
		TerrainMapScript.COVER:
			return Color(0.1, 0.16, 0.09)
		_:
			return Color(0.15, 0.19, 0.1)

func _setup_crosshair_cursor() -> void:
	var size := 25
	var center := size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white := Color(1.0, 1.0, 1.0, 0.95)
	var dark := Color(0.05, 0.05, 0.05, 0.9)
	# Four cross ticks with a gap around the center, dark-edged for contrast.
	for offset in range(4, 11):
		for axis in 2:
			for direction: int in [-1, 1]:
				var x: int = center + (offset * direction if axis == 0 else 0)
				var y: int = center + (offset * direction if axis == 1 else 0)
				img.set_pixel(x, y, white)
				if axis == 0:
					img.set_pixel(x, y - 1, dark)
					img.set_pixel(x, y + 1, dark)
				else:
					img.set_pixel(x - 1, y, dark)
					img.set_pixel(x + 1, y, dark)
	# Center dot.
	img.set_pixel(center, center, white)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(center, center))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

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
	help_label.text = "WASD move | mouse aim | LMB primary | Q / E abilities | Space flight | Esc menu"

	root.add_child(status_label)
	root.add_child(core_label)
	root.add_child(cooldown_label)
	root.add_child(scoreboard_label)
	root.add_child(kill_feed_label)
	root.add_child(end_summary_label)
	root.add_child(help_label)

	var minimap := MinimapScript.new()
	minimap.arena = self
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -252.0
	minimap.offset_top = 14.0
	minimap.offset_right = -14.0
	minimap.offset_bottom = 160.0
	canvas.add_child(minimap)

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

	for hut_team in terrain_map.hut_positions.keys():
		var lane_list: Array = terrain_map.hut_positions[hut_team]
		for lane_index in lane_list.size():
			var hut = MudHutScript.new()
			add_child(hut)
			hut.setup(self, int(hut_team), lane_index, lane_list[lane_index])
			huts.append(hut)
			register_entity(hut)

	player = CreatureScript.new()
	add_child(player)
	player.setup(self, BLUE, get_team_spawn(BLUE), GameConfig.selected_creature_id, terrain_map)
	register_entity(player)
	_spawn_bots_for_mode()

	camera = Camera2D.new()
	camera.zoom = camera_zoom
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	camera.make_current()

	spawn_wave()
	_update_ui()

func _spawn_bots_for_mode() -> void:
	if GameConfig.selected_mode == "3v3":
		_spawn_bot(BLUE, "chorus_frog", get_bot_spawn(BLUE, "Blue Guard"), "Blue Guard")
		_spawn_bot(BLUE, "beaver", get_bot_spawn(BLUE, "Blue Ward"), "Blue Ward")
		_spawn_bot(RED, "snapping_turtle", get_bot_spawn(RED, "Red Blade"), "Red Blade")
		_spawn_bot(RED, "duck", get_bot_spawn(RED, "Red Scope"), "Red Scope")
		_spawn_bot(RED, "mink", get_bot_spawn(RED, "Red Chorus"), "Red Chorus")
	else:
		_spawn_bot(RED, "mink", get_bot_spawn(RED, "Red Rival"), "Red Rival")

func _spawn_bot(team: int, creature_id: String, spawn_position: Vector2, bot_name: String) -> void:
	var bot = CreatureScript.new()
	add_child(bot)
	bot.setup(self, team, spawn_position, creature_id, terrain_map)
	bot.actor_name = bot_name
	bots.append(bot)
	register_entity(bot)

func spawn_wave() -> void:
	# Each surviving hut fields a wave that marches down its lane.
	for hut in huts:
		if hut == null or not is_instance_valid(hut) or not hut.is_alive():
			continue
		var toward_mid := Vector2(1.0 if hut.team == BLUE else -1.0, 0.0)
		var lane_anchor := Vector2(-hut.global_position.x, hut.global_position.y)
		for i in wave_minion_offsets.size():
			var minion = MinionScript.new()
			add_child(minion)
			minion.setup(self, hut.team, hut.global_position + toward_mid * (52.0 + float(i) * 22.0) + wave_minion_offsets[i] * 0.4, "lane", lane_anchor)
			minions.append(minion)
			register_entity(minion)

func track_minion(minion: Node) -> void:
	if not minions.has(minion):
		minions.append(minion)

func get_lane_destination(attacking_team: int, lane_anchor: Vector2) -> Vector2:
	# March to the nearest surviving enemy hut on this lane; if none remain,
	# push into the habitat toward the core.
	var enemy_team := RED if attacking_team == BLUE else BLUE
	var best_position := Vector2.ZERO
	var best_distance := INF
	for hut in huts:
		if hut == null or not is_instance_valid(hut) or not hut.is_alive() or hut.team != enemy_team:
			continue
		var distance: float = hut.global_position.distance_to(lane_anchor)
		if distance < best_distance:
			best_distance = distance
			best_position = hut.global_position
	if best_distance < INF:
		return best_position
	var core = cores.get(enemy_team)
	return core.global_position if core != null else lane_anchor

func can_damage_core(defending_team: int) -> bool:
	return int(huts_lost.get(defending_team, 0)) > 0 or not _team_has_huts(defending_team)

func _team_has_huts(defending_team: int) -> bool:
	for hut in huts:
		if hut != null and is_instance_valid(hut) and hut.team == defending_team:
			return true
	return int(huts_lost.get(defending_team, 0)) > 0

func on_hut_destroyed(hut: Node) -> void:
	huts.erase(hut)
	huts_lost[hut.team] = int(huts_lost.get(hut.team, 0)) + 1
	var team_name := _team_name(hut.team)
	add_kill_feed("%s mud hut destroyed — %s habitat exposed!" % [team_name, team_name])
	add_circle_telegraph(cores[hut.team].global_position, 90.0, Color(1.0, 0.6, 0.2, 0.8), 1.0, 5.0, true)

func register_dam(dam: Node) -> void:
	if not dams.has(dam):
		dams.append(dam)
	register_entity(dam)

func unregister_dam(dam: Node) -> void:
	dams.erase(dam)

func get_dam_rects() -> Array:
	var rects: Array = []
	for dam in dams:
		if dam != null and is_instance_valid(dam):
			rects.append(dam.rect)
	return rects

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

func record_vfx_event(event: Dictionary) -> void:
	vfx_events.append(event.duplicate())
	if vfx_events.size() > 240:
		vfx_events.pop_front()
	_spawn_vfx_for_event(event)
	queue_redraw()

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
			if not can_damage_core(core.team):
				_show_core_shielded(core)
				projectile.queue_free()
				return
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
		if entity.has_method("is_stealthed") and entity.is_stealthed():
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
			if not can_damage_core(core.team):
				_show_core_shielded(core)
				continue
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

func _show_core_shielded(core: Node) -> void:
	if hut_defend_hint_timer > 0.0:
		return
	hut_defend_hint_timer = 1.2
	telegraphs.append({
		"type": "float_text",
		"position": core.global_position + Vector2(-20.0, -70.0),
		"text": "SHIELDED — destroy a mud hut first",
		"color": Color(0.7, 0.85, 1.0, 0.95),
		"size": 13,
		"duration": 1.1,
		"remaining": 1.1
	})

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

func get_terrain_zone(point: Vector2) -> String:
	return terrain_map.get_zone_at(point)

func is_inside_arena(point: Vector2) -> bool:
	return arena_rect.has_point(point)

func clamp_to_arena(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, arena_rect.position.x + 24.0, arena_rect.end.x - 24.0), clampf(point.y, arena_rect.position.y + 24.0, arena_rect.end.y - 24.0))

func resolve_body_position(point: Vector2, radius: float) -> Vector2:
	var resolved := Vector2(clampf(point.x, arena_rect.position.x + radius, arena_rect.end.x - radius), clampf(point.y, arena_rect.position.y + radius, arena_rect.end.y - radius))
	for cover in cover_rects + get_dam_rects():
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
	for cover in cover_rects + get_dam_rects():
		if cover.grow(radius).has_point(next_position):
			return true
	return false

func _tick_telegraphs(delta: float) -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		var telegraph := telegraphs[i]
		if _telegraph_lost_anchor(telegraph):
			telegraphs.remove_at(i)
			continue
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
			"windup":
				_draw_windup_telegraph(telegraph, color)
			"swing":
				_draw_swing_telegraph(telegraph, color)
			"dash_trail":
				draw_line(telegraph["from"], telegraph["to"], color, float(telegraph.get("width", 7.0)))
			"tracer":
				draw_line(telegraph["from"], telegraph["to"], color, float(telegraph.get("width", 3.0)))
			"aura_follow":
				var target = telegraph.get("target", null)
				if target != null and is_instance_valid(target):
					var ring_radius: float = float(telegraph.get("ring_radius", 22.0))
					draw_arc(target.global_position, ring_radius, 0.0, TAU, 32, color, float(telegraph.get("width", 3.0)))
			"tether":
				var attacker = telegraph.get("attacker", null)
				var victim = telegraph.get("victim", null)
				if attacker != null and victim != null and is_instance_valid(attacker) and is_instance_valid(victim):
					draw_line(attacker.global_position, victim.global_position, color, float(telegraph.get("width", 4.0)))
					_draw_latch_countdown(telegraph, attacker.global_position.lerp(victim.global_position, 0.5), color)
			"float_text":
				_draw_float_text(telegraph, color, fade)
			"circle":
				var center: Vector2 = telegraph["center"]
				var radius: float = telegraph["radius"]
				var width: float = telegraph.get("width", 3.0)
				if bool(telegraph.get("filled", false)):
					var fill_color := color
					fill_color.a *= 0.18
					draw_circle(center, radius, fill_color)
				draw_arc(center, radius, 0.0, TAU, 48, color, width)

func _spawn_vfx_for_event(event: Dictionary) -> void:
	match String(event.get("type", "")):
		"windup_started":
			var actor = event.get("actor", null)
			var duration: float = float(event.get("duration", 0.1))
			telegraphs.append({
				"type": "windup",
				"actor": actor,
				"aim": event.get("aim", Vector2.RIGHT),
				"reach_px": event.get("reach_px", 24.0),
				"color": Color(1.0, 0.78, 0.22, 0.95),
				"duration": duration,
				"remaining": duration
			})
		"attack_swung":
			telegraphs.append({
				"type": "swing",
				"actor": event.get("actor", null),
				"position": event.get("position", event.get("center", Vector2.ZERO)),
				"aim": event.get("aim", Vector2.RIGHT),
				"reach_px": event.get("reach_px", 24.0),
				"color": Color(1.0, 0.93, 0.55, 0.95),
				"duration": 0.3,
				"remaining": 0.3
			})
		"hit_landed":
			var target = event.get("target", null)
			var amount: float = float(event.get("amount", 0.0))
			if target != null and is_instance_valid(target) and target.has_method("apply_render_hit_feedback"):
				target.apply_render_hit_feedback(amount)
			var heavy := bool(event.get("heavy", false))
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": str(int(round(amount))),
				"color": Color(1.0, 0.62, 0.28, 1.0) if heavy else Color(1.0, 0.96, 0.82, 1.0),
				"size": 19 if heavy else 15,
				"duration": 0.7 if heavy else 0.55,
				"remaining": 0.7 if heavy else 0.55
			})
			telegraphs.append({
				"type": "circle",
				"center": event.get("position", Vector2.ZERO),
				"radius": 16.0 if heavy else 10.0,
				"color": Color(1.0, 0.9, 0.7, 0.85),
				"width": 3.0,
				"filled": true,
				"duration": 0.16,
				"remaining": 0.16
			})
		"heal_tick":
			var heal_amount: float = float(event.get("amount", 0.0))
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "+%d" % int(ceil(heal_amount)),
				"color": Color(0.32, 1.0, 0.48, 1.0),
				"duration": 0.5,
				"remaining": 0.5
			})
		"dash_started":
			var dash_duration: float = float(event.get("duration", 0.12))
			telegraphs.append({
				"type": "dash_trail",
				"from": event.get("from", Vector2.ZERO),
				"to": event.get("to", Vector2.ZERO),
				"color": Color(0.65, 0.95, 1.0, 0.65),
				"duration": maxf(dash_duration, 0.12),
				"remaining": maxf(dash_duration, 0.12),
				"width": 7.0
			})
		"projectile_tracer":
			telegraphs.append({
				"type": "tracer",
				"from": event.get("from", Vector2.ZERO),
				"to": event.get("to", Vector2.ZERO),
				"color": Color(0.92, 0.88, 0.5, 0.85),
				"duration": float(event.get("duration", 0.18)),
				"remaining": float(event.get("duration", 0.18)),
				"width": 3.0
			})
		"aura_applied":
			var target = event.get("target", null)
			var aura_duration: float = float(event.get("duration", 0.1))
			telegraphs.append({
				"type": "aura_follow",
				"target": target,
				"ring_radius": _aura_ring_radius(target),
				"color": _aura_color(String(event.get("source_ability", "")), bool(event.get("friendly", true))),
				"duration": aura_duration,
				"remaining": aura_duration,
				"width": 3.0
			})
		"latch_started":
			var duration: float = float(event.get("duration", 0.1))
			telegraphs.append({
				"type": "tether",
				"attacker": event.get("attacker", null),
				"victim": event.get("victim", null),
				"source_ability": event.get("source_ability", ""),
				"duration": duration,
				"remaining": duration,
				"execute_after": event.get("execute_after", 0.0),
				"color": Color(1.0, 0.28, 0.2, 0.9),
				"width": 4.0
			})
		"spiked":
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "SPIKED!",
				"color": Color(1.0, 0.45, 0.2, 1.0),
				"size": 18,
				"duration": 0.8,
				"remaining": 0.8
			})
			telegraphs.append({
				"type": "circle",
				"center": event.get("position", Vector2.ZERO),
				"radius": 22.0,
				"color": Color(1.0, 0.5, 0.2, 0.9),
				"width": 4.0,
				"filled": true,
				"duration": 0.3,
				"remaining": 0.3
			})
		"attack_dodged":
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "MISS",
				"color": Color(0.75, 0.8, 0.9, 0.9),
				"size": 13,
				"duration": 0.5,
				"remaining": 0.5
			})
		"latch_ended":
			_remove_tether(event.get("attacker", null), event.get("victim", null))

func _telegraph_lost_anchor(telegraph: Dictionary) -> bool:
	match String(telegraph.get("type", "")):
		"windup":
			var actor = telegraph.get("actor", null)
			return actor == null or not is_instance_valid(actor)
		"aura_follow":
			var target = telegraph.get("target", null)
			return target == null or not is_instance_valid(target)
		"tether":
			var attacker = telegraph.get("attacker", null)
			var victim = telegraph.get("victim", null)
			return attacker == null or victim == null or not is_instance_valid(attacker) or not is_instance_valid(victim)
	return false

func _remove_tether(attacker: Variant, victim: Variant) -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		var telegraph := telegraphs[i]
		if String(telegraph.get("type", "")) != "tether":
			continue
		if telegraph.get("attacker", null) == attacker and telegraph.get("victim", null) == victim:
			telegraphs.remove_at(i)

func _draw_windup_telegraph(telegraph: Dictionary, color: Color) -> void:
	var actor = telegraph.get("actor", null)
	if actor == null or not is_instance_valid(actor):
		return
	var aim: Vector2 = telegraph.get("aim", Vector2.RIGHT)
	if actor.get("last_aim_direction") != null:
		aim = actor.last_aim_direction
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var duration: float = maxf(float(telegraph.get("duration", 0.01)), 0.01)
	var remaining: float = float(telegraph.get("remaining", 0.0))
	var progress := 1.0 - clampf(remaining / duration, 0.0, 1.0)
	var reach: float = float(telegraph.get("reach_px", 24.0))
	var danger := Color(1.0, 0.42, 0.2, 0.35 + progress * 0.55)
	_draw_cone(actor.global_position, aim.normalized(), reach, PI * 0.52, Color(1.0, 0.75, 0.3, 0.3))
	_draw_cone(actor.global_position, aim.normalized(), reach * progress, PI * 0.52, danger)

func _draw_swing_telegraph(telegraph: Dictionary, color: Color) -> void:
	var actor = telegraph.get("actor", null)
	var origin: Vector2 = actor.global_position if actor != null and is_instance_valid(actor) else telegraph.get("position", Vector2.ZERO)
	var aim: Vector2 = telegraph.get("aim", Vector2.RIGHT)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var reach: float = float(telegraph.get("reach_px", 24.0))
	_draw_cone(origin, aim.normalized(), reach, PI * 0.7, color)

func _draw_cone(origin: Vector2, aim: Vector2, reach: float, spread: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(origin)
	var steps := 10
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := -spread * 0.5 + spread * t
		points.append(origin + aim.rotated(angle) * reach)
	var fill := color
	fill.a *= 0.34
	draw_colored_polygon(points, fill)
	draw_arc(origin, reach, aim.angle() - spread * 0.5, aim.angle() + spread * 0.5, 18, color, 5.0)

func _draw_latch_countdown(telegraph: Dictionary, center: Vector2, color: Color) -> void:
	var duration: float = maxf(float(telegraph.get("duration", 0.1)), 0.1)
	var remaining: float = clampf(float(telegraph.get("remaining", 0.0)), 0.0, duration)
	var radius := 7.0
	draw_circle(center, radius + 2.0, Color(0.04, 0.02, 0.02, color.a))
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * (remaining / duration), 20, color, 3.0)

func _draw_float_text(telegraph: Dictionary, color: Color, fade: float) -> void:
	var duration: float = maxf(float(telegraph.get("duration", 0.5)), 0.01)
	var remaining: float = float(telegraph.get("remaining", 0.0))
	var progress := 1.0 - clampf(remaining / duration, 0.0, 1.0)
	var position: Vector2 = telegraph.get("position", Vector2.ZERO) + Vector2(-8.0, -18.0 - progress * 24.0)
	var size: int = int(telegraph.get("size", 15))
	color.a *= fade
	draw_string(ThemeDB.fallback_font, position + Vector2(1.5, 1.5), String(telegraph.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(0.02, 0.02, 0.02, color.a))
	draw_string(ThemeDB.fallback_font, position, String(telegraph.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _aura_ring_radius(target: Variant) -> float:
	if target != null and is_instance_valid(target) and target.get("body_radius") != null:
		return float(target.body_radius) + 9.0
	return 22.0

func _aura_color(source_ability: String, friendly: bool) -> Color:
	if source_ability == "Scent Marking":
		return Color(0.95, 0.82, 0.35, 0.82)
	if friendly:
		return Color(0.35, 1.0, 0.55, 0.82)
	return Color(0.82, 0.45, 1.0, 0.82)

func _on_core_destroyed(core) -> void:
	match_over = true
	var winner := "Red" if core.team == BLUE else "Blue"
	status_label.text = "%s wins! Press Enter to restart or Esc for menu." % winner
	end_summary_label.text = _get_match_summary(winner)

func _update_ui() -> void:
	var blue_core = cores[BLUE]
	var red_core = cores[RED]
	var creature_name: String = player.creature_data.get("name", "Unknown") if player != null else "Unknown"
	if not match_over:
		status_label.text = "%s | %s | Creature: %s | Bots: %d | Next wave: %ds" % [GameConfig.selected_mode, _format_match_time(elapsed), creature_name, bots.size(), ceili(wave_timer)]
	core_label.text = "Blue Core %d / %d    Red Core %d / %d    %s" % [blue_core.health, blue_core.max_health, red_core.health, red_core.max_health, _get_objective_text()]
	cooldown_label.text = _get_cooldown_text()
	scoreboard_label.text = _get_scoreboard_text()
	kill_feed_label.text = _get_kill_feed_text()

func _get_cooldown_text() -> String:
	if player == null:
		return ""
	if player.has_method("is_alive") and not player.is_alive():
		return "RESPAWNING"
	return "Primary %s | Q %s | E %s | Swim %d%% | Flight %d%% | %s" % [
		_format_cooldown(player.primary_timer),
		_format_cooldown(player.q_timer),
		_format_cooldown(player.e_timer),
		int(player.get_swim_ratio() * 100.0),
		int(player.get_flight_ratio() * 100.0),
		"LATCH" if player.has_latch() else "free"
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

func _player_near_own_hut() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	for hut in huts:
		if hut != null and is_instance_valid(hut) and hut.team == player.team and hut.global_position.distance_to(player.global_position) < 110.0:
			return true
	return false

func _team_name(team: int) -> String:
	return "Blue" if team == BLUE else "Red"

func _input(event: InputEvent) -> void:
	if match_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
