extends RefCounted

static var _number_regex: RegEx = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)")
static var _percent_regex: RegEx = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)%")
static var _number_cache: Dictionary = {}
static var _percent_cache: Dictionary = {}

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
	var numbers := _numbers_for(text)
	if numbers.is_empty():
		return fallback
	return float(numbers[0])

static func nth_number(text: String, index: int, fallback: float) -> float:
	var numbers := _numbers_for(text)
	if index < 0 or index >= numbers.size():
		return fallback
	return float(numbers[index])

static func max_number(text: String, fallback: float) -> float:
	var numbers := _numbers_for(text)
	if numbers.is_empty():
		return fallback
	var output := float(numbers[0])
	for number in numbers:
		output = maxf(output, float(number))
	return output

static func first_percent(text: String, fallback: float) -> float:
	var percents := _percents_for(text)
	if percents.is_empty():
		return fallback
	return float(percents[0])

static func first_seconds(text: String, fallback: float) -> float:
	return first_number(text, fallback)

static func range_units(stats: Dictionary, fallback: float) -> float:
	return max_number(String(stats.get("range", "")), fallback)

static func _numbers_for(text: String) -> Array:
	if _number_cache.has(text):
		return _number_cache[text]
	var numbers: Array[float] = []
	for result in _number_regex.search_all(text):
		numbers.append(float(result.get_string(1)))
	_number_cache[text] = numbers
	return numbers

static func _percents_for(text: String) -> Array:
	if _percent_cache.has(text):
		return _percent_cache[text]
	var percents: Array[float] = []
	for result in _percent_regex.search_all(text):
		percents.append(float(result.get_string(1)) / 100.0)
	_percent_cache[text] = percents
	return percents
