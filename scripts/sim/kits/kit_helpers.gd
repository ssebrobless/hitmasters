extends RefCounted

static var _number_regex: RegEx = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)")
static var _percent_regex: RegEx = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)%")

static func ability(creature_data: Dictionary, slot: String) -> Dictionary:
	for entry: Dictionary in creature_data.get("abilities", []):
		if String(entry.get("slot", "")) == slot:
			return entry
	return {}

static func cooldown_seconds(ability_data: Dictionary) -> float:
	for key in ["cooldown_sec", "cooldown_after_sec", "cooldown_on_hit_sec"]:
		if ability_data.has(key):
			return float(ability_data[key])
	return first_seconds(String(ability_data.get("summary", "")), 0.0)

static func first_number(text: String, fallback: float) -> float:
	var result := _number_regex.search(text)
	if result == null:
		return fallback
	return float(result.get_string(1))

static func nth_number(text: String, index: int, fallback: float) -> float:
	var results := _number_regex.search_all(text)
	if index < 0 or index >= results.size():
		return fallback
	return float(results[index].get_string(1))

static func max_number(text: String, fallback: float) -> float:
	var results := _number_regex.search_all(text)
	if results.is_empty():
		return fallback
	var output := float(results[0].get_string(1))
	for result in results:
		output = maxf(output, float(result.get_string(1)))
	return output

static func first_percent(text: String, fallback: float) -> float:
	var result := _percent_regex.search(text)
	if result == null:
		return fallback
	return float(result.get_string(1)) / 100.0

static func first_seconds(text: String, fallback: float) -> float:
	return first_number(text, fallback)

static func range_units(stats: Dictionary, fallback: float) -> float:
	return max_number(String(stats.get("range", "")), fallback)
