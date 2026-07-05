extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["kingfisher", "great_blue_heron", "newt"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave2a kingfisher check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "kingfisher":
		push_error("expected kingfisher active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_plunge_bonus(arena, failures)
	_check_hover(arena, failures)
	_check_nest_chamber(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave2a_kingfisher failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_plunge_bonus(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(14.0, 0.0)
	actor.state = CreatureStateScript.State.NORMAL
	target.health = target.max_health
	actor.kit.moved_since_attack_px = 0.0
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var normal_damage: float = target.max_health - target.health

	target.health = target.max_health
	actor.primary_timer = 0.0
	actor.kit.moved_since_attack_px = 2.0 * SimConstants.UNIT_PX
	actor.kit.tick(actor, 0.016)
	var plunge_damage: float = target.max_health - target.health
	var bonus_ok: bool = plunge_damage > normal_damage * 1.25 and actor.low_window_timer > 0.0 and actor.kit.moved_since_attack_px == 0.0
	if not bonus_ok:
		failures.append("Kingfisher Plunge should gain damage after 2u movement and open low window; normal=%.2f plunge=%.2f low=%.2f moved=%.2f" % [
			normal_damage,
			plunge_damage,
			actor.low_window_timer,
			actor.kit.moved_since_attack_px
		])

func _check_hover(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.state = CreatureStateScript.State.NORMAL
	actor.modifiers.clear()
	actor.q_timer = 0.0
	actor.kit.hover_timer = 0.0
	var hover := InputFrameScript.new()
	hover.aim = actor.global_position + Vector2.RIGHT * 100.0
	hover.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(hover)
	actor.kit.tick(actor, 0.016)
	var hover_started: bool = actor.state == CreatureStateScript.State.AIRBORNE and actor.kit.hover_timer > 3.5 and actor.get_modifier_value("move_speed_mult", 1.0) == 0.0

	var move := InputFrameScript.new()
	move.move = Vector2.RIGHT
	move.aim = actor.global_position + Vector2.RIGHT * 100.0
	actor.set_input_frame(move)
	actor.kit.tick(actor, 0.016)
	var released_to_flight: bool = actor.state == CreatureStateScript.State.AIRBORNE and actor.kit.hover_timer <= 0.0 and actor.get_modifier_value("move_speed_mult", 1.0) == 1.0
	if not hover_started or not released_to_flight:
		failures.append("Hover should start idle airborne then release into free flight on movement; start=%s release=%s state=%d timer=%.2f move=%.2f" % [
			str(hover_started),
			str(released_to_flight),
			actor.state,
			actor.kit.hover_timer,
			actor.get_modifier_value("move_speed_mult", 1.0)
		])

func _check_nest_chamber(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var attacker: Node = arena.bots[0]
	actor.state = CreatureStateScript.State.NORMAL
	actor.health = actor.max_health
	actor.modifiers.clear()
	actor.e_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var burrowed: bool = actor.state == CreatureStateScript.State.BURROWED and actor.is_untargetable() and actor.get_modifier_value("invulnerable", 1.0) > 1.5
	var filter_blocks: bool = not TargetFilter.is_live_damage_target(attacker, actor)
	actor.take_damage_event(_event(999.0, DamageEventScript.DELIVERY_MELEE, attacker, "Dig Test"))
	var immune: bool = actor.health == actor.max_health
	actor.kit.tick(actor, 7.1)
	var exited: bool = actor.state == CreatureStateScript.State.NORMAL and not actor.is_untargetable()
	if not burrowed or not filter_blocks or not immune or not exited:
		failures.append("Nest Chamber should burrow untargetable/immune then exit grounded; burrowed=%s filter=%s immune=%s exited=%s state=%d health=%.2f mods=%s" % [
			str(burrowed),
			str(filter_blocks),
			str(immune),
			str(exited),
			actor.state,
			actor.health,
			str(actor.modifiers)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("kingfisher")
	actor.health = actor.max_health * 0.3
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, actor.body_radius * 8.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("kingfisher bot should hover at range and nest when low; buttons=%d" % frame.buttons)

func _event(amount: float, delivery: int, source_actor: Node, source_ability: String) -> Resource:
	var event := DamageEventScript.new()
	event.setup(amount, delivery, DamageEventScript.PLANE_GROUND, source_actor, source_ability)
	return event
