extends RefCounted

const MAX_STOCKS := 3
const STATE_FIELD := "field"
const STATE_RESPAWNING := "respawning"
const STATE_EXHAUSTED := "exhausted"

var slots: Dictionary = {}
var actor_keys: Dictionary = {}
var habitat_visits: Array[Dictionary] = []

func reset() -> void:
	slots.clear()
	actor_keys.clear()
	habitat_visits.clear()

func register_slot(team: int, slot_index: int, creature_id: String, actor: Node, max_stocks := MAX_STOCKS) -> void:
	var key := _slot_key(team, slot_index)
	if not slots.has(key):
		slots[key] = {
			"team": team,
			"slot_index": slot_index,
			"creature_id": creature_id,
			"actor": actor,
			"stocks_remaining": max_stocks,
			"max_stocks": max_stocks,
			"state": STATE_FIELD,
			"respawn_timer": 0.0
		}
	else:
		slots[key]["actor"] = actor
		slots[key]["creature_id"] = creature_id
	if actor != null and is_instance_valid(actor):
		actor_keys[_actor_key(actor)] = key

func has_actor(actor: Node) -> bool:
	return actor != null and actor_keys.has(_actor_key(actor))

func record_ko(actor: Node, respawn_duration: float) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return {}
	var slot: Dictionary = slots[key]
	if String(slot.get("state", STATE_FIELD)) == STATE_EXHAUSTED:
		return slot.duplicate(true)
	var stocks := maxi(0, int(slot.get("stocks_remaining", MAX_STOCKS)) - 1)
	slot["stocks_remaining"] = stocks
	slot["respawn_timer"] = maxf(respawn_duration, 0.0)
	slot["state"] = STATE_RESPAWNING if stocks > 0 else STATE_EXHAUSTED
	slots[key] = slot
	return slot.duplicate(true)

func tick_actor_respawn(actor: Node, delta: float) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return {}
	var slot: Dictionary = slots[key]
	if String(slot.get("state", STATE_FIELD)) != STATE_RESPAWNING:
		return slot.duplicate(true)
	slot["respawn_timer"] = maxf(float(slot.get("respawn_timer", 0.0)) - delta, 0.0)
	slots[key] = slot
	return slot.duplicate(true)

func can_respawn(actor: Node) -> bool:
	var slot := get_slot_for_actor(actor)
	return not slot.is_empty() and String(slot.get("state", "")) == STATE_RESPAWNING and float(slot.get("respawn_timer", 0.0)) <= 0.0

func mark_respawned(actor: Node) -> void:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return
	var slot: Dictionary = slots[key]
	if String(slot.get("state", STATE_FIELD)) == STATE_RESPAWNING:
		slot["state"] = STATE_FIELD
		slot["respawn_timer"] = 0.0
		slots[key] = slot

func get_slot_for_actor(actor: Node) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return {}
	return slots[key].duplicate(true)

func get_slot(team: int, slot_index: int) -> Dictionary:
	var key := _slot_key(team, slot_index)
	if not slots.has(key):
		return {}
	return slots[key].duplicate(true)

func stocks_remaining(actor: Node) -> int:
	var slot := get_slot_for_actor(actor)
	if slot.is_empty():
		return MAX_STOCKS
	return int(slot.get("stocks_remaining", MAX_STOCKS))

func max_stocks(actor: Node) -> int:
	var slot := get_slot_for_actor(actor)
	if slot.is_empty():
		return MAX_STOCKS
	return int(slot.get("max_stocks", MAX_STOCKS))

func is_exhausted(actor: Node) -> bool:
	var slot := get_slot_for_actor(actor)
	return not slot.is_empty() and String(slot.get("state", "")) == STATE_EXHAUSTED

func team_exhausted(team: int) -> bool:
	var found_team_slot := false
	for slot: Dictionary in slots.values():
		if int(slot.get("team", -1)) != team:
			continue
		found_team_slot = true
		if String(slot.get("state", STATE_FIELD)) != STATE_EXHAUSTED:
			return false
	return found_team_slot

func record_habitat_visit(actor: Node) -> void:
	var slot := get_slot_for_actor(actor)
	habitat_visits.append({
		"team": int(slot.get("team", actor.team if actor != null else -1)),
		"slot_index": int(slot.get("slot_index", -1)),
		"creature_id": String(slot.get("creature_id", actor.creature_id if actor != null else "")),
		"actor": actor
	})

func _key_for_actor(actor: Node) -> String:
	if actor == null:
		return ""
	return String(actor_keys.get(_actor_key(actor), ""))

func _actor_key(actor: Node) -> String:
	return str(actor.get_instance_id())

func _slot_key(team: int, slot_index: int) -> String:
	return "%d:%d" % [team, slot_index]
