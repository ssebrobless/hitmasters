extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const DamScript := preload("res://scripts/game/dam.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["mosquito_swarm", "firefly", "wolf_spider"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave3 mosquito check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "mosquito_swarm":
		push_error("expected mosquito_swarm active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_primary_field_and_blood(arena, failures)
	_check_breeding_trail(arena, failures)
	_check_deposit(arena, failures)
	_check_unswattable(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave3_mosquito_swarm failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_primary_field_and_blood(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_normalize_target(target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 80.0
	target.health = target.max_health
	actor.secondary_resource = 0.0
	actor.primary_timer = 0.0
	actor.kit._retire_all()
	var frame := InputFrameScript.new()
	frame.aim = target.global_position
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	for projectile in actor.kit.projectiles:
		for i in 80:
			if projectile == null or not is_instance_valid(projectile):
				break
			projectile._physics_process(0.016)
	var field_spawned: bool = actor.kit.fields.size() == 1
	if field_spawned:
		var field: Node = actor.kit.fields[0]
		field.global_position = target.global_position
		field._physics_process(1.0)
	var damaged: bool = target.health <= target.max_health - 14.0
	var slowed: bool = target.get_modifier_value("move_speed_mult", 1.0) < 0.96
	var blood: bool = actor.secondary_resource >= 14.0
	if not field_spawned or not damaged or not slowed or not blood:
		failures.append("Mosquito primary should expand into 3u AOE, deal 15 DPS, slow 5%%, and fill blood; field=%s damaged=%s slowed=%s blood=%s health=%.2f speed=%.2f blood=%.2f" % [
			str(field_spawned),
			str(damaged),
			str(slowed),
			str(blood),
			target.health,
			target.get_modifier_value("move_speed_mult", 1.0),
			actor.secondary_resource
		])

func _check_breeding_trail(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.kit._retire_all()
	actor.q_timer = 0.0
	actor.global_position = Vector2(-120.0, -80.0)
	var frame := InputFrameScript.new()
	frame.move = Vector2.RIGHT
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.tick_sim(0.05)
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, false)
	actor.set_input_frame(frame)
	for i in 70:
		actor.tick_sim(0.1)
	var capped: bool = actor.kit.fields.size() <= 14 and actor.kit.fields.size() > 3
	var cooldown: bool = actor.q_timer > 9.0
	if not capped or not cooldown:
		failures.append("Breeding Grounds should leave capped lingering AOE trail and start 10s cooldown after trail ends; capped=%s cooldown=%s fields=%d q=%.2f" % [
			str(capped),
			str(cooldown),
			actor.kit.fields.size(),
			actor.q_timer
		])

func _check_deposit(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var ally: Node = arena.player_squad[2]
	actor.secondary_resource = actor.secondary_resource_max
	actor.e_timer = 0.0
	actor.global_position = Vector2.ZERO
	ally.global_position = Vector2.RIGHT * 10.0
	ally.health = ally.max_health - 80.0
	actor.hunger = 40.0
	var frame := InputFrameScript.new()
	frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var healed: bool = ally.health >= ally.max_health - 30.1 and ally.health <= ally.max_health - 29.5
	var drained_blood: bool = actor.secondary_resource == 0.0
	var cooldown: bool = actor.e_timer >= 2.9
	var hunger_kept: bool = actor.hunger >= 39.9
	if not healed or not drained_blood or not cooldown or not hunger_kept:
		failures.append("Deposit should heal ally for 50 at full blood within 1u, drain blood, set 3s CD, and not drain hunger; healed=%s drained=%s cooldown=%s hunger=%s ally=%.2f blood=%.2f e=%.2f hunger=%.2f" % [
			str(healed),
			str(drained_blood),
			str(cooldown),
			str(hunger_kept),
			ally.health,
			actor.secondary_resource,
			actor.e_timer,
			actor.hunger
		])

func _check_unswattable(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_normalize_target(target)
	actor.kit._retire_all()
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 8.0
	target.health = target.max_health
	actor.secondary_resource = 0.0
	actor.hunger = 20.0
	actor.kit.tick(actor, 1.0)
	var contact_damage: bool = target.health <= target.max_health - 9.0
	var contact_blood: bool = actor.secondary_resource >= 9.0
	var contact_hunger: bool = actor.hunger > 20.0

	actor.health = actor.max_health
	arena.match_rng.seed = 99
	var first_run_misses := _ranged_miss_count(actor, target, 300)
	actor.health = actor.max_health
	arena.match_rng.seed = 99
	var second_run_misses := _ranged_miss_count(actor, target, 300)
	var deterministic_miss: bool = first_run_misses == second_run_misses and first_run_misses >= 12 and first_run_misses <= 42

	actor.health = actor.max_health
	actor.take_damage_event(_event(10.0, DamageEventScript.DELIVERY_MELEE, target, "Melee Test"))
	var melee_hits: bool = actor.health <= actor.max_health - 9.9
	var full_radius: float = actor.body_radius
	actor.health = actor.max_health * 0.25
	actor.kit.tick(actor, 0.016)
	var shrunk: bool = actor.body_radius < full_radius

	var dam := DamScript.new()
	arena.add_child(dam)
	dam.setup(arena, 1, Rect2(Vector2(-10.0, -10.0), Vector2(20.0, 20.0)), 200.0)
	arena.register_dam(dam)
	actor.global_position = Vector2(-28.0, 0.0)
	var move := InputFrameScript.new()
	move.move = Vector2.RIGHT
	move.aim = Vector2.RIGHT * 100.0
	actor.set_input_frame(move)
	actor.tick_sim(0.5)
	var passed_dam: bool = actor.global_position.x > 10.0
	arena.unregister_dam(dam)
	dam.queue_free()

	if not contact_damage or not contact_blood or not contact_hunger or not deterministic_miss or not melee_hits or not shrunk or not passed_dam:
		failures.append("Unswattable should contact-drain blood/hunger, deterministic ~9%% ranged miss, still take melee, shrink hitbox with HP, and pass dams; contact=%s blood=%s hunger=%s miss=%s/%d melee=%s shrink=%s dam=%s hp=%.2f radius=%.2f/%.2f x=%.2f" % [
			str(contact_damage),
			str(contact_blood),
			str(contact_hunger),
			str(deterministic_miss),
			first_run_misses,
			str(melee_hits),
			str(shrunk),
			str(passed_dam),
			actor.health,
			actor.body_radius,
			full_radius,
			actor.global_position.x
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("mosquito_swarm")
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.secondary_resource = actor.secondary_resource_max
	var ally: Node = arena.bots[1]
	ally.apply_creature("cane_toad")
	ally.global_position = actor.global_position + Vector2.RIGHT * 8.0
	ally.health = ally.max_health - 40.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, actor.body_radius * 6.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("mosquito bot should fire, trail near enemies, and deposit near hurt allies; buttons=%d" % frame.buttons)

func _ranged_miss_count(actor: Node, source: Node, count: int) -> int:
	var misses := 0
	for i in count:
		actor.health = actor.max_health
		actor.take_damage_event(_event(1.0, DamageEventScript.DELIVERY_RANGED, source, "Ranged Test"))
		if actor.health == actor.max_health:
			misses += 1
	return misses

func _event(amount: float, delivery: int, source: Node, ability: String) -> Resource:
	var event := DamageEventScript.new()
	event.setup(amount, delivery, DamageEventScript.PLANE_GROUND, source, ability)
	return event

func _normalize_target(target: Node) -> void:
	target.apply_creature("cane_toad")
	target.state = preload("res://scripts/sim/creature_state.gd").State.NORMAL
	target.dash_timer = 0.0
	target.dash_velocity = Vector2.ZERO
	target.pass_obstacles_timer = 0.0
	target.velocity = Vector2.ZERO
	target.break_stealth()
	target.release_latch("test_reset")
