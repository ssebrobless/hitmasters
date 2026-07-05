extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["crayfish", "cane_toad", "bullfrog"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave1 crayfish check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "crayfish":
		push_error("expected crayfish active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_primary_alternates(arena, failures)
	_check_caridoid_escape(arena, failures)
	_check_meral_display(arena, failures)
	_check_molting(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave1_crayfish failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_primary_alternates(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(18.0, 0.0)
	target.health = target.max_health
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 120.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.primary_timer = 0.0
	actor.kit.tick(actor, 0.016)
	var after_first: float = target.health
	actor.primary_timer = 0.0
	actor.kit.tick(actor, 0.016)
	var alternated: bool = actor.kit.left_claw_next == false
	if not (target.health < after_first and alternated):
		failures.append("primary should alternate claws and damage twice; health %.2f -> %.2f left_next=%s" % [
			after_first,
			target.health,
			str(actor.kit.left_claw_next)
		])

func _check_caridoid_escape(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(12.0, 0.0)
	target.health = target.max_health
	actor.q_charges = 3
	actor.kit.escape_charges.charges = 3
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var dashed_back: bool = actor.dash_timer > 0.0 and actor.dash_velocity.x < 0.0
	var smacked: bool = target.health < target.max_health
	var spent: bool = actor.q_charges == 2
	if not dashed_back or not smacked or not spent:
		failures.append("Caridoid Escape should smack front target, dash backward, spend charge; dashed=%s smacked=%s charges=%d vel=%s" % [
			str(dashed_back),
			str(smacked),
			actor.q_charges,
			str(actor.dash_velocity)
		])
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO

func _check_meral_display(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.e_timer = 0.0
	var base_radius: float = actor.body_radius
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var stance_started: bool = actor.state == CreatureStateScript.State.STANCE and actor.body_radius > base_radius and actor.get_modifier_value("damage_taken_mult", 1.0) < 1.0

	var move_frame := InputFrameScript.new()
	move_frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	move_frame.move = Vector2.UP
	actor.set_input_frame(move_frame)
	var start_position: Vector2 = actor.global_position
	actor.tick_sim(0.2)
	var strafe_blocked: bool = absf(actor.global_position.y - start_position.y) < 0.001

	actor.kit.tick(actor, 11.0)
	var restored: bool = actor.state != CreatureStateScript.State.STANCE and absf(actor.body_radius - base_radius) < 0.001
	if not stance_started or not strafe_blocked or not restored:
		failures.append("Meral Display expected stance size/DR, forward-back movement, restore; started=%s strafe_blocked=%s restored=%s radius=%.2f base=%.2f state=%d" % [
			str(stance_started),
			str(strafe_blocked),
			str(restored),
			actor.body_radius,
			base_radius,
			actor.state
		])

func _check_molting(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.modifiers.clear()
	actor.kit.molt_stacks = 0
	actor.kit.molt_timer = 0.01
	actor.kit.molt_window_timer = 0.0
	actor.set_input_frame(InputFrameScript.new())
	actor.kit.tick(actor, 0.02)
	var vulnerable: bool = actor.get_modifier_value("damage_taken_mult", 1.0) > 1.0
	actor.tick_sim(1.1)
	var stacked: bool = actor.kit.molt_stacks == 1 and actor.get_modifier_value("damage_taken_mult", 1.0) < 1.0
	if not vulnerable or not stacked:
		failures.append("Molting should open vulnerable window then grant DR stack; vulnerable=%s stacks=%d damage_mult=%.3f" % [
			str(vulnerable),
			actor.kit.molt_stacks,
			actor.get_modifier_value("damage_taken_mult", 1.0)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("crayfish")
	actor.e_timer = 0.0
	actor.q_charges = 3
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, 8.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("crayfish bot should press Q/E at close range; buttons=%d" % frame.buttons)
