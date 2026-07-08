extends SceneTree
## BB-BOSS-5 follow-up: the boss rewards that were recorded-but-inert now bite in combat.
## Covers the habitat-stock stat buffs (damage_reduction, healing_received, hunger_depletion,
## size, vision_range) and the Teratornis center reward Sky Ambush (empowered next hit).

const ARENA_SCENE := "res://scenes/Arena.tscn"
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("boss_reward_wiring check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_reward_wiring check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	var player: Node = arena.player
	if player == null:
		push_error("boss_reward_wiring check: no player")
		quit(1)
		return

	# 1) damage_reduction (American Mastodon): incoming damage is scaled down.
	var base_incoming: float = player._modified_incoming_damage(_incoming(100.0))
	arena._add_boss_stock_stack(0, "american_mastodon")
	var buffed_incoming: float = player._modified_incoming_damage(_incoming(100.0))
	if not (buffed_incoming < base_incoming - 0.01):
		failures.append("damage_reduction should lower incoming damage; %.2f -> %.2f" % [base_incoming, buffed_incoming])

	# 2) healing_received (Platyhystrix): heals are amplified.
	player.health = 1.0
	player.heal(20.0)
	var base_heal: float = float(player.health) - 1.0
	arena._add_boss_stock_stack(0, "platyhystrix")
	player.health = 1.0
	player.heal(20.0)
	var buffed_heal: float = float(player.health) - 1.0
	if not (buffed_heal > base_heal + 0.1):
		failures.append("healing_received should amplify heals; %.2f -> %.2f" % [base_heal, buffed_heal])

	# 3+4) hunger_depletion + size (Arthropleura): slower drain, bigger body.
	player.hunger_satiated = false
	player.hunger = 300.0
	player._tick_hunger(1.0)
	var base_drain := 300.0 - float(player.hunger)
	var base_radius := float(player.body_radius)
	arena._add_boss_stock_stack(0, "arthropleura")
	player.hunger = 300.0
	player._tick_hunger(1.0)
	var buffed_drain := 300.0 - float(player.hunger)
	if not (buffed_drain < base_drain - 0.001):
		failures.append("hunger_depletion should slow the drain; %.3f -> %.3f" % [base_drain, buffed_drain])
	if not (float(player.body_radius) > base_radius + 0.001):
		failures.append("size buff should enlarge body_radius; %.3f -> %.3f" % [base_radius, float(player.body_radius)])

	# 5) vision_range (Teratornis habitat buff): team sight range extends.
	var base_vision := float(arena.get_team_vision_range(0))
	arena._add_boss_stock_stack(0, "teratornis")
	if not (float(arena.get_team_vision_range(0)) > base_vision + 0.5):
		failures.append("vision_range buff should extend team sight; %.1f -> %.1f" % [base_vision, float(arena.get_team_vision_range(0))])

	# 6) Sky Ambush (Teratornis center reward): empowered next hit after the no-damage window.
	arena._grant_center_reward(0, "teratornis")
	player.undamaged_timer = 10.0
	var empowered: float = player.modify_outgoing_damage(100.0)
	if not (empowered > 120.0):
		failures.append("Sky Ambush should empower the next hit after 8s undamaged; got %.1f" % empowered)
	if not is_equal_approx(float(player.undamaged_timer), 0.0):
		failures.append("Sky Ambush should reset the window when consumed; timer=%.2f" % float(player.undamaged_timer))
	var normal: float = player.modify_outgoing_damage(100.0)
	if normal > empowered - 5.0:
		failures.append("second consecutive hit should not be empowered; got %.1f" % normal)

	print("boss_reward_wiring failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _incoming(amount: float) -> Resource:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_AREA, DamageEventScript.PLANE_GROUND, null, "test")
	event.region_mult = 1.0
	return event
