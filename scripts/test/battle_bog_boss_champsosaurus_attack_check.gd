extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("champsosaurus_attack check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("champsosaurus_attack check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_attack(arena, failures)

	print("boss_champsosaurus_attack failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _boss_actor(arena: Node, zone_id: String) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == zone_id:
			return enc
	return null

func _subsequence(seq: Array, sub: Array) -> bool:
	var i := 0
	for x in seq:
		if i < sub.size() and String(x) == String(sub[i]):
			i += 1
	return i == sub.size()

func _check_attack(arena: Node, failures: Array[String]) -> void:
	for _i in range(5):
		arena._record_bred_animal(0)
	var boss := _boss_actor(arena, "blue:Boss")
	if boss == null or not boss.has_method("is_boss_actor"):
		failures.append("no blue boss actor to attack-test")
		return
	boss.set_physics_process(false)  # drive the AI manually for determinism

	# Plant the human creature just in front of the boss, within bite reach & leash.
	var victim: Node = arena.player
	victim.global_position = boss.global_position + Vector2(50.0, 0.0)
	var hp_before := float(victim.get("health"))

	# Drive the AI and record the phase sequence.
	var phases: Array[String] = []
	for _i in range(80):
		boss._physics_process(0.05)
		var ph := String(boss.get("phase"))
		if phases.is_empty() or phases[phases.size() - 1] != ph:
			phases.append(ph)
		if not boss.is_alive():
			break

	# The major attack must follow TEL -> HIT -> FX -> RECOVERY in order.
	if not _subsequence(phases, ["tel", "hit", "fx", "recovery"]):
		failures.append("attack should follow TEL->HIT->FX->RECOVERY; observed=%s" % str(phases))
	# The bite must damage a creature caught in the HIT window.
	if float(victim.get("health")) >= hp_before:
		failures.append("boss bite should damage a creature in range; hp %.1f->%.1f" % [hp_before, float(victim.get("health"))])

	# Recovery opens a weakpoint: incoming damage is amplified vs the neutral state.
	boss.phase = "recovery"
	if not boss.is_weakpoint_open():
		failures.append("weakpoint should be open during recovery")
	var h0 := float(boss.get("health"))
	boss.take_damage(20.0, 0, arena.player)
	var recovery_drop := h0 - float(boss.get("health"))
	boss.phase = "idle"
	if boss.is_weakpoint_open():
		failures.append("weakpoint should be closed outside recovery")
	var h1 := float(boss.get("health"))
	boss.take_damage(20.0, 0, arena.player)
	var idle_drop := h1 - float(boss.get("health"))
	if recovery_drop <= idle_drop + 0.5:
		failures.append("recovery weakpoint should amplify damage; recovery=%.1f idle=%.1f" % [recovery_drop, idle_drop])
