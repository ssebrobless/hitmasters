extends RefCounted

const MAX_STOCKS := 3
const STATE_FIELD := "field"
const STATE_RESPAWNING := "respawning"
const STATE_EXHAUSTED := "exhausted"
const BREEDING_DURATION_SEC := 45.0

var slots: Dictionary = {}
var actor_keys: Dictionary = {}
var habitat_visits: Array[Dictionary] = []
var breeding_cues: Array[Dictionary] = []
var breeding_cue_sequence := 0

func reset() -> void:
	slots.clear()
	actor_keys.clear()
	habitat_visits.clear()
	breeding_cues.clear()
	breeding_cue_sequence = 0

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

func get_team_slots(team: int) -> Array[Dictionary]:
	var team_slots: Array[Dictionary] = []
	for slot: Dictionary in slots.values():
		if int(slot.get("team", -1)) == team:
			team_slots.append(slot.duplicate(true))
	team_slots.sort_custom(Callable(self, "_sort_slots_by_index"))
	return team_slots

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

func record_habitat_visit(actor: Node) -> Dictionary:
	var slot := get_slot_for_actor(actor)
	var team := int(slot.get("team", actor.team if actor != null else -1))
	var slot_index := int(slot.get("slot_index", -1))
	var creature_id := String(slot.get("creature_id", actor.creature_id if actor != null else ""))
	var family := _family_for_actor(actor)
	if _has_active_breeding_cue(team, creature_id):
		return {
			"accepted": false,
			"reason": "already_breeding",
			"team": team,
			"slot_index": slot_index,
			"creature_id": creature_id,
			"family": family,
			"actor": actor
		}
	var cue := {
		"accepted": true,
		"id": _next_breeding_cue_id(team, slot_index, creature_id),
		"team": team,
		"slot_index": slot_index,
		"creature_id": creature_id,
		"family": family,
		"actor": actor,
		"remaining": BREEDING_DURATION_SEC,
		"duration": BREEDING_DURATION_SEC
	}
	habitat_visits.append(cue.duplicate())
	breeding_cues.append(cue)
	return cue.duplicate(true)

func remove_breeding_cue(cue_id: String) -> Dictionary:
	if cue_id.is_empty():
		return {}
	for i in range(breeding_cues.size() - 1, -1, -1):
		if String(breeding_cues[i].get("id", "")) != cue_id:
			continue
		var cue := breeding_cues[i].duplicate(true)
		breeding_cues.remove_at(i)
		return cue
	return {}

func tick_breeding_cues(delta: float) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	for i in range(breeding_cues.size() - 1, -1, -1):
		breeding_cues[i]["remaining"] = float(breeding_cues[i].get("remaining", 0.0)) - delta
		if float(breeding_cues[i]["remaining"]) <= 0.0:
			completed.append(breeding_cues[i].duplicate(true))
			breeding_cues.remove_at(i)
	completed.reverse()
	return completed

func get_breeding_cues(team := -1) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	for cue: Dictionary in breeding_cues:
		if team >= 0 and int(cue.get("team", -1)) != team:
			continue
		cues.append(cue.duplicate(true))
	return cues

func _key_for_actor(actor: Node) -> String:
	if actor == null:
		return ""
	return String(actor_keys.get(_actor_key(actor), ""))

func _has_active_breeding_cue(team: int, creature_id: String) -> bool:
	if creature_id.is_empty():
		return false
	for cue: Dictionary in breeding_cues:
		if int(cue.get("team", -1)) == team and String(cue.get("creature_id", "")) == creature_id:
			return true
	return false

func _family_for_actor(actor: Node) -> String:
	if actor == null:
		return ""
	var data_value: Variant = actor.get("creature_data")
	if typeof(data_value) == TYPE_DICTIONARY:
		var data: Dictionary = data_value
		return String(data.get("family", ""))
	return ""

func _next_breeding_cue_id(team: int, slot_index: int, creature_id: String) -> String:
	breeding_cue_sequence += 1
	return "%d:%d:%s:%d" % [team, slot_index, creature_id, breeding_cue_sequence]

func _actor_key(actor: Node) -> String:
	return str(actor.get_instance_id())

func _slot_key(team: int, slot_index: int) -> String:
	return "%d:%d" % [team, slot_index]

func _sort_slots_by_index(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
