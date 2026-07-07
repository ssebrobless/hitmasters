extends RefCounted

const CreatureScript := preload("res://scripts/sim/creature.gd")

static func speed_text(stats: Dictionary) -> String:
	if stats.has("speed"):
		return str(stats["speed"])
	if stats.has("ground_speed") and stats.has("flight_speed"):
		return "%s/%s" % [str(stats["ground_speed"]), str(stats["flight_speed"])]
	if stats.has("ground_speed"):
		return str(stats["ground_speed"])
	if stats.has("flight_speed"):
		return str(stats["flight_speed"])
	return "?"

static func footprint_text(footprint: Dictionary) -> String:
	var shape := String(footprint.get("shape", "?"))
	if shape == "capsule":
		return "%s %sx%s u" % [shape, str(footprint.get("radius_units", "?")), str(footprint.get("length_units", "?"))]
	return "%s %s u" % [shape, str(footprint.get("radius_units", "?"))]

static func height_read_text(creature_id: String) -> String:
	var profile := CreatureScript.visual_size_profile_for(creature_id)
	var height_units := float(profile.get("height_units", 0.45))
	var height_band := CreatureScript.visual_height_band_for(height_units).capitalize()
	var height_class := title_from_snake(String(profile.get("height_class", "mid")))
	return "%s %s" % [height_band, height_class]

static func title_from_snake(value: String) -> String:
	var words := PackedStringArray()
	for part in value.split("_", false):
		words.append(part.capitalize())
	return " ".join(words)
