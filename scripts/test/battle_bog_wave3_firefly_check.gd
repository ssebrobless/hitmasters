extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["firefly", "wolf_spider", "alligator"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave3 firefly check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "firefly":
		push_error("expected firefly active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_bioluminescence_and_flash(arena, failures)
	_check_reveal_projectile(arena, failures)
	_check_glowworms(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave3_firefly failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_bioluminescence_and_flash(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var ally: Node = arena.player_squad[1]
	actor.global_position = Vector2.ZERO
	ally.global_position = Vector2.RIGHT * 56.0
	ally.health = ally.max_health - 80.0
	actor.kit.flash_timer = 0.0
	actor.set_input_frame(InputFrameScript.new())
	actor.kit.tick(actor, 0.5)
	var passive_heal: bool = ally.health >= ally.max_health - 70.1 and ally.health <= ally.max_health - 69.5

	ally.health = ally.max_health - 80.0
	ally.global_position = Vector2.RIGHT * 96.0
	actor.kit.tick(actor, 0.5)
	var outside_base: bool = ally.health <= ally.max_health - 79.9
	var q := InputFrameScript.new()
	q.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.q_timer = 0.0
	actor.set_input_frame(q)
	actor.kit.tick(actor, 0.016)
	actor.set_input_frame(InputFrameScript.new())
	actor.kit.tick(actor, 1.0)
	var flash_heal: bool = ally.health >= ally.max_health - 57.5
	var flash_speed: bool = ally.get_modifier_value("move_speed_mult", 1.0) > 1.04
	if not passive_heal or not outside_base or not flash_heal or not flash_speed:
		failures.append("Firefly Bioluminescence should heal 20/s inside 4u only; Flash-Train should reach 7u, heal +15%%, speed +5%%; passive=%s outside=%s flash_heal=%s flash_speed=%s health=%.2f speed=%.2f" % [
			str(passive_heal),
			str(outside_base),
			str(flash_heal),
			str(flash_speed),
			ally.health,
			ally.get_modifier_value("move_speed_mult", 1.0)
		])

func _check_reveal_projectile(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 80.0
	target.health = target.max_health
	target.begin_stealth(10.0, "Test Stealth")
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = target.global_position
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	for projectile in actor.kit.projectiles:
		for i in 40:
			if projectile == null or not is_instance_valid(projectile):
				break
			projectile._physics_process(0.016)
	var damaged: bool = target.health < target.max_health
	var revealed: bool = not target.is_stealthed() and _has_modifier(target, "Firefly Reveal")
	if not damaged or not revealed:
		failures.append("Firefly primary should launch homing reveal projectile; damaged=%s revealed=%s health=%.2f projectiles=%d" % [
			str(damaged),
			str(revealed),
			target.health,
			actor.kit.projectiles.size()
		])

func _check_glowworms(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	target.apply_creature("cane_toad")
	actor.kit._retire_all()
	actor.kit.glowworm_charges.setup(3, 10.0)
	actor.e_charges = 3
	actor.global_position = Vector2(-60.0, 0.0)
	var e := InputFrameScript.new()
	e.aim = actor.global_position + Vector2.RIGHT * 100.0
	e.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(e)
	for i in 4:
		actor.kit.tick(actor, 0.016)
	var charge_cap: bool = actor.kit.mines.size() == 3 and actor.e_charges == 0
	var mine: Node = actor.kit.mines[0]
	target.global_position = mine.global_position
	mine._physics_process(0.016)
	var field_spawned: bool = actor.kit.fields.size() == 1
	if field_spawned:
		var field: Node = actor.kit.fields[0]
		field._physics_process(0.1)
	var slowed: bool = target.get_modifier_value("move_speed_mult", 1.0) < 0.61
	var vulnerable: bool = target.get_modifier_value("damage_taken_mult", 1.0) > 1.09
	for field in actor.kit.fields:
		if field != null and is_instance_valid(field) and field.has_method("retire"):
			field.retire()
	target.cleanse_negative_modifiers()
	var cleansed: bool = target.get_modifier_value("move_speed_mult", 1.0) >= 0.99 and target.get_modifier_value("damage_taken_mult", 1.0) <= 1.01
	if not charge_cap or not field_spawned or not slowed or not vulnerable or not cleansed:
		failures.append("Glowworms should spend 3 charges, cap mines, trigger a 3u 4s field with 40%% slow/10%% vuln, and be cleansable; cap=%s field=%s slow=%s vuln=%s clean=%s mines=%d fields=%d charges=%d speed=%.2f damage=%.2f" % [
			str(charge_cap),
			str(field_spawned),
			str(slowed),
			str(vulnerable),
			str(cleansed),
			actor.kit.mines.size(),
			actor.kit.fields.size(),
			actor.e_charges,
			target.get_modifier_value("move_speed_mult", 1.0),
			target.get_modifier_value("damage_taken_mult", 1.0)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("firefly")
	actor.q_timer = 0.0
	actor.e_charges = 3
	actor.global_position = Vector2.ZERO
	var ally: Node = arena.bots[1]
	ally.global_position = Vector2.RIGHT * 48.0
	ally.health = ally.max_health * 0.5
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, actor.body_radius * 8.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("firefly bot should fire, Flash-Train hurt allies, and place glowworms near enemies; buttons=%d" % frame.buttons)

func _has_modifier(target: Node, source: String) -> bool:
	for modifier: Dictionary in target.modifiers:
		if String(modifier.get("source", "")) == source:
			return true
	return false
