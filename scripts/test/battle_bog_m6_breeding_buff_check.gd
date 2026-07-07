extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
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
		push_error("m6 breeding buff check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or not arena.has_method("get_team_breeding_buff_summary"):
		push_error("Arena scene did not expose breeding buff state; current_scene=%s" % str(arena))
		quit(1)
		return

	_check_timed_breeding_completion(arena, failures)
	_check_buff_effects_and_caps(arena, failures)
	_check_boss_activation_after_completed_breeds(arena, failures)

	print("m6_breeding_buffs failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_timed_breeding_completion(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(actor.team)
	actor.global_position = habitat.get_center()
	var before_speed: float = actor.get_speed_px()
	_satiate(actor)
	var deposited: bool = arena._try_manual_habitat_deposit(actor)
	var post_deposit_hunger := absf(float(actor.get("hunger")) - 80.0) < 0.001 and not bool(actor.get("hunger_satiated"))
	var first_cues: Array = arena.stock_manager.get_breeding_cues(actor.team)
	var immediate_summary: Dictionary = arena.get_team_breeding_buff_summary(actor.team)
	var no_immediate_stack := deposited \
		and post_deposit_hunger \
		and first_cues.size() == 1 \
		and int(immediate_summary.get("total_stacks", -1)) == 0 \
		and int(arena.get_boss_progress_state().get("bred_count", -1)) == 0

	arena.habitat_deposit_feedback_timer = 0.0
	_satiate(actor)
	var duplicate_blocked: bool = not arena._try_manual_habitat_deposit(actor) \
		and arena.stock_manager.get_breeding_cues(actor.team).size() == 1

	arena._tick_breeding(StockManagerScript.BREEDING_DURATION_SEC - 1.0)
	var almost_summary: Dictionary = arena.get_team_breeding_buff_summary(actor.team)
	var still_pending: bool = int(almost_summary.get("total_stacks", -1)) == 0 \
		and int(arena.get_boss_progress_state().get("bred_count", -1)) == 0 \
		and arena.stock_manager.get_breeding_cues(actor.team).size() == 1

	arena._tick_breeding(1.2)
	var complete_summary: Dictionary = arena.get_team_breeding_buff_summary(actor.team)
	var family_counts: Dictionary = complete_summary.get("family_counts", {})
	var effects: Dictionary = complete_summary.get("effects", {})
	var completed: bool = int(complete_summary.get("total_stacks", -1)) == 1 \
		and int(family_counts.get("bird", 0)) == 1 \
		and float(effects.get("move_speed", 0.0)) >= 0.029 \
		and actor.get_speed_px() > before_speed * 1.02 \
		and int(arena.get_boss_progress_state().get("bred_count", -1)) == 1 \
		and arena.stock_manager.get_breeding_cues(actor.team).is_empty()

	if not no_immediate_stack or not duplicate_blocked or not still_pending or not completed:
		failures.append("breeding deposit should reset hunger to 80%%, deny duplicates, wait 45s, then grant bird speed stack; deposited=%s post_hunger=%s no_immediate=%s duplicate=%s pending=%s completed=%s first=%s complete=%s speed %.2f->%.2f progress=%s" % [
			str(deposited),
			str(post_deposit_hunger),
			str(no_immediate_stack),
			str(duplicate_blocked),
			str(still_pending),
			str(completed),
			str(first_cues),
			str(complete_summary),
			before_speed,
			actor.get_speed_px(),
			str(arena.get_boss_progress_state())
		])

func _check_buff_effects_and_caps(arena: Node, failures: Array[String]) -> void:
	var duck: Node = arena.player_squad[0]
	var turtle: Node = arena.player_squad[1]
	var turtle_before := float(turtle.max_health)
	var reptile_result: Dictionary = arena._add_breeding_buff_stack(0, "reptile")
	var reptile_ok := bool(reptile_result.get("accepted", false)) and float(turtle.max_health) > turtle_before * 1.02

	var damage_before: float = duck.make_damage_event(100.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "probe").amount
	var mammal_result: Dictionary = arena._add_breeding_buff_stack(0, "mammal")
	var damage_after: float = duck.make_damage_event(100.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "probe").amount
	var mammal_ok: bool = bool(mammal_result.get("accepted", false)) and damage_after > damage_before * 1.02

	duck.q_timer = 10.0
	var crawly_result: Dictionary = arena._add_breeding_buff_stack(0, "crawly")
	duck._tick_timers(1.0)
	var crawly_ok: bool = bool(crawly_result.get("accepted", false)) and duck.q_timer < 8.99

	var amphibian_result: Dictionary = arena._add_breeding_buff_stack(0, "amphibian")
	duck.health = duck.max_health * 0.5
	var health_before := float(duck.health)
	duck._tick_timers(1.0)
	var amphibian_ok := bool(amphibian_result.get("accepted", false)) and float(duck.health) > health_before

	var red_family_results := [
		arena._add_breeding_buff_stack(1, "bird"),
		arena._add_breeding_buff_stack(1, "bird"),
		arena._add_breeding_buff_stack(1, "bird"),
		arena._add_breeding_buff_stack(1, "bird")
	]
	var red_summary: Dictionary = arena.get_team_breeding_buff_summary(1)
	var red_counts: Dictionary = red_summary.get("family_counts", {})
	var family_cap_ok := bool(red_family_results[0].get("accepted", false)) \
		and bool(red_family_results[1].get("accepted", false)) \
		and bool(red_family_results[2].get("accepted", false)) \
		and not bool(red_family_results[3].get("accepted", true)) \
		and String(red_family_results[3].get("reason", "")) == "family_cap" \
		and int(red_counts.get("bird", 0)) == 3

	var team_sixth: Dictionary = arena._add_breeding_buff_stack(0, "reptile")
	var team_seventh: Dictionary = arena._add_breeding_buff_stack(0, "mammal")
	var blue_summary: Dictionary = arena.get_team_breeding_buff_summary(0)
	var team_cap_ok := bool(team_sixth.get("accepted", false)) \
		and not bool(team_seventh.get("accepted", true)) \
		and String(team_seventh.get("reason", "")) == "team_cap" \
		and int(blue_summary.get("total_stacks", 0)) == 6

	if not reptile_ok or not mammal_ok or not crawly_ok or not amphibian_ok or not family_cap_ok or not team_cap_ok:
		failures.append("breeding family buffs should change stats and enforce family/team caps; reptile=%s mammal=%s crawly=%s amphibian=%s family_cap=%s team_cap=%s blue=%s red=%s damage %.2f->%.2f health %.2f->%.2f q=%.2f" % [
			str(reptile_ok),
			str(mammal_ok),
			str(crawly_ok),
			str(amphibian_ok),
			str(family_cap_ok),
			str(team_cap_ok),
			str(blue_summary),
			str(red_summary),
			damage_before,
			damage_after,
			health_before,
			float(duck.health),
			float(duck.q_timer)
		])

func _check_boss_activation_after_completed_breeds(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var accepted := 0
	for _i in 4:
		arena.habitat_deposit_feedback_timer = 0.0
		_satiate(actor)
		if arena._try_manual_habitat_deposit(actor):
			accepted += 1
		arena._tick_breeding(StockManagerScript.BREEDING_DURATION_SEC + 0.1)
	var progress: Dictionary = arena.get_boss_progress_state()
	var blue_boss := _zone(arena.get_animal_zone_state(), "blue", "Boss")
	var red_boss := _zone(arena.get_animal_zone_state(), "red", "Boss")
	var boss_ok := accepted == 4 \
		and int(progress.get("bred_count", 0)) == 5 \
		and int(progress.get("activations", 0)) == 1 \
		and bool(progress.get("boss_active", false)) \
		and bool(blue_boss.get("active", false)) \
		and bool(red_boss.get("active", false))
	if not boss_ok:
		failures.append("boss zones should activate after five completed breeding cues, not raw deposits; accepted=%d progress=%s blue=%s red=%s" % [
			accepted,
			str(progress),
			str(blue_boss),
			str(red_boss)
		])

func _satiate(actor: Node) -> void:
	var habitat: Rect2 = actor.arena.terrain_map.get_team_habitat_rect(actor.team)
	actor.global_position = habitat.get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true

func _zone(zones: Array, side: String, group: String) -> Dictionary:
	for zone: Dictionary in zones:
		if String(zone.get("side", "")) == side and String(zone.get("group", "")) == group:
			return zone
	return {}
