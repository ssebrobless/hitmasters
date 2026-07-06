extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const StockManagerScript := preload("res://scripts/game/stock_manager.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("m6 breeding interrupt check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or not ("breeding_actors" in arena):
		push_error("Arena scene did not expose breeding actors; current_scene=%s" % str(arena))
		quit(1)
		return

	_check_breeding_raid_window(arena, failures)

	print("m6_breeding_interrupt failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_breeding_raid_window(arena: Node, failures: Array[String]) -> void:
	var breeder: Node = arena.player
	var raider: Node = arena.bots[0] if not arena.bots.is_empty() else null
	if breeder == null or raider == null:
		failures.append("interrupt check needs blue breeder and red raider")
		return

	_satiate_at_home(breeder)
	var deposited: bool = arena._try_manual_habitat_deposit(breeder)
	var target: Node = arena.breeding_actors[0] if not arena.breeding_actors.is_empty() else null
	if not deposited or target == null:
		failures.append("deposit should spawn one breeding actor; deposited=%s actors=%d" % [str(deposited), arena.breeding_actors.size()])
		return
	breeder.global_position = arena.get_team_spawn(breeder.team)

	var starting_health := float(target.get("health"))
	_attack_from(raider, target, target.global_position + Vector2(10.0, 0.0), 999.0)
	var closed_blocked: bool = arena.breeding_actors.has(target) \
		and arena.stock_manager.get_breeding_cues(breeder.team).size() == 1 \
		and absf(float(target.get("health")) - starting_health) < 0.001

	arena.huts_lost[breeder.team] = 1
	_attack_from(raider, target, arena.terrain_map.get_team_habitat_rect(breeder.team).end + Vector2(12.0, -6.0), 999.0)
	var outside_blocked: bool = arena.breeding_actors.has(target) \
		and arena.stock_manager.get_breeding_cues(breeder.team).size() == 1 \
		and absf(float(target.get("health")) - starting_health) < 0.001

	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(breeder.team)
	_attack_from(raider, target, habitat.get_center() + Vector2(8.0, 0.0), starting_health + 20.0)
	var denied: bool = not arena.breeding_actors.has(target) \
		and arena.stock_manager.get_breeding_cues(breeder.team).is_empty() \
		and int(arena.get_boss_progress_state().get("bred_count", -1)) == 0

	arena._tick_breeding(StockManagerScript.BREEDING_DURATION_SEC + 0.1)
	var stayed_denied := int(arena.get_boss_progress_state().get("bred_count", -1)) == 0 \
		and int(arena.get_team_breeding_buff_summary(breeder.team).get("total_stacks", -1)) == 0

	if not closed_blocked or not outside_blocked or not denied or not stayed_denied:
		failures.append("breeding actor should be denied only by an enemy inside an exposed habitat; closed=%s outside=%s denied=%s stayed=%s health %.2f->%s actors=%d cues=%s progress=%s" % [
			str(closed_blocked),
			str(outside_blocked),
			str(denied),
			str(stayed_denied),
			starting_health,
			str(target.get("health") if target != null and is_instance_valid(target) else "freed"),
			arena.breeding_actors.size(),
			str(arena.stock_manager.get_breeding_cues(breeder.team)),
			str(arena.get_boss_progress_state())
		])

func _satiate_at_home(actor: Node) -> void:
	var habitat: Rect2 = actor.arena.terrain_map.get_team_habitat_rect(actor.team)
	actor.global_position = habitat.get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true

func _attack_from(attacker: Node, target: Node, attacker_position: Vector2, damage: float) -> Array:
	attacker.global_position = attacker_position
	attacker.last_aim_direction = (target.global_position - attacker.global_position).normalized()
	attacker.input_frame = null
	return MeleeHit.hit(attacker, 96.0, damage, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Breeding Raid Probe")
