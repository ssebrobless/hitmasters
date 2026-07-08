extends SceneTree
## BB-VIS-3: bots only act on enemies their team can see. An enemy in fog is not perceivable
## (dropped from target scans); after losing sight of a seen enemy the bot forms an INVESTIGATE
## intent toward the stored last-known point (never the live position).

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("vision_bot check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("vision_bot check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	arena.cover_rects.clear()
	arena.day_timer = 120.0 * 0.30  # day phase

	var bot: Node = _first_bot(arena, 1)
	var enemy: Node = arena.player  # blue player is the red bot's enemy
	var brain = arena.bot_brain
	if bot == null or enemy == null or brain == null:
		push_error("vision_bot check: need a red bot + blue player; bot=%s enemy=%s" % [str(bot), str(enemy)])
		quit(1)
		return

	# 1) Adjacent enemy -> perceivable.
	enemy.global_position = bot.global_position + Vector2(12.0, 0.0)
	if not brain._can_perceive(bot, enemy):
		failures.append("adjacent enemy should be perceivable by the bot")

	# 2) Enemy in fog with no memory -> not perceivable and not chosen as a target.
	arena.team_vision[1].clear()
	arena.team_reveals[1].clear()
	enemy.global_position = bot.global_position + Vector2(9000.0, 0.0)
	if brain._can_perceive(bot, enemy):
		failures.append("far unseen enemy must not be perceivable")
	var fog_intent: Dictionary = brain._best_target_intent(bot)
	if fog_intent.get("target", null) == enemy:
		failures.append("bot must not target an enemy it cannot see")
	# With no memory there is nothing to investigate either.
	if not brain._investigate_intent(bot).is_empty():
		failures.append("no last-known memory should yield no investigate intent")

	# 3) See the enemy, then lose sight -> INVESTIGATE the stored last-known point.
	enemy.global_position = bot.global_position + Vector2(12.0, 0.0)
	arena._tick_team_vision(0.2)                 # red team records the sighting
	var last_seen: Vector2 = enemy.global_position
	enemy.global_position = bot.global_position + Vector2(9000.0, 0.0)
	var investigate: Dictionary = brain._investigate_intent(bot)
	if String(investigate.get("mode", "")) != "investigate":
		failures.append("losing sight of a seen enemy should form an investigate intent; got %s" % str(investigate))
	elif (investigate.get("point", Vector2.INF) as Vector2).distance_to(last_seen) > 1.0:
		failures.append("investigate should target the last-known point %s, not live pos; got %s" % [str(last_seen), str(investigate.get("point"))])

	print("vision_bot failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _first_bot(arena: Node, team: int) -> Node:
	for bot: Node in arena.bots:
		if bot != null and is_instance_valid(bot) and ("team" in bot) and int(bot.get("team")) == team:
			if bot.has_method("is_alive") and not bot.is_alive():
				continue
			return bot
	return null
