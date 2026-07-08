extends SceneTree
## BB-BOSS-5 follow-up: the boss rewards that were recorded-but-inert now bite in combat.
## Covers the habitat-stock stat buffs (damage_reduction, healing_received, hunger_depletion,
## size, vision_range), plus center rewards Sky Ambush, Iron Hide, Tidal Venom, Spore Ward, and Swarm Growth.

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
	var enemy: Node = _first_enemy(arena)
	if player == null:
		push_error("boss_reward_wiring check: no player")
		quit(1)
		return
	if enemy == null:
		push_error("boss_reward_wiring check: no enemy")
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

	# 7) Iron Hide (American Mastodon center reward): after 4s out of combat, regen resumes until damaged/full.
	arena._grant_center_reward(0, "american_mastodon")
	player.health = player.max_health - 40.0
	player.undamaged_timer = 3.9
	player._tick_iron_hide_regen(1.0)
	var pre_ramp_health := float(player.health)
	if pre_ramp_health > float(player.max_health) - 39.9:
		failures.append("Iron Hide should not regen before the 4s damage-free window; health=%.2f" % pre_ramp_health)
	player.undamaged_timer = 4.1
	player._tick_iron_hide_regen(1.0)
	var ramped_health := float(player.health)
	if not (ramped_health > pre_ramp_health + 0.1):
		failures.append("Iron Hide should regen after 4s without damage; %.2f -> %.2f" % [pre_ramp_health, ramped_health])
	player.take_damage_event(enemy.make_damage_event(5.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "iron_hide_reset"))
	if not (float(player.undamaged_timer) <= 0.001):
		failures.append("Iron Hide should reset its no-damage window on real health damage; timer=%.3f" % float(player.undamaged_timer))

	# 8) Tidal Venom (Champsosaurus center reward): landed hits apply a capped DOT.
	arena._grant_center_reward(0, "champsosaurus")
	enemy.damage_ticks.clear()
	enemy.health = enemy.max_health
	enemy.take_damage_event(player.make_damage_event(40.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "reward_probe"))
	var venom_count := _dot_count(enemy, "Tidal Venom")
	if venom_count != 1:
		failures.append("Tidal Venom should apply exactly one DOT on a landed hit; count=%d ticks=%s" % [venom_count, str(enemy.damage_ticks)])
	elif float(enemy.damage_ticks[0].get("amount_remaining", 0.0)) <= 0.1:
		failures.append("Tidal Venom DOT should carry damage; tick=%s" % str(enemy.damage_ticks[0]))
	# Existing Tidal Venom ticks must not recursively add new Tidal Venom stacks.
	enemy._tick_timers(1.0)
	if _dot_count(enemy, "Tidal Venom") > 1:
		failures.append("Tidal Venom DOT ticks should not recursively add stacks; ticks=%s" % str(enemy.damage_ticks))

	# 9) Spore Ward (Platyhystrix center reward): periodic shield absorbs damage and slows the breaker.
	arena._grant_center_reward(0, "platyhystrix")
	player.spore_ward_timer = 0.0
	player.spore_ward_absorb = 0.0
	player.health = player.max_health
	enemy.modifiers.clear()
	player.tick_sim(0.05)
	var ward_amount := float(player.spore_ward_absorb)
	if not (ward_amount > player.max_health * 0.15):
		failures.append("Spore Ward should refresh a shield from the center reward; absorb=%.2f max=%.2f" % [ward_amount, float(player.max_health)])
	var ward_health := float(player.health)
	player.take_damage_event(enemy.make_damage_event(ward_amount * 0.5, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "ward_probe"))
	if float(player.health) < ward_health - 0.001:
		failures.append("Spore Ward should absorb shield-sized damage before health loss; %.2f -> %.2f" % [ward_health, float(player.health)])
	player.take_damage_event(enemy.make_damage_event(ward_amount + 50.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "ward_break"))
	if not (float(player.spore_ward_absorb) <= 0.001):
		failures.append("Spore Ward should break when depleted; absorb=%.3f" % float(player.spore_ward_absorb))
	if not (enemy.get_modifier_value("move_speed_mult", 1.0) < 1.0):
		failures.append("Spore Ward breaker should be slowed; modifiers=%s" % str(enemy.modifiers))

	# 10) Swarm Growth (Arthropleura center reward): scored kills grow team damage + body size, capped.
	arena._grant_center_reward(0, "arthropleura")
	var growth_base_radius := float(player.body_radius)
	var growth_base_damage: float = player.modify_outgoing_damage(100.0)
	player.on_kill(enemy)
	var growth_state: Dictionary = arena.get_team_combat_reward_state(0).get("arthropleura", {})
	var growth_bonus := float(growth_state.get("growth_bonus", 0.0))
	if int(growth_state.get("growth_stacks", 0)) != 1:
		failures.append("Swarm Growth should add one kill stack after on_kill; state=%s" % str(growth_state))
	if not (growth_bonus > 0.0):
		failures.append("Swarm Growth should report a positive growth bonus; state=%s" % str(growth_state))
	if not (float(player.body_radius) > growth_base_radius + 0.001):
		failures.append("Swarm Growth should enlarge body_radius; %.3f -> %.3f" % [growth_base_radius, float(player.body_radius)])
	if not (player.modify_outgoing_damage(100.0) > growth_base_damage + 0.1):
		failures.append("Swarm Growth should increase outgoing damage after a kill")
	for i in 12:
		player.on_kill(enemy)
	growth_state = arena.get_team_combat_reward_state(0).get("arthropleura", {})
	if int(growth_state.get("growth_stacks", 0)) != arena.CENTER_KILL_GROWTH_MAX_STACKS:
		failures.append("Swarm Growth should cap at %d stacks; state=%s" % [arena.CENTER_KILL_GROWTH_MAX_STACKS, str(growth_state)])

	print("boss_reward_wiring failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _incoming(amount: float) -> Resource:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_AREA, DamageEventScript.PLANE_GROUND, null, "test")
	event.region_mult = 1.0
	return event

func _first_enemy(arena: Node) -> Node:
	var player: Node = arena.player
	var player_team := int(player.get("team")) if player != null and ("team" in player) else 0
	for entity: Node in arena.entities:
		if entity == null or not is_instance_valid(entity) or not ("team" in entity):
			continue
		if int(entity.get("team")) == player_team:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		return entity
	return null

func _dot_count(target: Node, source_ability: String) -> int:
	var count := 0
	for tick: Dictionary in target.damage_ticks:
		if String(tick.get("source_ability", "")) == source_ability:
			count += 1
	return count
