extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["great_blue_heron", "newt", "water_shrew"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave2a heron check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "great_blue_heron":
		push_error("expected great_blue_heron active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_grounded_spear(arena, failures)
	_check_powder_puff(arena, failures)
	_check_flushing(arena, failures)
	_check_wading(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave2a_heron failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_grounded_spear(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(30.0, 0.0)
	target.health = target.max_health
	actor.state = CreatureStateScript.State.NORMAL
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 120.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var grounded_hit: bool = target.health < target.max_health

	target.health = target.max_health
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.primary_timer = 0.0
	actor.kit.tick(actor, 0.016)
	var flying_blocked: bool = target.health == target.max_health
	actor.state = CreatureStateScript.State.NORMAL
	if not grounded_hit or not flying_blocked:
		failures.append("Heron primary should hit grounded and be blocked while flying; grounded=%s flying_blocked=%s target=%.2f" % [
			str(grounded_hit),
			str(flying_blocked),
			target.health
		])

func _check_powder_puff(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.modifiers.clear()
	actor.q_timer = 0.0
	actor.add_modifier("Test Slow", {"move_speed_mult": 0.5, "damage_dealt_mult": 0.8}, 5.0)
	actor.add_modifier("Test Buff", {"damage_dealt_mult": 1.1}, 5.0)
	var frame := InputFrameScript.new()
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var cleansed: bool = _modifier_count(actor, "Test Slow") == 0 and _modifier_count(actor, "Test Buff") == 1
	var immune: bool = actor.get_modifier_value("cc_immune", 1.0) > 1.5
	actor.add_modifier("Lingual Lure", {"move_speed_mult": 0.0, "can_act_mult": 0.0}, 1.5)
	var blocked_lure: bool = actor.can_act() and actor.get_modifier_value("move_speed_mult", 1.0) > 0.0
	if not cleansed or not immune or not blocked_lure:
		failures.append("Powder Puff should cleanse negatives, keep buffs, and block CC; cleansed=%s immune=%s blocked=%s mods=%s" % [
			str(cleansed),
			str(immune),
			str(blocked_lure),
			str(actor.modifiers)
		])
	actor.modifiers.clear()

func _check_flushing(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.state = CreatureStateScript.State.NORMAL
	actor.e_timer = 0.0
	actor.flight_time_remaining = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var flushed: bool = actor.state == CreatureStateScript.State.AIRBORNE and actor.dash_timer > 0.0 and actor.dash_velocity.x > 0.0 and actor.flight_time_remaining == actor.flight_time_max
	if not flushed:
		failures.append("Flushing should dash and start airborne without takeoff; state=%d dash=%.2f vel=%s flight=%.2f/%.2f" % [
			actor.state,
			actor.dash_timer,
			str(actor.dash_velocity),
			actor.flight_time_remaining,
			actor.flight_time_max
		])
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO
	actor.state = CreatureStateScript.State.NORMAL

func _check_wading(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.global_position = Vector2.ZERO
	actor.state = CreatureStateScript.State.NORMAL
	actor.swim_time_remaining = 0.0
	actor._update_terrain(0.1)
	var safe_water: bool = actor.get_current_zone() == TerrainMapScript.WATER and not bool(actor.current_environment_profile.get("wrong_terrain_now", true))
	if not safe_water:
		failures.append("Wading heron should treat deep water as safe while grounded; zone=%s profile=%s" % [
			actor.get_current_zone(),
			str(actor.current_environment_profile)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("great_blue_heron")
	actor.add_modifier("Test Slow", {"move_speed_mult": 0.5}, 5.0)
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, actor.body_radius * 4.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("heron bot should Q when debuffed and E at close grounded range; buttons=%d" % frame.buttons)

func _modifier_count(actor: Node, source: String) -> int:
	var count := 0
	for modifier: Dictionary in actor.modifiers:
		if String(modifier.get("source", "")) == source:
			count += 1
	return count
