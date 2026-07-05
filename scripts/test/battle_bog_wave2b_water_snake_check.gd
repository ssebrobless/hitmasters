extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["water_snake", "kingfisher", "great_blue_heron"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave2b water snake check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "water_snake":
		push_error("expected water_snake active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_capsule_and_hold_latch(arena, failures)
	_check_latched_dps_drag_and_release(arena, failures)
	_check_musking_and_retreat(arena, failures)
	_check_ingestion(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave2b_water_snake failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_capsule_and_hold_latch(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	actor.last_aim_direction = Vector2.RIGHT
	target.global_position = Vector2(26.0, 0.0)
	target.health = target.max_health
	target.damage_ticks.clear()
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.primary_timer = 0.0
	actor.kit.tick(actor, 0.016)
	var latched: bool = actor.latch_victim == target and target.latched_attacker == actor
	var bleed: bool = _dot_count(target, "Water Snake Bleed") == 1
	if not latched or not bleed:
		failures.append("Water Snake bite should use capsule reach to latch tail-side target and bleed; latched=%s bleed=%s target_health=%.2f" % [
			str(latched),
			str(bleed),
			target.health
		])

func _check_latched_dps_drag_and_release(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	var start_health: float = target.health
	var start_position: Vector2 = target.global_position
	var hold := InputFrameScript.new()
	hold.aim = target.global_position
	hold.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(hold)
	actor.tick_sim(0.5)
	var dps: bool = target.health < start_health - target.max_health * 0.003
	var target_dragged: bool = target.global_position.distance_to(start_position) > 0.1
	var held: bool = actor.latch_victim == target and actor.latch_timer > 0.0
	var release := InputFrameScript.new()
	release.aim = target.global_position
	actor.set_input_frame(release)
	actor.tick_sim(0.05)
	var released: bool = actor.latch_victim == null and target.latched_attacker == null
	if not dps or not target_dragged or not held or not released:
		failures.append("Latched Water Snake should deal DPS, drag lower-HP target, hold while primary held, release on primary up; dps=%s dragged=%s held=%s released=%s health %.2f->%.2f move=%.2f" % [
			str(dps),
			str(target_dragged),
			str(held),
			str(released),
			start_health,
			target.health,
			target.global_position.distance_to(start_position)
		])

func _check_musking_and_retreat(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.release_latch("test_reset")
	actor.q_timer = 0.0
	target.dash_timer = 0.0
	target.global_position = actor.global_position + Vector2.RIGHT * 24.0
	var q_frame := InputFrameScript.new()
	q_frame.aim = target.global_position
	q_frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(q_frame)
	actor.kit.tick(actor, 0.016)
	var free_push: bool = target.dash_timer > 0.0 and target.dash_velocity.x > 0.0

	actor.q_timer = 0.0
	target.dash_timer = 0.0
	target.dash_velocity = Vector2.ZERO
	actor.attach_to_victim(target, 1.0, "Bite")
	target.receive_latch(actor, 1.0, "Bite")
	var latched_q_frame := InputFrameScript.new()
	latched_q_frame.aim = target.global_position
	latched_q_frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	latched_q_frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(latched_q_frame)
	actor.kit.tick(actor, 0.016)
	var blocked_latched_q: bool = actor.q_timer == 0.0 and target.dash_timer == 0.0
	actor.release_latch("test_reset")

	actor.e_timer = 0.0
	var e_frame := InputFrameScript.new()
	e_frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(e_frame)
	actor.kit.tick(actor, 0.016)
	var retreated: bool = actor.get_modifier_value("move_speed_mult", 1.0) > 1.15
	if not free_push or not blocked_latched_q or not retreated:
		failures.append("Musking should push only while free and Retreat should speed buff; push=%s blocked=%s retreat=%s q=%.2f dash=%.2f speed=%.2f" % [
			str(free_push),
			str(blocked_latched_q),
			str(retreated),
			actor.q_timer,
			target.dash_timer,
			actor.get_modifier_value("move_speed_mult", 1.0)
		])

func _check_ingestion(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var victim: Node = arena.bots[1]
	victim.apply_creature("mink")
	actor.global_position = Vector2.ZERO
	victim.global_position = Vector2(20.0, 0.0)
	actor.health = actor.max_health * 0.25
	victim.health = victim.max_health * 0.10
	actor.kit.ingestion_timer = 0.0
	actor.attach_to_victim(victim, 1.0, "Bite")
	victim.receive_latch(actor, 1.0, "Bite")
	var hold := InputFrameScript.new()
	hold.aim = victim.global_position
	hold.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(hold)
	actor.kit.tick(actor, 0.2)
	var executed: bool = not victim.is_alive()
	var healed: bool = actor.health > actor.max_health * 0.45
	var cooldown: bool = actor.kit.ingestion_timer > 19.0
	if not executed or not healed or not cooldown:
		failures.append("Ingestion should execute lower-base-HP latched target under 15%% and heal; executed=%s healed=%s cooldown=%s actor=%.2f victim_alive=%s timer=%.2f" % [
			str(executed),
			str(healed),
			str(cooldown),
			actor.health,
			str(victim.is_alive()),
			actor.kit.ingestion_timer
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("water_snake")
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.health = actor.max_health * 0.3
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, actor.body_radius * 4.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("water snake bot should Q close and E when low; buttons=%d" % frame.buttons)
	actor.attach_to_victim(arena.player, 1.0, "Bite")
	arena.player.receive_latch(actor, 1.0, "Bite")
	var latch_frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, latch_frame, actor.body_radius * 4.0)
	if not latch_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY):
		failures.append("water snake bot should hold primary while latched; buttons=%d" % latch_frame.buttons)
	actor.release_latch("test_reset")

func _dot_count(target: Node, source_ability: String) -> int:
	var count := 0
	for tick: Dictionary in target.damage_ticks:
		if String(tick.get("source_ability", "")) == source_ability:
			count += 1
	return count
