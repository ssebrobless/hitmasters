extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["water_shrew", "crayfish", "cane_toad"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave1 water shrew check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "water_shrew":
		push_error("expected water_shrew active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_bite_stack_cap(arena, failures)
	_check_water_walk(arena, failures)
	_check_proenkephalin_split_lock(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave1_water_shrew failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_bite_stack_cap(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_normalize_grounded_target(target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(16.0, 0.0)
	target.health = target.max_health
	target.modifiers.clear()
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	for i in 4:
		actor.primary_timer = 0.0
		actor.kit.tick(actor, 0.016)
	var stacks := _modifier_count(target, "Water Shrew Bite")
	var capped_and_scaled: bool = stacks == 3 \
		and target.get_modifier_value("move_speed_mult", 1.0) < 0.92 \
		and target.get_modifier_value("damage_dealt_mult", 1.0) < 0.95 \
		and target.get_modifier_value("damage_taken_mult", 1.0) > 1.05
	if not capped_and_scaled:
		failures.append("Water Shrew Bite should cap at 3 debuff stacks; stacks=%d move=%.3f damage=%.3f taken=%.3f" % [
			stacks,
			target.get_modifier_value("move_speed_mult", 1.0),
			target.get_modifier_value("damage_dealt_mult", 1.0),
			target.get_modifier_value("damage_taken_mult", 1.0)
		])

func _check_water_walk(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.global_position = Vector2.ZERO
	actor.swim_time_remaining = 1.0
	actor.q_timer = 0.0
	actor.kit.water_walk_timer = 0.0
	actor.remove_modifiers_from_source("Water Walk")
	var frame := InputFrameScript.new()
	frame.move = Vector2.RIGHT
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.tick_sim(0.05)
	var after_start_swim: float = actor.swim_time_remaining
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, false)
	actor.set_input_frame(frame)
	actor.tick_sim(0.2)
	var active_safe: bool = actor.kit.water_walk_timer > 0.0 \
		and actor.get_modifier_value("water_walk", 1.0) > 1.5 \
		and not bool(actor.current_environment_profile.get("wrong_terrain_now", true)) \
		and actor.swim_time_remaining >= after_start_swim - 0.001
	var active_render: Dictionary = actor.get_render_motion_state()
	var active_surface_skim: bool = bool(active_render.get("surface_walk", false)) and bool(active_render.get("in_water", false))
	var active_wake: bool = float(active_render.get("surface_wake_intensity", 0.0)) > 0.25

	var idle_frame := InputFrameScript.new()
	idle_frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	actor.set_input_frame(idle_frame)
	actor.tick_sim(0.05)
	var idle_dropped: bool = actor.kit.water_walk_timer <= 0.0 and actor.get_modifier_value("water_walk", 1.0) == 1.0
	var idle_render: Dictionary = actor.get_render_motion_state()
	var idle_surface_skim: bool = bool(idle_render.get("surface_walk", false))
	var idle_wake_clear: bool = float(idle_render.get("surface_wake_intensity", 1.0)) <= 0.001
	if not active_safe or not active_surface_skim or not active_wake or not idle_dropped or idle_surface_skim or not idle_wake_clear:
		failures.append("Water Walk should make water safe while moving, render surface skim+wake, and drop on idle; active=%s skim=%s wake=%s dropped=%s idle_skim=%s idle_wake=%s timer=%.2f water_walk=%.1f swim %.2f/%.2f profile=%s render=%s/%s" % [
			str(active_safe),
			str(active_surface_skim),
			str(active_wake),
			str(idle_dropped),
			str(idle_surface_skim),
			str(idle_wake_clear),
			actor.kit.water_walk_timer,
			actor.get_modifier_value("water_walk", 1.0),
			after_start_swim,
			actor.swim_time_remaining,
			str(actor.current_environment_profile),
			str(active_render),
			str(idle_render)
		])

func _check_proenkephalin_split_lock(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_normalize_grounded_target(target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(16.0, 0.0)
	actor.health = actor.max_health
	target.health = target.max_health
	target.modifiers.clear()
	actor.kit.proenkephalin_primed = false
	actor.kit.proenkephalin_charges.charges = 2
	actor.e_charges = 2
	actor.e_timer = 0.0
	var prime := InputFrameScript.new()
	prime.aim = actor.global_position + Vector2.RIGHT * 100.0
	prime.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(prime)
	actor.kit.tick(actor, 0.016)
	var bite := InputFrameScript.new()
	bite.aim = actor.global_position + Vector2.RIGHT * 100.0
	bite.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(bite)
	actor.primary_timer = 0.0
	actor.kit.tick(actor, 0.016)
	var split_lock_applied: bool = target.can_act() and not target.can_use_abilities() and target.get_modifier_value("move_speed_mult", 1.0) == 0.0 and actor.e_timer > 0.0 and actor.e_charges == 1

	target.secondary_resource = 20.0
	target.primary_timer = 0.0
	target.q_timer = 0.0
	target.e_timer = 0.0
	var start_position: Vector2 = target.global_position
	var actor_health_before: float = actor.health
	var target_frame := InputFrameScript.new()
	target_frame.move = Vector2.RIGHT
	target_frame.aim = actor.global_position
	target_frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	target_frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	target_frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	target.set_input_frame(target_frame)
	target.tick_sim(0.3)
	var primary_allowed: bool = actor.health < actor_health_before
	var abilities_blocked: bool = target.q_timer == 0.0 and target.e_timer == 0.0
	var movement_blocked: bool = target.global_position.distance_to(start_position) < 0.001
	if not split_lock_applied or not primary_allowed or not abilities_blocked or not movement_blocked:
		failures.append("Proenkephalin should block movement/Q/E but allow primary; applied=%s primary=%s abilities=%s movement=%s q=%.2f e=%.2f health %.2f->%.2f pos_delta=%.3f" % [
			str(split_lock_applied),
			str(primary_allowed),
			str(abilities_blocked),
			str(movement_blocked),
			target.q_timer,
			target.e_timer,
			actor_health_before,
			actor.health,
			target.global_position.distance_to(start_position)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("water_shrew")
	actor.q_timer = 0.0
	actor.e_charges = 2
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, actor.body_radius * 4.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("water shrew bot should prime E at close range; buttons=%d" % frame.buttons)

func _modifier_count(target: Node, source: String) -> int:
	var count := 0
	for modifier: Dictionary in target.modifiers:
		if String(modifier.get("source", "")) == source:
			count += 1
	return count

func _normalize_grounded_target(target: Node) -> void:
	target.apply_creature("cane_toad")
	target.state = CreatureStateScript.State.NORMAL
	target.dash_timer = 0.0
	target.dash_velocity = Vector2.ZERO
	target.pass_obstacles_timer = 0.0
	target.velocity = Vector2.ZERO
	target.break_stealth()
	target.release_latch("test_reset")
