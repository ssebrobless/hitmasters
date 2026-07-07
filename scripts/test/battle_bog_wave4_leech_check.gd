extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["leech", "mink", "beaver"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave4 leech check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "leech":
		push_error("expected leech active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_cluster_resource(arena, failures)
	_check_primary_projectile_attach(arena, failures)
	_check_copulation_regen(arena, failures)
	_check_sensory_crypt(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave4_leech failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_cluster_resource(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("leech")
	var max_ok: bool = actor.max_health == 20.0 \
		and actor.secondary_resource_label == "LEECHES" \
		and actor.secondary_resource == actor.health
	var event := DamageEventScript.new()
	event.setup(50.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, arena.bots[0], "Cluster Probe")
	var before: float = actor.health
	actor.take_damage_event(event)
	var one_leech_hit: bool = before - actor.health == 1.0 and actor.secondary_resource == actor.health
	if not max_ok or not one_leech_hit:
		failures.append("Leech cluster should expose 20 body-leeches and lose one per hit; max=%s label=%s resource=%.2f before=%.2f after=%.2f" % [
			str(max_ok),
			actor.secondary_resource_label,
			actor.secondary_resource,
			before,
			actor.health
		])

func _check_primary_projectile_attach(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.apply_creature("leech")
	target.apply_creature("mink")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(48.0, 0.0)
	target.health = target.max_health
	target.damage_ticks.clear()
	target.modifiers.clear()
	actor.primary_timer = 0.0
	var frame := _aim_frame(actor, target)
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var spent: bool = actor.health == actor.max_health - 1.0 and actor.kit.projectiles.size() == 1
	if actor.kit.projectiles.size() > 0:
		var projectile: Node = actor.kit.projectiles[0]
		projectile.global_position = target.global_position
		projectile._physics_process(0.016)
	var attached: bool = _has_damage_tick(target, "Leech Projectile") and _has_modifier(target, "Leech Projectile")
	var before: float = target.health
	target.tick_sim(1.0)
	var ticking: bool = target.health < before
	if not spent or not attached or not ticking:
		failures.append("Leech primary should spend one body-leech, stick, reveal, and deal attach DPS; spent=%s attached=%s ticking=%s health=%.2f target=%.2f ticks=%s" % [
			str(spent),
			str(attached),
			str(ticking),
			actor.health,
			target.health,
			str(target.damage_ticks)
		])

func _check_copulation_regen(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("leech")
	actor.health = 16.0
	actor.q_timer = 0.0
	var frame := InputFrameScript.new()
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	actor.set_input_frame(InputFrameScript.new())
	actor.kit.tick(actor, 1.0)
	var spawned: bool = actor.health > 16.0 and actor.kit.copulation_timer > 0.0
	actor.kit.tick(actor, 5.0)
	var cooled: bool = actor.q_timer > 6.0
	if not spawned or not cooled:
		failures.append("Leech Copulation should idle-channel new body-leeches then enter cooldown; spawned=%s cooled=%s health=%.2f q=%.2f" % [
			str(spawned),
			str(cooled),
			actor.health,
			actor.q_timer
		])

func _check_sensory_crypt(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var first: Node = arena.bots[0]
	var second: Node = arena.bots[1]
	var dry: Node = arena.bots[2]
	actor.apply_creature("leech")
	first.apply_creature("mink")
	second.apply_creature("beaver")
	dry.apply_creature("cane_toad")
	var water_point: Vector2 = arena.terrain_map.get_rects("water")[0].get_center()
	actor.global_position = water_point
	first.global_position = water_point + Vector2(24.0, 0.0)
	second.global_position = water_point + Vector2(-24.0, 0.0)
	dry.global_position = Vector2(-1000.0, -1000.0)
	for target in [first, second, dry]:
		target.damage_ticks.clear()
		target.modifiers.clear()
	actor.health = actor.max_health
	actor.e_timer = 0.0
	var crypt := InputFrameScript.new()
	crypt.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(crypt)
	actor.kit.tick(actor, 0.016)
	var hit_water: bool = _has_damage_tick(first, "Sensory Crypt") and _has_damage_tick(second, "Sensory Crypt")
	var skipped_dry: bool = not _has_damage_tick(dry, "Sensory Crypt")
	var spent_and_cooled: bool = actor.health == actor.max_health - 2.0 and actor.e_timer > 13.0
	if not hit_water or not skipped_dry or not spent_and_cooled:
		failures.append("Leech Sensory Crypt should water-gate, spend one body-leech per water target, and reveal/attach; water=%s dry=%s spent=%s health=%.2f e=%.2f ticks=%s/%s/%s" % [
			str(hit_water),
			str(skipped_dry),
			str(spent_and_cooled),
			actor.health,
			actor.e_timer,
			str(first.damage_ticks),
			str(second.damage_ticks),
			str(dry.damage_ticks)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("leech")
	actor.global_position = arena.terrain_map.get_rects("water")[0].get_center()
	actor.health = actor.max_health - 3.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var target: Node = arena.player
	target.global_position = actor.global_position + Vector2.RIGHT * 80.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, target, frame, actor.global_position.distance_to(target.global_position))
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("leech bot should regenerate when depleted and crypt from water near targets; buttons=%d" % frame.buttons)

func _aim_frame(actor: Node, target: Node) -> Resource:
	var frame := InputFrameScript.new()
	frame.aim = target.global_position
	frame.move = Vector2.ZERO
	actor.last_aim_direction = (target.global_position - actor.global_position).normalized()
	return frame

func _has_damage_tick(target: Node, source_ability: String) -> bool:
	for tick: Dictionary in target.damage_ticks:
		if String(tick.get("source_ability", "")) == source_ability:
			return true
	return false

func _has_modifier(target: Node, source: String) -> bool:
	for modifier: Dictionary in target.modifiers:
		if String(modifier.get("source", "")) == source:
			return true
	return false
