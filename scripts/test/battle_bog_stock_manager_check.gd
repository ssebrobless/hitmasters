extends SceneTree

const StockManagerScript := preload("res://scripts/game/stock_manager.gd")

class FakeActor extends Node:
	var team: int
	var creature_id: String

	func _init(new_team := 0, new_creature_id := "") -> void:
		team = new_team
		creature_id = new_creature_id

func _initialize() -> void:
	var failures: Array[String] = []
	var register_ok := _check_register_slots(failures)
	var lifecycle_ok := _check_ko_respawn_and_exhaustion(failures)
	var habitat_ok := _check_habitat_visit_recording(failures)
	var reset_ok := _check_reset(failures)
	var passed := register_ok and lifecycle_ok and habitat_ok and reset_ok

	print("stock_manager register=%s lifecycle=%s habitat=%s reset=%s" % [
		str(register_ok),
		str(lifecycle_ok),
		str(habitat_ok),
		str(reset_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_register_slots(failures: Array[String]) -> bool:
	var manager = StockManagerScript.new()
	var blue_active := _actor(0, "beaver")
	var blue_reserve := _actor(0, "chorus_frog")
	var red_active := _actor(1, "mink")
	manager.register_slot(0, 0, "beaver", blue_active, 3)
	manager.register_slot(0, 1, "chorus_frog", blue_reserve, 2)
	manager.register_slot(1, 0, "mink", red_active, 1)

	var active_slot: Dictionary = manager.get_slot_for_actor(blue_active)
	var reserve_slot: Dictionary = manager.get_slot(0, 1)
	var red_slot: Dictionary = manager.get_slot(1, 0)
	var ok: bool = manager.has_actor(blue_active) \
		and manager.has_actor(blue_reserve) \
		and manager.has_actor(red_active) \
		and int(active_slot.get("team", -1)) == 0 \
		and int(active_slot.get("slot_index", -1)) == 0 \
		and String(active_slot.get("creature_id", "")) == "beaver" \
		and active_slot.get("actor", null) == blue_active \
		and int(active_slot.get("stocks_remaining", -1)) == 3 \
		and int(active_slot.get("max_stocks", -1)) == 3 \
		and String(active_slot.get("state", "")) == StockManagerScript.STATE_FIELD \
		and absf(float(active_slot.get("respawn_timer", -1.0))) < 0.001 \
		and int(reserve_slot.get("stocks_remaining", -1)) == 2 \
		and String(reserve_slot.get("creature_id", "")) == "chorus_frog" \
		and int(red_slot.get("team", -1)) == 1 \
		and int(red_slot.get("stocks_remaining", -1)) == 1
	if not ok:
		failures.append("register expected addressable blue/red slots with field state and configured stock counts; active=%s reserve=%s red=%s" % [
			str(active_slot),
			str(reserve_slot),
			str(red_slot)
		])
	return ok

func _check_ko_respawn_and_exhaustion(failures: Array[String]) -> bool:
	var manager = StockManagerScript.new()
	var blue_active := _actor(0, "beaver")
	var blue_reserve := _actor(0, "chorus_frog")
	var red_active := _actor(1, "mink")
	manager.register_slot(0, 0, "beaver", blue_active, 2)
	manager.register_slot(0, 1, "chorus_frog", blue_reserve, 1)
	manager.register_slot(1, 0, "mink", red_active, 1)

	var first_ko: Dictionary = manager.record_ko(blue_active, 1.5)
	var first_ko_ok := int(first_ko.get("stocks_remaining", -1)) == 1 \
		and String(first_ko.get("state", "")) == StockManagerScript.STATE_RESPAWNING \
		and absf(float(first_ko.get("respawn_timer", 0.0)) - 1.5) < 0.001 \
		and not manager.can_respawn(blue_active)

	var ticked: Dictionary = manager.tick_actor_respawn(blue_active, 0.5)
	var tick_ok := absf(float(ticked.get("respawn_timer", -1.0)) - 1.0) < 0.001 \
		and not manager.can_respawn(blue_active)

	var ready: Dictionary = manager.tick_actor_respawn(blue_active, 1.1)
	var ready_ok := absf(float(ready.get("respawn_timer", -1.0))) < 0.001 \
		and manager.can_respawn(blue_active)

	manager.mark_respawned(blue_active)
	var respawned: Dictionary = manager.get_slot_for_actor(blue_active)
	var respawned_ok := String(respawned.get("state", "")) == StockManagerScript.STATE_FIELD \
		and absf(float(respawned.get("respawn_timer", -1.0))) < 0.001 \
		and int(respawned.get("stocks_remaining", -1)) == 1

	var exhausted_active: Dictionary = manager.record_ko(blue_active, 0.25)
	var active_exhausted_ok := int(exhausted_active.get("stocks_remaining", -1)) == 0 \
		and String(exhausted_active.get("state", "")) == StockManagerScript.STATE_EXHAUSTED \
		and manager.is_exhausted(blue_active) \
		and not manager.can_respawn(blue_active) \
		and not manager.team_exhausted(0)

	var exhausted_reserve: Dictionary = manager.record_ko(blue_reserve, 0.0)
	var team_exhausted_ok := int(exhausted_reserve.get("stocks_remaining", -1)) == 0 \
		and String(exhausted_reserve.get("state", "")) == StockManagerScript.STATE_EXHAUSTED \
		and manager.team_exhausted(0) \
		and not manager.team_exhausted(1) \
		and not manager.team_exhausted(99)

	var unknown_actor := _actor(0, "otter")
	var unknown_ok := manager.record_ko(unknown_actor, 1.0).is_empty() \
		and manager.tick_actor_respawn(unknown_actor, 1.0).is_empty() \
		and manager.stocks_remaining(unknown_actor) == StockManagerScript.MAX_STOCKS \
		and manager.max_stocks(unknown_actor) == StockManagerScript.MAX_STOCKS \
		and not manager.is_exhausted(unknown_actor)

	var ok: bool = first_ko_ok and tick_ok and ready_ok and respawned_ok and active_exhausted_ok and team_exhausted_ok and unknown_ok
	if not ok:
		failures.append("lifecycle expected KO->respawn->field then exhaustion/team exhaustion; first=%s tick=%s ready=%s respawned=%s active=%s reserve=%s unknown=%s" % [
			str(first_ko),
			str(ticked),
			str(ready),
			str(respawned),
			str(exhausted_active),
			str(exhausted_reserve),
			str(unknown_ok)
		])
	return ok

func _check_habitat_visit_recording(failures: Array[String]) -> bool:
	var manager = StockManagerScript.new()
	var blue_active := _actor(0, "beaver")
	var red_active := _actor(1, "mink")
	manager.register_slot(0, 0, "beaver", blue_active, 3)
	manager.register_slot(1, 2, "mink", red_active, 2)

	manager.record_habitat_visit(blue_active)
	manager.record_habitat_visit(red_active)

	var blue_visit: Dictionary = manager.habitat_visits[0]
	var red_visit: Dictionary = manager.habitat_visits[1]
	var ok: bool = manager.habitat_visits.size() == 2 \
		and int(blue_visit.get("team", -1)) == 0 \
		and int(blue_visit.get("slot_index", -1)) == 0 \
		and String(blue_visit.get("creature_id", "")) == "beaver" \
		and blue_visit.get("actor", null) == blue_active \
		and int(red_visit.get("team", -1)) == 1 \
		and int(red_visit.get("slot_index", -1)) == 2 \
		and String(red_visit.get("creature_id", "")) == "mink" \
		and red_visit.get("actor", null) == red_active
	if not ok:
		failures.append("habitat expected ordered visit records with team, slot, creature, and actor; visits=%s" % str(manager.habitat_visits))
	return ok

func _check_reset(failures: Array[String]) -> bool:
	var manager = StockManagerScript.new()
	var actor := _actor(0, "beaver")
	manager.register_slot(0, 0, "beaver", actor, 3)
	manager.record_habitat_visit(actor)
	manager.reset()
	var ok: bool = manager.slots.is_empty() and manager.actor_keys.is_empty() and manager.habitat_visits.is_empty()
	if not ok:
		failures.append("reset expected slots, actor keys, and visits to clear; slots=%s actor_keys=%s visits=%s" % [
			str(manager.slots),
			str(manager.actor_keys),
			str(manager.habitat_visits)
		])
	return ok

func _actor(team: int, creature_id: String) -> FakeActor:
	var actor := FakeActor.new(team, creature_id)
	get_root().add_child(actor)
	return actor
