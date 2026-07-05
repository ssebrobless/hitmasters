extends SceneTree

# Decision #27 acceptance (soft body collision) + minion engagement slots.
# Boots the real Arena so resolve_body_separation runs with true wiring.

const ARENA_SCENE := "res://scenes/Arena.tscn"
const MinionScript := preload("res://scripts/game/minion.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "3v3"
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("separation check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	_check_pair_separates(arena, failures)
	_check_latch_pair_exempt(arena, failures)
	_check_push_is_soft(arena, failures)
	_check_minion_slots(arena, failures)
	print("separation failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _two_creatures(arena: Node) -> Array:
	var a: Node = arena.player_squad[0] if arena.get("player_squad") != null and arena.player_squad.size() > 0 else arena.player
	var b: Node = arena.bots[0]
	return [a, b]

func _check_pair_separates(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	var anchor: Vector2 = Vector2(0.0, 0.0)
	a.global_position = anchor
	b.global_position = anchor + Vector2(2.0, 0.0)
	for i in 60:
		arena.resolve_body_separation()
	var gap: float = a.global_position.distance_to(b.global_position)
	var min_gap: float = a.body_radius + b.body_radius
	if gap < min_gap - 0.5:
		failures.append("overlapped creatures should separate to ring contact within 60 ticks (gap=%.1f need %.1f)" % [gap, min_gap])

func _check_latch_pair_exempt(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	a.attach_to_victim(b, 5.0, "TestLatch", 99.0)
	b.receive_latch(a, 5.0, "TestLatch")
	a.global_position = b.global_position + Vector2(3.0, 0.0)
	var before: float = a.global_position.distance_to(b.global_position)
	arena.resolve_body_separation()
	var after: float = a.global_position.distance_to(b.global_position)
	if absf(after - before) > 0.01:
		failures.append("latch pair must be exempt from separation (gap %.2f -> %.2f)" % [before, after])
	a.release_latch("test_done")

func _check_push_is_soft(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	a.global_position = Vector2(40.0, 40.0)
	b.global_position = a.global_position + Vector2(1.0, 0.0)
	var a_before: Vector2 = a.global_position
	arena.resolve_body_separation()
	var moved: float = a.global_position.distance_to(a_before)
	if moved > arena.SEPARATION_MAX_PUSH_PX + 0.01:
		failures.append("per-tick separation push should be capped at %.1f px (moved %.2f)" % [arena.SEPARATION_MAX_PUSH_PX, moved])

func _check_minion_slots(arena: Node, failures: Array[String]) -> void:
	var target: Node = arena.bots[0]
	var offsets := {}
	for slot in 5:
		var minion := MinionScript.new()
		arena.add_child(minion)
		minion.setup(arena, 0, Vector2.ZERO, "melee", Vector2.ZERO, arena.huts[0] if arena.huts.size() > 0 else null, slot)
		var offset: Vector2 = minion._engage_offset(target)
		offsets[offset.round()] = true
		minion.queue_free()
	if offsets.size() < 4:
		failures.append("defender slots should produce distinct engagement angles (got %d unique of 5)" % offsets.size())
