extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["cane_toad", "bullfrog", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave1 cane toad check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "cane_toad":
		push_error("expected cane_toad active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_poison_stream(arena, failures)
	_check_melee_retaliation(arena, failures)
	_check_toxic_skin_and_thanatosis(arena, failures)
	_check_secondary_meter(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave1_cane_toad failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_poison_stream(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(36.0, 0.0)
	target.health = target.max_health
	target.damage_ticks.clear()
	actor.secondary_resource = 20.0
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 160.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.3)
	var hit_and_dot: bool = target.health < target.max_health and _dot_count(target, "Poison Stream") > 0
	var spent_toxin: bool = actor.secondary_resource < 20.0
	if not hit_and_dot or not spent_toxin:
		failures.append("poison stream expected hit, DOT, and toxin drain; health=%.2f dots=%d toxin=%.2f" % [
			target.health,
			_dot_count(target, "Poison Stream"),
			actor.secondary_resource
		])

	target.health = target.max_health
	target.damage_ticks.clear()
	actor.secondary_resource = 0.0
	actor.primary_timer = 0.0
	actor.kit.tick(actor, 0.3)
	var dry_blocked: bool = target.health == target.max_health and _dot_count(target, "Poison Stream") == 0
	if not dry_blocked:
		failures.append("poison stream should not fire at zero toxin; health=%.2f dots=%d" % [
			target.health,
			_dot_count(target, "Poison Stream")
		])

func _check_melee_retaliation(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var attacker: Node = arena.bots[0]
	actor.health = actor.max_health
	attacker.damage_ticks.clear()
	actor.take_damage_event(_event(1.0, DamageEventScript.DELIVERY_MELEE, attacker, "Test Bite"))
	if _dot_count(attacker, "Bufotoxin") != 1:
		failures.append("melee attacker should receive one Bufotoxin stack, got %d" % _dot_count(attacker, "Bufotoxin"))

	actor.take_damage_event(_event(1.0, DamageEventScript.DELIVERY_RANGED, attacker, "Test Shot"))
	if _dot_count(attacker, "Bufotoxin") != 1:
		failures.append("ranged attacker should not receive Bufotoxin, got %d" % _dot_count(attacker, "Bufotoxin"))

	for i in 6:
		actor.take_damage_event(_event(1.0, DamageEventScript.DELIVERY_MELEE, attacker, "Stack Bite"))
	if _dot_count(attacker, "Bufotoxin") != 5:
		failures.append("Bufotoxin should cap at 5 stacks, got %d" % _dot_count(attacker, "Bufotoxin"))

func _check_toxic_skin_and_thanatosis(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var attacker: Node = arena.bots[1]
	actor.health = actor.max_health
	attacker.damage_ticks.clear()
	actor.q_timer = 0.0
	var q_frame := InputFrameScript.new()
	q_frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(q_frame)
	actor.kit.tick(actor, 0.016)
	if actor.kit.toxic_skin_timer <= 0.0 or actor.q_timer <= 0.0:
		failures.append("Toxic Skin should start active and set Q cooldown")
	for i in 4:
		actor.take_damage_event(_event(1.0, DamageEventScript.DELIVERY_MELEE, attacker, "Skin Bite"))
	if _dot_count(attacker, "Toxic Skin") != 3:
		failures.append("Toxic Skin should cap at 3 stacks, got %d" % _dot_count(attacker, "Toxic Skin"))

	actor.e_timer = 0.0
	var e_frame := InputFrameScript.new()
	e_frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(e_frame)
	actor.kit.tick(actor, 0.016)
	var rooted: bool = actor.get_modifier_value("move_speed_mult", 1.0) == 0.0
	if not rooted or not actor.can_act() or actor.kit.thanatosis_timer <= 0.0:
		failures.append("Thanatosis should root movement without silencing actions; rooted=%s can_act=%s timer=%.2f" % [
			str(rooted),
			str(actor.can_act()),
			actor.kit.thanatosis_timer
		])

func _check_secondary_meter(arena: Node, failures: Array[String]) -> void:
	if arena.ability_bar == null:
		failures.append("arena should build ability bar for Cane Toad")
		return
	var meter: Dictionary = arena.ability_bar.get_secondary_meter()
	if not bool(meter.visible) or String(meter.label) != "TOXIN" or float(meter.max) <= 0.0:
		failures.append("Cane Toad ability bar should expose TOXIN meter, got %s" % str(meter))

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("cane_toad")
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.health = actor.max_health * 0.3
	var target: Node = arena.player
	target.global_position = actor.global_position + Vector2.RIGHT * 4.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, target, frame, 4.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("cane toad bot should press Q/E when threatened close; buttons=%d" % frame.buttons)

func _event(amount: float, delivery: int, source_actor: Node, source_ability: String) -> Resource:
	var event := DamageEventScript.new()
	event.setup(amount, delivery, DamageEventScript.PLANE_GROUND, source_actor, source_ability)
	return event

func _dot_count(target: Node, source_ability: String) -> int:
	var count := 0
	for tick: Dictionary in target.damage_ticks:
		if String(tick.get("source_ability", "")) == source_ability:
			count += 1
	return count
