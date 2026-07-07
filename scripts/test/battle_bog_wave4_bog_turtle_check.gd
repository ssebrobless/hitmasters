extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["bog_turtle", "beaver", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave4 bog turtle check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "bog_turtle":
		push_error("expected bog turtle active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_headbutt(arena, failures)
	_check_basking_support(arena, failures)
	_check_endozoochory_flower(arena, failures)
	_check_umbrella_effect(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave4_bog_turtle failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_headbutt(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.apply_creature("bog_turtle")
	target.apply_creature("mink")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(16.0, 0.0)
	actor.health = actor.max_health
	target.health = target.max_health
	actor.primary_timer = 0.0
	var frame := _aim_frame(actor, target)
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var hit: bool = target.health < target.max_health and actor.health == actor.max_health - 2.0 and actor.primary_timer > 0.9
	if not hit:
		failures.append("Bog Turtle headbutt should damage target, self-chip 2 HP, and start cooldown; actor=%.2f/%.2f target=%.2f/%.2f primary=%.2f" % [
			actor.health,
			actor.max_health,
			target.health,
			target.max_health,
			actor.primary_timer
		])

func _check_basking_support(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var ally: Node = arena.player_squad[1]
	var target: Node = arena.bots[0]
	actor.apply_creature("bog_turtle")
	ally.apply_creature("beaver")
	target.apply_creature("mink")
	actor.global_position = Vector2.ZERO
	ally.global_position = Vector2(12.0, 0.0)
	target.global_position = Vector2(16.0, 0.0)
	ally.health = ally.max_health - 40.0
	actor.primary_timer = 0.0
	var bask := InputFrameScript.new()
	bask.set_button(InputFrameScript.BUTTON_CONTEXT_ACTION, true)
	actor.set_input_frame(bask)
	actor.kit.tick(actor, 0.016)
	var started: bool = actor.kit.basking_ally == ally and actor.get_modifier_value("damage_taken_mult", 1.0) < 0.1
	var before_ally: float = ally.health
	var headbutt := _aim_frame(actor, target)
	headbutt.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(headbutt)
	actor.primary_timer = 0.0
	actor.kit.tick(actor, 0.016)
	var supported: bool = ally.health > before_ally and ally.get_modifier_value("damage_dealt_mult", 1.0) > 1.01
	if not started or not supported:
		failures.append("Bog Turtle Basking should attach to a larger ally, reduce turtle damage taken, then headbutt-heal/buff ally; started=%s supported=%s ally=%.2f/%.2f mult=%.2f turtle_mult=%.2f" % [
			str(started),
			str(supported),
			ally.health,
			ally.max_health,
			ally.get_modifier_value("damage_dealt_mult", 1.0),
			actor.get_modifier_value("damage_taken_mult", 1.0)
		])

func _check_endozoochory_flower(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var ally: Node = arena.player_squad[1]
	actor.apply_creature("bog_turtle")
	ally.apply_creature("beaver")
	actor.global_position = Vector2.ZERO
	ally.global_position = Vector2(96.0, 0.0)
	ally.health = ally.max_health * 0.5
	actor.q_charges = 2
	var frame := InputFrameScript.new()
	frame.aim = Vector2(64.0, 0.0)
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var spawned: bool = actor.kit.flowers.size() == 1 and actor.q_charges == 1
	var flower: Node = actor.kit.flowers[0] if actor.kit.flowers.size() > 0 else null
	if flower != null:
		flower._physics_process(2.1)
		ally.global_position = flower.global_position
		flower._physics_process(0.016)
		var healed: bool = ally.health > ally.max_health * 0.5 and bool(flower.get("consumed"))
		if not spawned or not healed:
			failures.append("Bog Turtle Endozoochory should spend Q charge, grow a delayed flower, and heal ally on touch; spawned=%s healed=%s ally=%.2f/%.2f q=%d" % [
				str(spawned),
				str(healed),
				ally.health,
				ally.max_health,
				actor.q_charges
			])
	else:
		failures.append("Bog Turtle Endozoochory should spawn a flower node")

func _check_umbrella_effect(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var ally: Node = arena.player_squad[1]
	actor.apply_creature("bog_turtle")
	ally.apply_creature("beaver")
	actor.global_position = Vector2.ZERO
	ally.global_position = Vector2(12.0, 0.0)
	actor.health = actor.max_health - 50.0
	ally.health = ally.max_health - 80.0
	var bask := InputFrameScript.new()
	bask.set_button(InputFrameScript.BUTTON_CONTEXT_ACTION, true)
	actor.set_input_frame(bask)
	actor.kit.tick(actor, 0.016)
	var before_ally: float = ally.health
	var umbrella := InputFrameScript.new()
	umbrella.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(umbrella)
	actor.kit.tick(actor, 0.016)
	var healed: bool = actor.health == actor.max_health and ally.health > before_ally and actor.e_charges == 1
	if not healed:
		failures.append("Bog Turtle Umbrella Effect should spend E while basking, heal self missing HP, and mirror that heal to ally; actor=%.2f/%.2f ally=%.2f/%.2f e=%d bask=%s" % [
			actor.health,
			actor.max_health,
			ally.health,
			ally.max_health,
			actor.e_charges,
			str(actor.kit.basking_ally)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	var ally: Node = arena.bots[1]
	actor.apply_creature("bog_turtle")
	ally.apply_creature("beaver")
	actor.global_position = Vector2.ZERO
	ally.global_position = Vector2(12.0, 0.0)
	actor.q_charges = 1
	actor.e_charges = 1
	actor.health = actor.max_health - 20.0
	actor.kit.basking_ally = ally
	var target: Node = arena.player
	target.global_position = actor.global_position + Vector2.RIGHT * 64.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, target, frame, actor.global_position.distance_to(target.global_position))
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("bog turtle bot should use Q near enemies and E while wounded+basking; buttons=%d" % frame.buttons)

func _aim_frame(actor: Node, target: Node) -> Resource:
	var frame := InputFrameScript.new()
	frame.aim = target.global_position
	frame.move = Vector2.ZERO
	actor.last_aim_direction = (target.global_position - actor.global_position).normalized()
	return frame
