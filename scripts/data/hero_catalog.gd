extends Node
class_name HeroCatalog

const HERO_DATA_PATH := "res://data/heroes.json"

var heroes_by_id: Dictionary = {}

func _ready() -> void:
	load_heroes()

func load_heroes() -> void:
	var file := FileAccess.open(HERO_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open hero data: %s" % HERO_DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Hero data must be a JSON object.")
		return

	heroes_by_id.clear()
	for hero: Dictionary in parsed.get("heroes", []):
		var hero_id: String = hero.get("id", "")
		if hero_id.is_empty():
			push_warning("Skipping hero without id.")
			continue
		heroes_by_id[hero_id] = hero

func get_hero(hero_id: String) -> Dictionary:
	return heroes_by_id.get(hero_id, {})

func get_all_heroes() -> Array:
	return heroes_by_id.values()

