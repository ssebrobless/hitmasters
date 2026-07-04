extends Node

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const ROSTER_PATH := "res://data/battle_bog_roster.json"

var creatures_by_id: Dictionary = {}
var creatures: Array[Dictionary] = []

func _ready() -> void:
	load_catalog()

func load_catalog(path := ROSTER_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open creature roster: %s" % path)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Creature roster must be a JSON object: %s" % path)
		return false

	creatures_by_id.clear()
	creatures.clear()

	var roster: Array = parsed.get("creatures", [])
	var valid := true
	for entry: Variant in roster:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("Creature roster entry must be an object.")
			valid = false
			continue

		var creature: Dictionary = entry
		var creature_id := String(creature.get("id", ""))
		if creature_id.is_empty():
			push_error("Creature roster entry is missing id.")
			valid = false
			continue
		if not creature.has("stats") or typeof(creature.get("stats")) != TYPE_DICTIONARY:
			push_error("Creature %s is missing stats." % creature_id)
			valid = false
		if not creature.has("footprint") or typeof(creature.get("footprint")) != TYPE_DICTIONARY:
			push_error("Creature %s is missing footprint." % creature_id)
			valid = false
		if String(creature.get("diet", "")).is_empty():
			push_error("Creature %s is missing diet." % creature_id)
			valid = false
		if creatures_by_id.has(creature_id):
			push_error("Duplicate creature id: %s" % creature_id)
			valid = false

		creatures_by_id[creature_id] = creature
		creatures.append(creature)

	return valid

func get_creature(creature_id: String) -> Dictionary:
	return creatures_by_id.get(creature_id, {})

func get_all() -> Array[Dictionary]:
	return creatures.duplicate()

func units_to_px(units: float) -> float:
	return units * SimConstants.UNIT_PX

func px_to_units(px: float) -> float:
	return px / SimConstants.UNIT_PX

func speed_to_px_per_sec(speed_units: float) -> float:
	return speed_units * SimConstants.SPEED_PX_PER_SEC
