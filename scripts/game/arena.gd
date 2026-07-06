extends Node2D

const BLUE := 0
const RED := 1
const ARENA_RECT := Rect2(Vector2(-1120.0, -620.0), Vector2(2240.0, 1240.0))
const WAVE_INTERVAL := 20.0
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
const SquadHudScript := preload("res://scripts/ui/squad_hud.gd")
const MudHutScript := preload("res://scripts/game/mud_hut.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainLayerScript := preload("res://scripts/game/terrain_layer.gd")
const WaterLayerScript := preload("res://scripts/game/water_layer.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const HurtboxScript := preload("res://scripts/sim/combat/hurtbox.gd")
const PerfOverlayScript := preload("res://scripts/ui/perf_overlay.gd")
const PerfStats := preload("res://scripts/game/perf_stats.gd")
const AbilityBarScript := preload("res://scripts/ui/ability_bar.gd")
const CreatureInfoPanelScript := preload("res://scripts/ui/creature_info_panel.gd")
const StockManagerScript := preload("res://scripts/game/stock_manager.gd")
const FoodSourceScript := preload("res://scripts/game/food_source.gd")

const PLAYABLE_CREATURE_POOL := ["snapping_turtle", "chorus_frog", "mink", "beaver", "owl", "duck", "bullfrog", "cane_toad", "crayfish", "water_shrew", "newt", "great_blue_heron", "kingfisher", "water_snake", "alligator", "wolf_spider", "firefly"]
const SQUAD_COMMAND_FARM := "farm"
const SQUAD_COMMAND_FOLLOW := "follow"
const SQUAD_COMMAND_AGGRO := "aggro"
const SQUAD_COMMAND_SECONDS := 10.0
const SQUAD_SWITCH_FEEDBACK_SECONDS := 0.85
const SQUAD_FOLLOW_RADIUS := 5.0 * SimConstants.UNIT_PX
const SQUAD_DANGER_HEALTH_RATIO := 0.28
const SQUAD_DANGER_RANGE := 360.0
const DAY_LENGTH_SEC := 120.0
const FOOD_EAT_RADIUS_PAD := 8.0

var entities: Array[Node] = []
var minions: Array[Node] = []
var bots: Array[Node] = []
var player_squad: Array[Node] = []
var active_squad_index := 0
var squad_command := SQUAD_COMMAND_FARM
var squad_command_timer := 0.0
var squad_aggro_target: Node = null
var squad_switch_feedback_timer := 0.0
var squad_switch_feedback_state := ""
var squad_switch_feedback_slot_index := -1
var cores: Dictionary = {}
var player: Node
var wave_timer := 2.0
var elapsed := 0.0
var match_over := false
var telegraphs: Array[Dictionary] = []
var vfx_events: Array[Dictionary] = []
var dams: Array[Node] = []
var huts: Array[Node] = []
var food_sources: Array[Node] = []
var huts_lost := {0: 0, 1: 0}
var hut_defend_hint_timer := 0.0
var habitat_deposit_feedback_timer := 0.0
var habitat_deposit_prompt_state := ""
var day_index := 1
var day_timer := 0.0
var ui_refresh_accumulator := 0.0
var camera: Camera2D = null

const CAMERA_LEAD_DEADZONE := 70.0
const CAMERA_LEAD_FRACTION := 0.32
const CAMERA_LEAD_MAX := 150.0
var actor_stats: Dictionary = {}
var team_stats := {
	BLUE: {"kills": 0, "deaths": 0, "core_damage": 0.0},
	RED: {"kills": 0, "deaths": 0, "core_damage": 0.0}
}
var kill_feed: Array[Dictionary] = []
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
var camera_zoom := Vector2(0.9, 0.9)

var status_label: Label
var core_label: Label
var cooldown_label: Label
var ability_bar: Control
var info_panel: Control
var scoreboard_label: Label
var kill_feed_label: Label
var end_summary_label: Label
var help_label: Label
var squad_hud: Control = null
var local_input: Node = LocalInputScript.new()
var bot_brain: RefCounted = BotBrainScript.new()
var match_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stock_manager: RefCounted = StockManagerScript.new()

func _ready() -> void:
	_configure_mode()
	var terrain_layer = TerrainLayerScript.new()
	add_child(terrain_layer)
	terrain_layer.setup(terrain_map)
	var water_layer = WaterLayerScript.new()
	add_child(water_layer)
	water_layer.setup(terrain_map)
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

	if GameConfig.selected_mode == "1v1" or GameConfig.selected_mode == "Hero Lab":
		wave_interval = 18.0
		camera_zoom = Vector2(2.6, 2.6)
	else:
		wave_interval = WAVE_INTERVAL
		camera_zoom = Vector2(2.4, 2.4)

	wave_timer = 2.0

func _physics_process(delta: float) -> void:
	if match_over:
		return
	var perf_start := Time.get_ticks_usec() if PerfStats.enabled else 0

	hut_defend_hint_timer = maxf(hut_defend_hint_timer - delta, 0.0)
	habitat_deposit_feedback_timer = maxf(habitat_deposit_feedback_timer - delta, 0.0)
	if habitat_deposit_feedback_timer <= 0.0:
		habitat_deposit_prompt_state = ""
	squad_switch_feedback_timer = maxf(squad_switch_feedback_timer - delta, 0.0)
	if squad_switch_feedback_timer <= 0.0:
		squad_switch_feedback_state = ""
		squad_switch_feedback_slot_index = -1
	_tick_squad_command(delta)
	_tick_day_cycle(delta)
	stock_manager.tick_breeding_cues(delta)
	if _is_1v1_trio_mode():
		_feed_player_squad_inputs()
	elif player != null and is_instance_valid(player):
		var player_frame: Resource = local_input.build_frame(player.get_global_mouse_position())
		player.set_input_frame(player_frame)
		if player_frame.is_pressed(InputFrameScript.BUTTON_HUT_DEFEND) and hut_defend_hint_timer <= 0.0 and _player_near_own_hut():
			hut_defend_hint_timer = 2.5
			add_kill_feed("Hut defense assignment needs a reserve habitat upgrade")
	var perf_bots_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	for bot in bots:
		if bot != null and is_instance_valid(bot) and bot.is_alive():
			bot.set_input_frame(bot_brain.build_frame(bot))
	if PerfStats.enabled:
		PerfStats.add("bot_frames", int(Time.get_ticks_usec() - perf_bots_start))

	elapsed += delta
	wave_timer -= delta
	_tick_telegraphs(delta)
	_tick_kill_feed(delta)
	if wave_timer <= 0.0:
		spawn_wave()
		wave_timer = wave_interval

	ui_refresh_accumulator += delta
	if ui_refresh_accumulator >= 0.2:
		ui_refresh_accumulator = 0.0
		_update_ui()
	resolve_body_separation()
	if PerfStats.enabled:
		PerfStats.add("arena_tick", int(Time.get_ticks_usec() - perf_start))

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
	# Retired mid-objective holdover: Battle Bog's center belongs to
	# contested water while huts and habitats carry the match contract.
	_draw_telegraphs()

	draw_string(ThemeDB.fallback_font, blue_core_position + Vector2(-42.0, -110.0), "BLUE HABITAT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.45, 0.72, 1.0))
	draw_string(ThemeDB.fallback_font, red_core_position + Vector2(-42.0, -110.0), "RED HABITAT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.45, 0.4))
	_draw_habitat_stock_visuals()
	_draw_breeding_cues()
	_draw_squad_badges()

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
	# Full controls + ability text live in the hold-P panel now (UI pass);
	# the old cooldown text line is superseded by the ability bar but kept
	# updated (hidden) for check-script compatibility.
	help_label.text = "hold P — creature info & controls"
	cooldown_label.visible = false

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

	ability_bar = AbilityBarScript.new()
	ability_bar.arena = self
	ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ability_bar.offset_left = -300.0
	ability_bar.offset_right = 300.0
	ability_bar.offset_top = -78.0
	ability_bar.offset_bottom = -14.0
	canvas.add_child(ability_bar)

	info_panel = CreatureInfoPanelScript.new()
	info_panel.arena = self
	info_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	info_panel.offset_left = 24.0
	info_panel.offset_top = -220.0
	info_panel.offset_right = 560.0
	info_panel.offset_bottom = 220.0
	canvas.add_child(info_panel)

	var perf_overlay := PerfOverlayScript.new()
	perf_overlay.arena = self
	perf_overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	perf_overlay.offset_left = -420.0
	perf_overlay.offset_top = -34.0
	perf_overlay.offset_right = -14.0
	perf_overlay.offset_bottom = -14.0
	canvas.add_child(perf_overlay)

	squad_hud = SquadHudScript.new()
	squad_hud.set("arena", self)
	squad_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	squad_hud.offset_left = 18.0
	squad_hud.offset_top = -194.0
	squad_hud.offset_right = 410.0
	squad_hud.offset_bottom = -18.0
	canvas.add_child(squad_hud)

func _spawn_match() -> void:
	_seed_match_rng()
	stock_manager.reset()
	day_index = 1
	day_timer = 0.0

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

	if _is_1v1_trio_mode():
		_spawn_player_squad()
	else:
		player = CreatureScript.new()
		add_child(player)
		player.setup(self, BLUE, get_team_spawn(BLUE), GameConfig.selected_creature_id, terrain_map)
		register_entity(player)
	_spawn_bots_for_mode()

	camera = Camera2D.new()
	camera.zoom = camera_zoom
	camera.position_smoothing_enabled = true
	_attach_camera_to_player()

	_refresh_food_sources()
	spawn_wave()
	_update_ui()

func _spawn_bots_for_mode() -> void:
	if GameConfig.selected_mode == "3v3":
		var ally_pool := _shuffled_creature_pool(PLAYABLE_CREATURE_POOL)
		ally_pool.erase(GameConfig.selected_creature_id)
		var enemy_pool := _shuffled_creature_pool(PLAYABLE_CREATURE_POOL)
		_spawn_bot(BLUE, ally_pool[0], get_bot_spawn(BLUE, "Blue Guard"), "Blue Guard")
		_spawn_bot(BLUE, ally_pool[1], get_bot_spawn(BLUE, "Blue Ward"), "Blue Ward")
		_spawn_bot(RED, enemy_pool[0], get_bot_spawn(RED, "Red Blade"), "Red Blade")
		_spawn_bot(RED, enemy_pool[1], get_bot_spawn(RED, "Red Scope"), "Red Scope")
		_spawn_bot(RED, enemy_pool[2], get_bot_spawn(RED, "Red Chorus"), "Red Chorus")
	elif _is_1v1_trio_mode():
		var enemy_pool := _shuffled_creature_pool(PLAYABLE_CREATURE_POOL)
		var red_spawn := get_team_spawn(RED)
		var red_names := ["Red Claw", "Red Reed", "Red Fang"]
		for i in 3:
			var bot := _spawn_bot(RED, enemy_pool[i], red_spawn + _squad_spawn_offset(i, RED), red_names[i])
			stock_manager.register_slot(RED, i, enemy_pool[i], bot)
	else:
		_spawn_bot(RED, PLAYABLE_CREATURE_POOL[match_rng.randi_range(0, PLAYABLE_CREATURE_POOL.size() - 1)], get_bot_spawn(RED, "Red Rival"), "Red Rival")

func _is_1v1_trio_mode() -> bool:
	return GameConfig.selected_mode == "1v1"

func get_squad_follow_radius() -> float:
	return SQUAD_FOLLOW_RADIUS

func get_trio_hud_rows(team: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not _is_1v1_trio_mode() or stock_manager == null or not stock_manager.has_method("get_team_slots"):
		return rows
	for slot: Dictionary in stock_manager.get_team_slots(team):
		rows.append(_build_trio_hud_row(slot))
	return rows

func get_squad_hud_data() -> Dictionary:
	return {
		"enabled": _is_1v1_trio_mode(),
		"own_team": BLUE,
		"enemy_team": RED,
		"command": squad_command,
		"command_timer": squad_command_timer,
		"own": get_trio_hud_rows(BLUE),
		"enemy": get_trio_hud_rows(RED),
		"switch_feedback": get_squad_switch_feedback_state(),
		"deposit_prompt": get_deposit_prompt_state()
	}

func get_squad_switch_feedback_state() -> Dictionary:
	return {
		"state": squad_switch_feedback_state if squad_switch_feedback_timer > 0.0 else "idle",
		"slot_index": squad_switch_feedback_slot_index,
		"timer": squad_switch_feedback_timer
	}

func get_deposit_prompt_state() -> Dictionary:
	var state := "hidden"
	var visible := false
	var in_home := false
	var near_home := false
	if _is_1v1_trio_mode() and player != null and is_instance_valid(player) and player.has_method("is_alive") and player.is_alive():
		in_home = _is_actor_in_home_habitat(player)
		var rect: Rect2 = terrain_map.get_team_habitat_rect(player.team)
		near_home = in_home or (rect.size.x > 0.0 and rect.size.y > 0.0 and rect.grow(96.0).has_point(player.global_position))
		if habitat_deposit_feedback_timer > 0.0 and not habitat_deposit_prompt_state.is_empty():
			state = habitat_deposit_prompt_state
		elif in_home:
			state = "ready" if not player.has_method("is_satiated") or player.is_satiated() else "needs_food"
		elif near_home:
			state = "near"
		visible = state != "hidden"
	return {
		"state": state,
		"visible": visible,
		"timer": habitat_deposit_feedback_timer,
		"in_home_habitat": in_home,
		"near_home_habitat": near_home
	}

func _build_trio_hud_row(slot: Dictionary) -> Dictionary:
	var actor: Node = slot.get("actor", null)
	var team := int(slot.get("team", -1))
	var creature_id := String(slot.get("creature_id", ""))
	var name := creature_id
	var hp_ratio := 0.0
	if actor != null and is_instance_valid(actor):
		var data_value = actor.get("creature_data")
		if typeof(data_value) == TYPE_DICTIONARY:
			var creature_data: Dictionary = data_value
			name = String(creature_data.get("name", creature_id))
		elif actor.has_method("get_actor_name"):
			name = actor.get_actor_name()
		if actor.has_method("is_alive") and actor.is_alive():
			hp_ratio = _health_ratio(actor)
	var state := String(slot.get("state", StockManagerScript.STATE_FIELD))
	if state == StockManagerScript.STATE_FIELD and actor != null and is_instance_valid(actor) and actor.has_method("is_alive") and not actor.is_alive():
		state = StockManagerScript.STATE_RESPAWNING
	return {
		"team": team,
		"slot_index": int(slot.get("slot_index", -1)),
		"creature_id": creature_id,
		"name": name,
		"active": team == BLUE and actor != null and actor == player,
		"hp_ratio": hp_ratio,
		"stocks": int(slot.get("stocks_remaining", StockManagerScript.MAX_STOCKS)),
		"max_stocks": int(slot.get("max_stocks", StockManagerScript.MAX_STOCKS)),
		"state": state
	}

func _spawn_player_squad() -> void:
	player_squad.clear()
	active_squad_index = 0
	squad_command = SQUAD_COMMAND_FARM
	squad_command_timer = 0.0
	squad_aggro_target = null
	squad_switch_feedback_timer = 0.0
	squad_switch_feedback_state = ""
	squad_switch_feedback_slot_index = -1

	var squad_ids: Array[String] = GameConfig.get_selected_squad_ids() if GameConfig.has_method("get_selected_squad_ids") else [GameConfig.selected_creature_id, "chorus_frog", "mink"]
	var blue_spawn := get_team_spawn(BLUE)
	for i in 3:
		var member = CreatureScript.new()
		add_child(member)
		member.setup(self, BLUE, blue_spawn + _squad_spawn_offset(i, BLUE), squad_ids[i], terrain_map)
		member.actor_name = "Blue %d %s" % [i + 1, member.creature_data.get("name", member.creature_id)]
		player_squad.append(member)
		register_entity(member)
		stock_manager.register_slot(BLUE, i, squad_ids[i], member)
	player = player_squad[active_squad_index]

func _squad_spawn_offset(index: int, team: int) -> Vector2:
	var y_offsets := [-42.0, 0.0, 42.0]
	var x := -28.0 if team == BLUE else 28.0
	return Vector2(x, y_offsets[index])

func _attach_camera_to_player() -> void:
	if camera == null or player == null or not is_instance_valid(player):
		return
	var parent := camera.get_parent()
	if parent != null:
		parent.remove_child(camera)
	player.add_child(camera)
	camera.position = Vector2.ZERO
	camera.make_current()

func _seed_match_rng() -> void:
	match_rng.seed = int(("%s:%s" % [GameConfig.selected_mode, GameConfig.selected_creature_id]).hash())

func _shuffled_creature_pool(source_pool: Array) -> Array:
	var shuffled := source_pool.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := match_rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	return shuffled

func _spawn_bot(team: int, creature_id: String, spawn_position: Vector2, bot_name: String) -> Node:
	var bot = CreatureScript.new()
	add_child(bot)
	bot.setup(self, team, spawn_position, creature_id, terrain_map)
	bot.actor_name = bot_name
	bots.append(bot)
	register_entity(bot)
	return bot

func _feed_player_squad_inputs() -> void:
	_select_live_active_if_needed()
	if player != null and is_instance_valid(player) and player.is_alive():
		var player_frame: Resource = local_input.build_frame(player.get_global_mouse_position())
		player.set_input_frame(player_frame)
		if player_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT):
			_try_manual_habitat_deposit(player)
		if player_frame.is_pressed(InputFrameScript.BUTTON_HUT_DEFEND) and hut_defend_hint_timer <= 0.0 and _player_near_own_hut():
			hut_defend_hint_timer = 2.5
			add_kill_feed("Hut defense assignment needs a reserve habitat upgrade")
	for member in player_squad:
		if member == null or not is_instance_valid(member) or member == player:
			continue
		if member.is_alive():
			member.set_input_frame(_build_squad_ai_frame(member))

func _select_live_active_if_needed() -> void:
	if player != null and is_instance_valid(player) and player.is_alive():
		return
	var best_index := -1
	var best_health_ratio := -1.0
	for i in player_squad.size():
		var member: Node = player_squad[i]
		if member == null or not is_instance_valid(member) or not member.is_alive():
			continue
		var ratio := _health_ratio(member)
		if ratio > best_health_ratio:
			best_health_ratio = ratio
			best_index = i
	if best_index >= 0:
		_set_active_squad_index(best_index, false)

func _build_squad_ai_frame(actor: Node) -> Resource:
	if _is_severe_danger(actor):
		return _retreat_frame(actor)
	match squad_command:
		SQUAD_COMMAND_FOLLOW:
			return _follow_active_frame(actor)
		SQUAD_COMMAND_AGGRO:
			var target := squad_aggro_target if _valid_target(squad_aggro_target) else _closest_enemy_creature(actor, SQUAD_DANGER_RANGE * 1.8)
			if target != null:
				return _direct_target_frame(actor, target, true)
			return _follow_active_frame(actor)
		_:
			return _safe_farm_frame(actor)

func _follow_active_frame(actor: Node) -> Resource:
	if player == null or not is_instance_valid(player):
		return _safe_farm_frame(actor)
	var distance: float = actor.global_position.distance_to(player.global_position)
	if distance <= SQUAD_FOLLOW_RADIUS:
		var frame := InputFrameScript.new()
		frame.aim = player.global_position
		return frame
	return _move_to_frame(actor, player.global_position, SQUAD_FOLLOW_RADIUS, player.global_position)

func _safe_farm_frame(actor: Node) -> Resource:
	# Proactive when uncontrolled (2026-07-05 playtest: 'in gather they just
	# stand still in spawn'): push out and clear the nearest wave, but never
	# contest a point an enemy creature is holding — the frontline hut line
	# is the risk ceiling, and _is_severe_danger retreat still overrides all.
	var minion_target := _closest_enemy_minion(actor, 900.0)
	if minion_target != null and not _farm_point_contested(actor, minion_target.global_position):
		return _direct_target_frame(actor, minion_target, false)
	var frontline := _squad_frontline_point(actor)
	return _move_to_frame(actor, frontline, 70.0, frontline)

# Hold just behind an alive friendly hut (lane split by squad slot) —
# forward enough to meet waves, safe enough to disengage.
func _squad_frontline_point(actor: Node) -> Vector2:
	var own_huts: Array[Node] = []
	for hut in huts:
		if hut != null and is_instance_valid(hut) and hut.is_alive() and hut.team == actor.team:
			own_huts.append(hut)
	if own_huts.is_empty():
		return _safe_patrol_point(actor)
	var slot: int = maxi(player_squad.find(actor), 0)
	var hut: Node = own_huts[slot % own_huts.size()]
	return hut.global_position + Vector2(-90.0 if actor.team == BLUE else 90.0, 0.0)

func _farm_point_contested(actor: Node, point: Vector2) -> bool:
	for entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		var creature_id_value: Variant = entity.get("creature_id")
		if creature_id_value == null or String(creature_id_value) == "":
			continue
		if int(entity.get("team")) == actor.team:
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if entity.global_position.distance_to(point) < SQUAD_DANGER_RANGE:
			return true
	return false

func _retreat_frame(actor: Node) -> Resource:
	var point := _retreat_point(actor)
	var threat := _closest_enemy_creature(actor, SQUAD_DANGER_RANGE)
	return _move_to_frame(actor, point, 36.0, threat.global_position if threat != null else point)

func _direct_target_frame(actor: Node, target: Node, allow_abilities: bool) -> Resource:
	var frame := _move_to_frame(actor, target.global_position, bot_brain._preferred_range(actor) + _target_radius(target), target.global_position)
	var distance: float = actor.global_position.distance_to(target.global_position)
	if distance <= bot_brain._primary_range(actor, target):
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
		if allow_abilities:
			bot_brain._hook(actor).apply(actor, target, frame, distance)
	return frame

func _move_to_frame(actor: Node, point: Vector2, hold_radius: float, aim_point: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.aim = aim_point
	var offset: Vector2 = point - actor.global_position
	var distance := offset.length()
	if distance > hold_radius:
		var direction := offset.normalized()
		frame.move = get_steering_direction(actor.global_position, point, actor.body_radius, actor.team)
		if frame.move == Vector2.ZERO:
			frame.move = direction
	return frame

func _is_severe_danger(actor: Node) -> bool:
	return _health_ratio(actor) <= SQUAD_DANGER_HEALTH_RATIO and _closest_enemy_creature(actor, SQUAD_DANGER_RANGE) != null

func _health_ratio(target: Node) -> float:
	var max_health := float(target.get("max_health") if target.get("max_health") != null else 0.0)
	if max_health <= 0.0:
		return 1.0
	return clampf(float(target.health) / max_health, 0.0, 1.0)

func _closest_enemy_creature(actor: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance := max_distance
	for entity in entities:
		if not _valid_target(entity) or entity.team == actor.team:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_stealthed") and entity.is_stealthed():
			continue
		var distance: float = actor.global_position.distance_to(entity.global_position)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _closest_enemy_minion(actor: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance := max_distance
	for minion in minions:
		if not _valid_target(minion) or minion.team == actor.team:
			continue
		var distance: float = actor.global_position.distance_to(minion.global_position)
		if distance < closest_distance:
			closest = minion
			closest_distance = distance
	return closest

func _valid_target(target: Variant) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_alive") and not target.is_alive():
		return false
	if target.get("health") != null and float(target.health) <= 0.0:
		return false
	return true

func _target_radius(target: Node) -> float:
	if target.get("body_radius") != null:
		return float(target.body_radius)
	if target.get("radius") != null:
		return float(target.radius)
	return 0.0

func _retreat_point(actor: Node) -> Vector2:
	var best_point: Vector2 = get_team_spawn(actor.team)
	var best_distance: float = actor.global_position.distance_to(best_point)
	for hut in huts:
		if not _valid_target(hut) or hut.team != actor.team:
			continue
		var distance: float = actor.global_position.distance_to(hut.global_position)
		if distance < best_distance:
			best_point = hut.global_position
			best_distance = distance
	return best_point

func _safe_patrol_point(actor: Node) -> Vector2:
	var spawn := get_team_spawn(actor.team)
	var lane_y := 56.0 * (1.0 if active_squad_index % 2 == 0 else -1.0)
	return spawn + Vector2(150.0 if actor.team == BLUE else -150.0, lane_y)

func _tick_squad_command(delta: float) -> void:
	if not _is_1v1_trio_mode():
		return
	if squad_command == SQUAD_COMMAND_FOLLOW or squad_command == SQUAD_COMMAND_AGGRO:
		squad_command_timer = maxf(squad_command_timer - delta, 0.0)
		if squad_command_timer <= 0.0:
			_issue_squad_farm(false)

func _set_squad_switch_feedback(state: String, slot_index: int) -> void:
	squad_switch_feedback_state = state
	squad_switch_feedback_slot_index = slot_index
	squad_switch_feedback_timer = SQUAD_SWITCH_FEEDBACK_SECONDS

func _set_active_squad_index(index: int, announce := true) -> void:
	if index < 0 or index >= player_squad.size():
		_set_squad_switch_feedback("invalid", index)
		return
	var next_player: Node = player_squad[index]
	if next_player == null or not is_instance_valid(next_player) or not next_player.is_alive():
		_set_squad_switch_feedback("respawning", index)
		if announce:
			add_kill_feed("Squad slot %d is respawning" % (index + 1))
		return
	active_squad_index = index
	player = next_player
	_set_squad_switch_feedback("active", index)
	_attach_camera_to_player()
	if announce:
		add_kill_feed("Controlling %d: %s" % [index + 1, player.get_actor_name()])
	_update_ui()

func _issue_squad_follow(announce := true) -> void:
	if not _is_1v1_trio_mode():
		return
	squad_command = SQUAD_COMMAND_FOLLOW
	squad_command_timer = SQUAD_COMMAND_SECONDS
	squad_aggro_target = null
	if announce:
		add_kill_feed("Squad regrouping on active creature")
		if player != null and is_instance_valid(player):
			add_circle_telegraph(player.global_position, SQUAD_FOLLOW_RADIUS, Color(0.45, 0.75, 1.0, 0.75), 0.35, 3.0, false)

func _issue_squad_farm(announce := true) -> void:
	if not _is_1v1_trio_mode():
		return
	squad_command = SQUAD_COMMAND_FARM
	squad_command_timer = 0.0
	squad_aggro_target = null
	if announce:
		add_kill_feed("Squad farming safely")

func _issue_squad_aggro(target: Node) -> void:
	if not _is_1v1_trio_mode() or squad_command != SQUAD_COMMAND_FOLLOW or squad_command_timer <= 0.0:
		return
	if not _valid_target(target) or (player != null and target.team == player.team):
		return
	if not target.has_method("is_scored_actor") or not target.is_scored_actor():
		return
	squad_command = SQUAD_COMMAND_AGGRO
	squad_aggro_target = target
	add_kill_feed("Squad assisting on %s" % (target.get_actor_name() if target.has_method("get_actor_name") else "target"))

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

func _tick_day_cycle(delta: float) -> void:
	day_timer += delta
	if day_timer < DAY_LENGTH_SEC:
		return
	day_timer = fmod(day_timer, DAY_LENGTH_SEC)
	day_index += 1
	_refresh_food_sources()
	add_kill_feed("Dawn %d: wild food refreshed" % day_index)

func _refresh_food_sources() -> void:
	for food in food_sources:
		if food != null and is_instance_valid(food):
			food.queue_free()
	food_sources.clear()
	var spawn_points: Array = terrain_map.get_food_spawn_points() if terrain_map.has_method("get_food_spawn_points") else []
	for entry: Dictionary in spawn_points:
		var food = FoodSourceScript.new()
		add_child(food)
		food.setup(String(entry.get("kind", FoodSourceScript.KIND_PLANT)), entry.get("position", Vector2.ZERO))
		food_sources.append(food)

func try_eat_nearby_food(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.has_method("consume_food"):
		return false
	for i in range(food_sources.size() - 1, -1, -1):
		var food: Node = food_sources[i]
		if food == null or not is_instance_valid(food):
			food_sources.remove_at(i)
			continue
		var reach := float(actor.get("body_radius") if actor.get("body_radius") != null else 10.0) + float(food.get("body_radius")) + FOOD_EAT_RADIUS_PAD
		if actor.global_position.distance_to(food.global_position) > reach:
			continue
		if actor.consume_food(String(food.get("kind")), float(food.get("food_value")), float(food.get("heal_fraction"))):
			food.consume()
			food_sources.remove_at(i)
			return true
	return false

func record_food_consumed(actor: Node, food_kind: String, hunger_gain: float) -> void:
	var food_label := "plant" if food_kind == FoodSourceScript.KIND_PLANT else "critter"
	var actor_name: String = actor.get_actor_name() if actor != null and actor.has_method("get_actor_name") else "Creature"
	if hunger_gain > 0.0:
		add_kill_feed("%s ate %s (+%d hunger)" % [actor_name, food_label, int(round(hunger_gain))])
	else:
		add_kill_feed("%s topped off on %s" % [actor_name, food_label])

func get_day_state() -> Dictionary:
	return {
		"day": day_index,
		"elapsed": day_timer,
		"remaining": maxf(DAY_LENGTH_SEC - day_timer, 0.0),
		"length": DAY_LENGTH_SEC,
		"food_sources": food_sources.size()
	}

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
	_maybe_trigger_squad_aggro(event)
	_spawn_vfx_for_event(event)
	queue_redraw()

func _maybe_trigger_squad_aggro(event: Dictionary) -> void:
	if not _is_1v1_trio_mode() or squad_command != SQUAD_COMMAND_FOLLOW or squad_command_timer <= 0.0:
		return
	if String(event.get("type", "")) != "hit_landed":
		return
	var source = event.get("source", null)
	var target = event.get("target", null)
	if source == player:
		_issue_squad_aggro(target)

func resolve_projectile_hits(projectile: Node) -> void:
	if projectile_crosses_cover(projectile.previous_position, projectile.global_position, projectile.radius):
		projectile.queue_free()
		return

	for entity in entities:
		if projectile.hit_entities.has(entity):
			continue
		if not TargetFilter.is_live_damage_target(projectile, entity, {"require_damage_api": false}):
			continue
		# Hull test (decision #21): capsule bodies are hittable along their length.
		if HurtboxScript.overlaps_circle(HurtboxScript.hull_of(entity), projectile.global_position, projectile.radius):
			# Projectiles are RANGED (decision #1) — flying targets are hit
			# normally and heavy shots can spike birds (decision #20).
			if entity.has_method("take_damage_event"):
				var event := DamageEventScript.new()
				event.setup(projectile.damage, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, projectile.source_actor, "projectile")
				entity.take_damage_event(event)
			else:
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
		if not TargetFilter.is_live_damage_target(source, entity, {"require_damage_api": false}):
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
		if not _valid_target(entity) or entity.team == source_team:
			continue
		if cover_blocks_point(center, entity.global_position, minf(radius, 18.0)):
			continue
		if HurtboxScript.overlaps_circle(HurtboxScript.hull_of(entity), center, radius):
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
		if not _valid_target(entity) or entity.team != source_team:
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
	_consume_stock_for_death(victim)

func _consume_stock_for_death(victim: Node) -> void:
	if not uses_stock_respawn(victim):
		return
	var respawn_duration := float(victim.get("respawn_duration") if victim.get("respawn_duration") != null else 5.0)
	var slot: Dictionary = stock_manager.record_ko(victim, respawn_duration)
	var remaining := int(slot.get("stocks_remaining", 0))
	var max_stocks := int(slot.get("max_stocks", StockManagerScript.MAX_STOCKS))
	if String(slot.get("state", "")) == StockManagerScript.STATE_EXHAUSTED:
		add_kill_feed("%s is out of stocks" % victim.get_actor_name())
	else:
		add_kill_feed("%s stocks %d/%d" % [victim.get_actor_name(), remaining, max_stocks])
	_check_stock_victory(victim.team)

func uses_stock_respawn(actor: Node) -> bool:
	return _is_1v1_trio_mode() and actor != null and stock_manager.has_actor(actor)

func tick_stock_respawn(actor: Node, delta: float) -> bool:
	if not uses_stock_respawn(actor):
		return false
	var slot: Dictionary = stock_manager.tick_actor_respawn(actor, delta)
	if slot.is_empty():
		return false
	actor.respawn_timer = float(slot.get("respawn_timer", actor.respawn_timer))
	return stock_manager.can_respawn(actor)

func get_actor_respawn_position(actor: Node) -> Vector2:
	if uses_stock_respawn(actor):
		var rect: Rect2 = terrain_map.get_team_habitat_rect(actor.team)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			var slot: Dictionary = stock_manager.get_slot_for_actor(actor)
			var slot_index := int(slot.get("slot_index", 1))
			return rect.position + rect.size * 0.5 + Vector2(0.0, float(slot_index - 1) * 34.0)
	return get_team_spawn(actor.team)

func on_actor_respawned(actor: Node) -> void:
	if uses_stock_respawn(actor):
		stock_manager.mark_respawned(actor)

func _check_stock_victory(losing_team: int) -> void:
	if match_over or not stock_manager.team_exhausted(losing_team):
		return
	match_over = true
	var winner := "Red" if losing_team == BLUE else "Blue"
	status_label.text = "%s wins by stock elimination! Press Enter to restart or Esc for menu." % winner
	end_summary_label.text = _get_match_summary(winner)
	add_kill_feed("%s squad is out of stocks" % _team_name(losing_team))

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

func get_core_damage_multiplier(_team: int) -> float:
	return 1.0

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

func is_near_view(point: Vector2) -> bool:
	# True when a point is close enough to the player's camera view that its
	# node should bother redrawing. Generous margin for the cursor-led camera.
	if player == null or not is_instance_valid(player):
		return true
	return point.distance_squared_to(player.global_position) < 810000.0  # 900px

func is_inside_arena(point: Vector2) -> bool:
	return arena_rect.has_point(point)

func clamp_to_arena(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, arena_rect.position.x + 24.0, arena_rect.end.x - 24.0), clampf(point.y, arena_rect.position.y + 24.0, arena_rect.end.y - 24.0))

# Soft body collision (decision #27): grounded live movers push apart with a
# capped per-tick correction so bodies read as solid without hard physics.
# Airborne creatures pass over, dashers ghost through, latch pairs stay
# attached. Deterministic: entities iterated in registration order.
const SEPARATION_MAX_PUSH_PX := 2.0

func resolve_body_separation() -> void:
	var bodies: Array[Node] = []
	for entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		# Movers only (creatures + minions); huts/cores are terrain-like.
		if not (entity is CharacterBody2D):
			continue
		bodies.append(entity)
	# PERF: hulls computed once per body, and a squared-distance broad phase
	# rejects far pairs before any hull math (this pass regressed to
	# 80 ms/frame without it — see perf_harness before committing changes).
	var hulls: Array[Dictionary] = []
	var reaches := PackedFloat32Array()
	for body in bodies:
		var hull: Dictionary = HurtboxScript.hull_of(body)
		hulls.append(hull)
		reaches.append(float(hull.radius) + float(hull.half_len))
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Node = bodies[i]
			var b: Node = bodies[j]
			var max_gap: float = reaches[i] + reaches[j]
			if a.global_position.distance_squared_to(b.global_position) > max_gap * max_gap:
				continue
			if _separation_exempt(a, b):
				continue
			var push: Vector2 = HurtboxScript.separation_push_hulls(hulls[i], hulls[j])
			if push == Vector2.ZERO:
				continue
			var half: Vector2 = push * 0.5
			if half.length() > SEPARATION_MAX_PUSH_PX:
				half = half.normalized() * SEPARATION_MAX_PUSH_PX
			a.global_position = resolve_body_position(a.global_position + half, a.body_radius)
			b.global_position = resolve_body_position(b.global_position - half, b.body_radius)

func _separation_exempt(a: Node, b: Node) -> bool:
	if _passes_over_bodies(a) or _passes_over_bodies(b):
		return true
	if a.get("latch_victim") == b or b.get("latch_victim") == a:
		return true
	return false

func _passes_over_bodies(body: Node) -> bool:
	if body.has_method("is_airborne") and body.is_airborne():
		return true
	var dash_value: Variant = body.get("dash_timer")
	if typeof(dash_value) == TYPE_FLOAT and float(dash_value) > 0.0:
		return true
	var pass_obstacles_value: Variant = body.get("pass_obstacles_timer")
	if typeof(pass_obstacles_value) == TYPE_FLOAT and float(pass_obstacles_value) > 0.0:
		return true
	return false

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
	for cover: Rect2 in cover_rects:
		if _segment_intersects_rect(from, to, cover.grow(radius)):
			return true
	return false

# Exact segment-vs-AABB slab test — replaces the old 20px point-stepping walk.
static func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var d := b - a
	var t_min := 0.0
	var t_max := 1.0
	for axis in 2:
		var delta := d.x if axis == 0 else d.y
		var origin := a.x if axis == 0 else a.y
		var low := rect.position.x if axis == 0 else rect.position.y
		var high := rect.end.x if axis == 0 else rect.end.y
		if absf(delta) < 0.0001:
			if origin < low or origin > high:
				return false
		else:
			var t1 := (low - origin) / delta
			var t2 := (high - origin) / delta
			if t1 > t2:
				var swap := t1
				t1 = t2
				t2 = swap
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return false
	return true

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

func _draw_squad_badges() -> void:
	if not _is_1v1_trio_mode():
		return
	for i in player_squad.size():
		var member: Node = player_squad[i]
		if member == null or not is_instance_valid(member) or not member.is_alive():
			continue
		var text := _squad_badge_text(member, i)
		var color := _squad_badge_color(member, i)
		var position: Vector2 = member.global_position + Vector2(-28.0, -member.body_radius - 25.0)
		draw_string(ThemeDB.fallback_font, position + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.02, 0.02, 0.02, 0.85))
		draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, color)

func get_habitat_stock_visuals(team := -1) -> Array[Dictionary]:
	var visuals: Array[Dictionary] = []
	if stock_manager == null or not stock_manager.has_method("get_team_slots"):
		return visuals
	var teams := [BLUE, RED] if team < 0 else [team]
	for draw_team in teams:
		var habitat: Rect2 = terrain_map.get_team_habitat_rect(draw_team)
		if habitat.size.x <= 0.0 or habitat.size.y <= 0.0:
			continue
		var slots: Array[Dictionary] = stock_manager.get_team_slots(draw_team)
		for slot: Dictionary in slots:
			var slot_index := int(slot.get("slot_index", 0))
			var stocks := int(slot.get("stocks_remaining", StockManagerScript.MAX_STOCKS))
			var state := String(slot.get("state", StockManagerScript.STATE_FIELD))
			var reserves := maxi(0, stocks - (0 if state == StockManagerScript.STATE_RESPAWNING else 1))
			for reserve_index in mini(reserves, StockManagerScript.MAX_STOCKS - 1):
				visuals.append({
					"team": draw_team,
					"slot_index": slot_index,
					"reserve_index": reserve_index,
					"creature_id": String(slot.get("creature_id", "")),
					"state": state,
					"position": _habitat_reserve_position(habitat, draw_team, slot_index, reserve_index)
				})
	return visuals

func _habitat_reserve_position(habitat: Rect2, team: int, slot_index: int, reserve_index: int) -> Vector2:
	var x_side := -1.0 if team == BLUE else 1.0
	var center := habitat.get_center()
	var row_y := (float(slot_index) - 1.0) * 32.0
	var col_x := x_side * (34.0 + float(reserve_index) * 26.0)
	return center + Vector2(col_x, row_y)

func _draw_habitat_stock_visuals() -> void:
	for visual: Dictionary in get_habitat_stock_visuals():
		var position: Vector2 = visual.get("position", Vector2.ZERO)
		var team := int(visual.get("team", BLUE))
		var team_color := Color(0.42, 0.72, 1.0, 0.84) if team == BLUE else Color(1.0, 0.38, 0.32, 0.84)
		draw_circle(position, 10.0, Color(0.04, 0.05, 0.045, 0.82))
		draw_circle(position, 7.0, team_color)
		draw_arc(position, 11.5, 0.0, TAU, 20, Color(0.88, 0.92, 0.82, 0.45), 1.5)
		draw_string(ThemeDB.fallback_font, position + Vector2(-5.0, 4.0), str(int(visual.get("slot_index", 0)) + 1), HORIZONTAL_ALIGNMENT_LEFT, 10.0, 9, Color(0.02, 0.025, 0.02, 0.95))

func _draw_breeding_cues() -> void:
	for cue: Dictionary in stock_manager.get_breeding_cues():
		var team := int(cue.get("team", BLUE))
		var habitat: Rect2 = terrain_map.get_team_habitat_rect(team)
		if habitat.size.x <= 0.0 or habitat.size.y <= 0.0:
			continue
		var slot_index := int(cue.get("slot_index", 0))
		var center := habitat.get_center() + Vector2(0.0, (float(slot_index) - 1.0) * 32.0)
		var remaining := clampf(float(cue.get("remaining", 0.0)), 0.0, 45.0)
		var progress := 1.0 - remaining / 45.0
		var color := Color(0.9, 0.75, 0.28, 0.85)
		draw_arc(center, 24.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 36, color, 4.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-16.0, -28.0), "%ds" % ceili(remaining), HORIZONTAL_ALIGNMENT_LEFT, 36.0, 10, color)

func _squad_badge_text(member: Node, index: int) -> String:
	if member == player:
		return "%d ACTIVE" % (index + 1)
	if _is_severe_danger(member):
		return "%d DANGER" % (index + 1)
	match squad_command:
		SQUAD_COMMAND_FOLLOW:
			return "%d FOLLOW %.0f" % [index + 1, ceili(squad_command_timer)]
		SQUAD_COMMAND_AGGRO:
			return "%d AGGRO" % (index + 1)
		_:
			return "%d FARM" % (index + 1)

func _squad_badge_color(member: Node, _index: int) -> Color:
	if member == player:
		return Color(1.0, 1.0, 1.0, 0.95)
	if _is_severe_danger(member):
		return Color(1.0, 0.34, 0.24, 0.95)
	match squad_command:
		SQUAD_COMMAND_FOLLOW:
			return Color(0.45, 0.75, 1.0, 0.95)
		SQUAD_COMMAND_AGGRO:
			return Color(1.0, 0.54, 0.26, 0.95)
		_:
			return Color(0.58, 1.0, 0.48, 0.95)

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
		var mode_text := "1v1 Trio" if _is_1v1_trio_mode() else GameConfig.selected_mode
		var active_text := "Slot %d %s" % [active_squad_index + 1, creature_name] if _is_1v1_trio_mode() else creature_name
		var hunger_text := "Hunger %d%%" % int(round(float(player.get("hunger")))) if player != null and player.get("hunger") != null else "Hunger --"
		status_label.text = "%s | %s | Day %d dawn %ds | Active: %s | %s | Bots: %d | Next wave: %ds" % [mode_text, _format_match_time(elapsed), day_index, ceili(maxf(DAY_LENGTH_SEC - day_timer, 0.0)), active_text, hunger_text, bots.size(), ceili(wave_timer)]
	core_label.text = "Blue Core %d / %d    Red Core %d / %d" % [blue_core.health, blue_core.max_health, red_core.health, red_core.max_health]
	cooldown_label.text = _get_cooldown_text()
	scoreboard_label.text = _get_scoreboard_text()
	kill_feed_label.text = _get_kill_feed_text()

func _get_cooldown_text() -> String:
	if player == null:
		return ""
	if player.has_method("is_alive") and not player.is_alive():
		return "RESPAWNING IN %.1fs" % maxf(player.respawn_timer, 0.0)
	var active_line := "Primary %s | Q %s | E %s | Swim %d%% | Flight %d%% | %s" % [
		_format_cooldown(player.primary_timer),
		_format_cooldown(player.q_timer),
		_format_cooldown(player.e_timer),
		int(player.get_swim_ratio() * 100.0),
		int(player.get_flight_ratio() * 100.0),
		"LATCH" if player.has_latch() else "free"
	]
	return active_line

func _get_squad_rail_text() -> String:
	var command_text := "FARM/SAFE"
	if squad_command == SQUAD_COMMAND_FOLLOW:
		command_text = "FOLLOW %.0fs" % ceili(squad_command_timer)
	elif squad_command == SQUAD_COMMAND_AGGRO:
		command_text = "AGGRO %.0fs" % ceili(squad_command_timer)
	var chunks: Array[String] = ["Squad %s" % command_text]
	for i in player_squad.size():
		var member: Node = player_squad[i]
		if member == null or not is_instance_valid(member):
			continue
		var marker := "*" if member == player else " "
		var hp_ratio := _health_ratio(member)
		var state := "KO %.1fs" % member.respawn_timer if member.has_method("is_alive") and not member.is_alive() else "%d%%" % int(hp_ratio * 100.0)
		var stocks_text := "stocks 3/3"
		if stock_manager.has_actor(member):
			var slot: Dictionary = stock_manager.get_slot_for_actor(member)
			stocks_text = "stocks %d/%d" % [int(slot.get("stocks_remaining", 3)), int(slot.get("max_stocks", 3))]
			if String(slot.get("state", "")) == StockManagerScript.STATE_EXHAUSTED:
				state = "OUT"
		chunks.append("%s%d %s %s %s" % [marker, i + 1, member.creature_data.get("name", member.creature_id), stocks_text, state])
	return " | ".join(chunks)

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
		"Score  Blue %dK/%dD/%dDmg    Red %dK/%dD/%dDmg" % [
			blue["kills"], blue["deaths"], int(blue["core_damage"]),
			red["kills"], red["deaths"], int(red["core_damage"]),
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
	return "Match Summary: %s victory at %s | Blue %dK %dDmg | Red %dK %dDmg" % [
		winner,
		_format_match_time(elapsed),
		blue["kills"],
		int(blue["core_damage"]),
		red["kills"],
		int(red["core_damage"]),
	]

func _format_match_time(seconds: float) -> String:
	var total_seconds := int(floor(seconds))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _tick_kill_feed(delta: float) -> void:
	for i in range(kill_feed.size() - 1, -1, -1):
		kill_feed[i]["remaining"] = float(kill_feed[i]["remaining"]) - delta
		if float(kill_feed[i]["remaining"]) <= 0.0:
			kill_feed.remove_at(i)

func _player_near_own_hut() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	for hut in huts:
		if hut != null and is_instance_valid(hut) and hut.team == player.team and hut.global_position.distance_to(player.global_position) < 110.0:
			return true
	return false

func _try_manual_habitat_deposit(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor) or habitat_deposit_feedback_timer > 0.0:
		return false
	habitat_deposit_feedback_timer = 1.0
	if not _is_actor_in_home_habitat(actor):
		habitat_deposit_prompt_state = "needs_habitat"
		add_kill_feed("U: enter home habitat to deposit")
		return false
	if actor.has_method("is_satiated") and not actor.is_satiated():
		habitat_deposit_prompt_state = "needs_food"
		add_kill_feed("U: eat wild food until satiated first")
		return false
	if uses_stock_respawn(actor):
		stock_manager.record_habitat_visit(actor)
	if actor.has_method("reset_hunger_after_deposit") and actor.has_method("is_satiated") and actor.is_satiated():
		actor.reset_hunger_after_deposit()
	habitat_deposit_prompt_state = "accepted"
	add_kill_feed("%s deposited at habitat; breeding cue started" % actor.get_actor_name())
	return true

func _is_actor_in_home_habitat(actor: Node) -> bool:
	var rect: Rect2 = terrain_map.get_team_habitat_rect(actor.team)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return rect.grow(16.0).has_point(actor.global_position)

func _team_name(team: int) -> String:
	return "Blue" if team == BLUE else "Red"

var quit_confirm_timer := 0.0

func _input(event: InputEvent) -> void:
	if match_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		# No accidental mid-match exits: Esc must be pressed twice within 2s.
		if match_over or quit_confirm_timer > 0.0:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		else:
			quit_confirm_timer = 2.0
			add_kill_feed("Press Esc again to leave the match")
			var confirm_timer := get_tree().create_timer(2.0)
			confirm_timer.timeout.connect(func() -> void: quit_confirm_timer = 0.0)
	elif _is_1v1_trio_mode() and _is_pressed_non_echo_event(event):
		if event.is_action_pressed("squad_slot_1"):
			_set_active_squad_index(0)
		elif event.is_action_pressed("squad_slot_2"):
			_set_active_squad_index(1)
		elif event.is_action_pressed("squad_slot_3"):
			_set_active_squad_index(2)
		elif event.is_action_pressed("squad_regroup"):
			_issue_squad_follow()
		elif event.is_action_pressed("squad_farm"):
			_issue_squad_farm()

func _is_pressed_non_echo_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventAction:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false
