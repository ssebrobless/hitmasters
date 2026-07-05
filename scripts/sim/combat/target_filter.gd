extends RefCounted

static func is_live_damage_target(source: Node, target: Node, opts: Dictionary = {}) -> bool:
	if not _is_valid_target_object(target):
		return false
	if not bool(opts.get("allow_self", false)) and source != null and target == source:
		return false
	if _is_dead(target):
		return false
	if not bool(opts.get("allow_stealthed", false)) and target.has_method("is_stealthed") and target.is_stealthed():
		return false
	if not _team_matches(source, target, opts, false):
		return false
	return _has_required_api(target, opts, true)

static func is_live_blind_damage_target(source: Node, target: Node, opts: Dictionary = {}) -> bool:
	var effective_opts := opts.duplicate()
	effective_opts["allow_stealthed"] = true
	return is_live_damage_target(source, target, effective_opts)

static func is_live_ally_target(source: Node, target: Node, opts: Dictionary = {}) -> bool:
	if not _is_valid_target_object(target):
		return false
	if not bool(opts.get("allow_self", true)) and source != null and target == source:
		return false
	if _is_dead(target):
		return false
	if not _team_matches(source, target, opts, true):
		return false
	return _has_required_api(target, opts, false)

static func _is_valid_target_object(target: Node) -> bool:
	return target != null and is_instance_valid(target)

static func _is_dead(target: Node) -> bool:
	if target.has_method("is_alive") and not target.is_alive():
		return true
	if _has_property(target, "health") and float(target.get("health")) <= 0.0:
		return true
	return false

static func _team_matches(source: Node, target: Node, opts: Dictionary, wants_ally: bool) -> bool:
	if bool(opts.get("ignore_team", false)):
		return true
	if source == null or not is_instance_valid(source):
		return bool(opts.get("allow_missing_source", true))
	if not _has_property(source, "team") or not _has_property(target, "team"):
		return bool(opts.get("allow_missing_team", false))
	var same_team := int(source.get("team")) == int(target.get("team"))
	return same_team if wants_ally else not same_team

static func _has_required_api(target: Node, opts: Dictionary, default_require_damage_api: bool) -> bool:
	var required_method := String(opts.get("require_method", ""))
	if required_method != "" and not target.has_method(required_method):
		return false
	if bool(opts.get("require_damage_api", default_require_damage_api)) and not target.has_method("take_damage_event"):
		return false
	if bool(opts.get("require_modifier_api", false)) and not target.has_method("add_modifier"):
		return false
	return true

static func _has_property(target: Object, property_name: String) -> bool:
	for property: Dictionary in target.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
