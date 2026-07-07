extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["otter", "mink", "beaver"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave4 otter check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "otter":
		push_error("expected otter active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_primary_bite_latch(arena, failures)
	_check_tail_whip(arena, failures)
	_check_gang_up(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave4_otter failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_primary_bite_latch(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.release_latch("test_reset")
	target.release_latch("test_reset")
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(24.0, 0.0)
	target.health = target.max_health
	actor.primary_timer = 0.0
	var frame := _aim_frame(actor, target)
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var latched: bool = actor.latch_victim == target \
		and target.latched_attacker == actor \
		and actor.latch_source == "Bite" \
		and actor.latch_timer > 1.8 \
		and target.health < target.max_health
	if not latched:
		failures.append("Otter primary should bite and latch for a short pack grip; latch=%s/%s source=%s timer=%.2f target=%.2f/%.2f" % [
			str(actor.latch_victim),
			str(target.latched_attacker),
			actor.latch_source,
			actor.latch_timer,
			target.health,
			target.max_health
		])
	actor.release_latch("test_reset")

func _check_tail_whip(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var first: Node = arena.bots[0]
	var second: Node = arena.bots[1]
	actor.release_latch("test_reset")
	first.release_latch("test_reset")
	second.release_latch("test_reset")
	first.apply_creature("cane_toad")
	second.apply_creature("mink")
	actor.global_position = Vector2.ZERO
	first.global_position = Vector2(24.0, -6.0)
	second.global_position = Vector2(26.0, 8.0)
	first.health = first.max_health
	second.health = second.max_health
	first.dash_timer = 0.0
	second.dash_timer = 0.0
	actor.q_timer = 0.0
	var frame := _aim_frame(actor, first)
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var first_hit: bool = first.health < first.max_health and first.dash_timer > 0.0 and first.dash_velocity.x > 0.0
	var second_hit: bool = second.health < second.max_health and second.dash_timer > 0.0 and second.dash_velocity.x > 0.0
	if not first_hit or not second_hit or actor.q_timer < 4.9:
		failures.append("Otter Tail Whip should multi-hit and knock targets backward; first=%s/%s second=%s/%s q=%.2f" % [
			str(first_hit),
			str(first.dash_velocity),
			str(second_hit),
			str(second.dash_velocity),
			actor.q_timer
		])

func _check_gang_up(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.release_latch("test_reset")
	target.release_latch("test_reset")
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(24.0, 0.0)
	target.health = target.max_health
	actor.primary_timer = 0.0
	actor.e_timer = 0.0
	var arm := _aim_frame(actor, target)
	arm.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(arm)
	actor.kit.tick(actor, 0.016)
	var armed: bool = bool(actor.kit.get("gang_up_armed"))
	actor.primary_timer = 0.0
	var hit := _aim_frame(actor, target)
	hit.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(hit)
	actor.kit.tick(actor, 0.016)
	var gang_latched: bool = actor.latch_victim == target \
		and actor.latch_source == "Gang Up" \
		and target.latch_source == "Gang Up" \
		and actor.latch_timer > 1.8
	var immobilized: bool = target.get_modifier_value("move_speed_mult", 1.0) <= 0.01
	var disarmed: bool = not bool(actor.kit.get("gang_up_armed")) and actor.e_timer > 5.0
	if not armed or not gang_latched or not immobilized or not disarmed:
		failures.append("Otter Gang Up should arm next bite into immobilizing pack latch; armed=%s latch=%s immobilized=%s disarmed=%s source=%s target_mult=%.2f e=%.2f" % [
			str(armed),
			str(gang_latched),
			str(immobilized),
			str(disarmed),
			actor.latch_source,
			target.get_modifier_value("move_speed_mult", 1.0),
			actor.e_timer
		])
	actor.release_latch("test_reset")

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("otter")
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var target: Node = arena.player
	target.global_position = actor.global_position + Vector2.RIGHT * 42.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, target, frame, actor.global_position.distance_to(target.global_position))
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("otter bot should tail-whip and arm Gang Up at close range; buttons=%d" % frame.buttons)

func _aim_frame(actor: Node, target: Node) -> Resource:
	var frame := InputFrameScript.new()
	frame.aim = target.global_position
	frame.move = Vector2.ZERO
	actor.last_aim_direction = (target.global_position - actor.global_position).normalized()
	return frame
