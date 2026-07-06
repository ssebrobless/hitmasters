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
		if not _validate_hurtbox_regions(creature_id, creature.get("hurtbox_regions", [])):
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

func _validate_hurtbox_regions(creature_id: String, regions: Variant) -> bool:
	if regions == null:
		return true
	if typeof(regions) != TYPE_ARRAY:
		push_error("Creature %s hurtbox_regions must be an array." % creature_id)
		return false
	var valid := true
	for region_value: Variant in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			push_error("Creature %s hurtbox region must be an object." % creature_id)
			valid = false
			continue
		var region: Dictionary = region_value
		var name := String(region.get("name", ""))
		var open_when := String(region.get("open_when", "always"))
		if name.is_empty():
			push_error("Creature %s hurtbox region is missing name." % creature_id)
			valid = false
		if not ["always", "lunge", "stunned", "low_window", "bask"].has(open_when):
			push_error("Creature %s hurtbox region %s has invalid open_when %s." % [creature_id, name, open_when])
			valid = false
		var radius := _number_or_nan(region.get("radius_units", NAN))
		if is_nan(radius) or radius < 0.35:
			push_error("Creature %s hurtbox region %s radius_units must be >= 0.35." % [creature_id, name])
			valid = false
		var mult := _number_or_nan(region.get("mult", NAN))
		if is_nan(mult) or mult < 0.75 or mult > 1.35:
			push_error("Creature %s hurtbox region %s mult must be between 0.75 and 1.35." % [creature_id, name])
			valid = false
		if not _valid_region_offset(region.get("offset_units", null)):
			push_error("Creature %s hurtbox region %s offset_units must be [forward, side] or {forward, side}." % [creature_id, name])
			valid = false
	return valid

func _number_or_nan(value: Variant) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return NAN

func _valid_region_offset(value: Variant) -> bool:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).size() >= 2 and _is_number((value as Array)[0]) and _is_number((value as Array)[1])
	if typeof(value) == TYPE_DICTIONARY:
		var offset: Dictionary = value
		return (_is_number(offset.get("forward", offset.get("x", null))) and _is_number(offset.get("side", offset.get("y", null))))
	return false

func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
