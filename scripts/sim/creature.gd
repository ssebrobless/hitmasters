extends CharacterBody2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

const WATER_SPEED_MULTIPLIER := 1.15
const WRONG_TERRAIN_GRACE_SEC := 3.0
const WRONG_TERRAIN_EARLY_DPS := 0.02
const WRONG_TERRAIN_LATE_DPS := 0.05
const TAKEOFF_DISTANCE_UNITS := 2.0
const FLIGHT_GROUNDED_LOCKOUT_SEC := 3.0

var arena: Node = null
var terrain_map: RefCounted = null
var team := 0
var creature_id := ""
var creature_data: Dictionary = {}
var stats: Dictionary = {}
var movement_tags: Array = []
var state := CreatureStateScript.State.NORMAL
var input_frame: Resource = null
var max_health := 1.0
var health := 1.0
var body_radius := 8.0
var base_speed_px := 0.0
var swim_time_max := 0.0
var swim_time_remaining := 0.0
var wrong_terrain_seconds := 0.0
var flight_time_max := 0.0
var flight_time_remaining := 0.0
var flight_grounded_timer := 0.0
var takeoff_distance_px := 0.0
var alive := true

func setup(creature_arena: Node, creature_team: int, spawn_position: Vector2, next_creature_id: String, next_terrain_map: RefCounted = null) -> void:
	arena = creature_arena
	team = creature_team
	position = spawn_position
	terrain_map = next_terrain_map
	apply_creature(next_creature_id)

func apply_creature(next_creature_id: String) -> void:
	creature_id = next_creature_id
	creature_data = _catalog().get_creature(creature_id)
	stats = creature_data.get("stats", {})
	movement_tags = creature_data.get("movement", [])
	max_health = _stat_float("health", 1.0)
	health = max_health
	body_radius = _footprint_radius_px()
	base_speed_px = _speed_px_for_ground()
	swim_time_max = _numeric_stat("swim_time_sec", 0.0)
	swim_time_remaining = swim_time_max
	flight_time_max = _numeric_stat("flight_time_sec", 0.0)
	flight_time_remaining = flight_time_max
	state = CreatureStateScript.State.AIRBORNE if has_movement("always_flying") else CreatureStateScript.State.NORMAL
	alive = true
	queue_redraw()

func set_input_frame(next_frame: Resource) -> void:
	input_frame = next_frame

func _physics_process(delta: float) -> void:
	tick_sim(delta)

func tick_sim(delta: float) -> void:
	if not alive:
		return

	flight_grounded_timer = maxf(flight_grounded_timer - delta, 0.0)
	_update_flight(delta)
	_update_terrain(delta)
	_move_from_input(delta)
	queue_redraw()

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	if not alive:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		alive = false
		velocity = Vector2.ZERO
		if arena != null and arena.has_method("unregister_entity"):
			arena.unregister_entity(self)

func heal(amount: float) -> void:
	if alive:
		health = minf(health + amount, max_health)

func is_alive() -> bool:
	return alive

func is_airborne() -> bool:
	return state == CreatureStateScript.State.AIRBORNE or has_movement("always_flying")

func has_movement(tag: String) -> bool:
	return movement_tags.has(tag)

func get_current_zone() -> String:
	if arena != null and arena.has_method("get_terrain_zone"):
		return arena.get_terrain_zone(global_position)
	if terrain_map != null:
		return terrain_map.get_zone_at(global_position)
	return TerrainMapScript.LAND

func get_speed_px() -> float:
	var zone := get_current_zone()
	if is_airborne():
		return _speed_px_for_flight()
	if zone == TerrainMapScript.WATER:
		if _is_water_boosted():
			return _speed_px_for_water() * WATER_SPEED_MULTIPLIER
		return _speed_px_for_ground()
	return _speed_px_for_ground()

func get_swim_ratio() -> float:
	if swim_time_max <= 0.0:
		return 1.0
	return clampf(swim_time_remaining / swim_time_max, 0.0, 1.0)

func get_flight_ratio() -> float:
	if flight_time_max <= 0.0:
		return 1.0
	return clampf(flight_time_remaining / flight_time_max, 0.0, 1.0)

func _move_from_input(delta: float) -> void:
	var move := Vector2.ZERO
	if input_frame != null:
		move = input_frame.move.normalized()
	velocity = move * get_speed_px()
	if Engine.is_in_physics_frame():
		move_and_slide()
	else:
		global_position += velocity * delta
	if arena != null and arena.has_method("resolve_body_position"):
		global_position = arena.resolve_body_position(global_position, body_radius)

func _update_terrain(delta: float) -> void:
	var zone := get_current_zone()
	if zone == TerrainMapScript.WATER and not is_airborne():
		if _has_limited_swim_time():
			swim_time_remaining = maxf(swim_time_remaining - delta, 0.0)
		if _is_wrong_terrain():
			wrong_terrain_seconds += delta
			var rate := WRONG_TERRAIN_LATE_DPS if wrong_terrain_seconds > WRONG_TERRAIN_GRACE_SEC else WRONG_TERRAIN_EARLY_DPS
			take_damage(max_health * rate * delta)
		else:
			wrong_terrain_seconds = 0.0
	else:
		wrong_terrain_seconds = 0.0
		if swim_time_max > 0.0:
			swim_time_remaining = minf(swim_time_remaining + delta, swim_time_max)

func _update_flight(delta: float) -> void:
	if has_movement("always_flying"):
		state = CreatureStateScript.State.AIRBORNE
		return

	if is_airborne():
		flight_time_remaining = maxf(flight_time_remaining - delta, 0.0)
		takeoff_distance_px = 0.0
		if flight_time_max > 0.0 and flight_time_remaining <= 0.0:
			state = CreatureStateScript.State.NORMAL
			flight_grounded_timer = FLIGHT_GROUNDED_LOCKOUT_SEC
		return

	if flight_time_max <= 0.0 or not has_movement("flight"):
		return

	flight_time_remaining = minf(flight_time_remaining + delta, flight_time_max)
	if flight_grounded_timer > 0.0 or input_frame == null:
		takeoff_distance_px = 0.0
		return

	if input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE) and input_frame.move.length() > 0.0:
		takeoff_distance_px += input_frame.move.normalized().length() * get_speed_px() * delta
		if takeoff_distance_px >= TAKEOFF_DISTANCE_UNITS * SimConstants.UNIT_PX:
			state = CreatureStateScript.State.AIRBORNE
			takeoff_distance_px = 0.0
	else:
		takeoff_distance_px = 0.0

func _is_wrong_terrain() -> bool:
	if has_movement("aquatic") or has_movement("paddling") or has_movement("wading"):
		return false
	if has_movement("semi_aquatic"):
		return swim_time_remaining <= 0.0
	return true

func _is_water_boosted() -> bool:
	return has_movement("aquatic") or has_movement("semi_aquatic")

func _has_limited_swim_time() -> bool:
	return has_movement("semi_aquatic") and swim_time_max > 0.0

func _speed_px_for_ground() -> float:
	if stats.has("speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("speed", 1.0))
	if stats.has("ground_speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("ground_speed", 1.0))
	return _catalog().speed_to_px_per_sec(1.0)

func _speed_px_for_water() -> float:
	if stats.has("swim_speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("swim_speed", 1.0))
	return _speed_px_for_ground()

func _speed_px_for_flight() -> float:
	if stats.has("flight_speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("flight_speed", 1.0))
	return _speed_px_for_ground()

func _footprint_radius_px() -> float:
	var footprint: Dictionary = creature_data.get("footprint", {})
	return _catalog().units_to_px(float(footprint.get("radius_units", 0.5)))

func _stat_float(key: String, fallback: float) -> float:
	return _numeric_stat(key, fallback)

func _numeric_stat(key: String, fallback: float) -> float:
	var value: Variant = stats.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback

func _catalog() -> Node:
	return Engine.get_main_loop().root.get_node("CreatureCatalog")

func _draw() -> void:
	if not alive:
		return
	var color := Color(0.25, 0.65, 1.0) if team == 0 else Color(1.0, 0.28, 0.25)
	var fill := color.lightened(0.25) if is_airborne() else color
	draw_circle(Vector2.ZERO, body_radius, Color(0.03, 0.035, 0.045))
	draw_circle(Vector2.ZERO, maxf(body_radius - 3.0, 2.0), fill)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0, 5.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0 * (health / max_health), 5.0)), Color(0.3, 1.0, 0.45))
	if swim_time_max > 0.0:
		_draw_meter(Vector2(-body_radius, body_radius + 6.0), body_radius * 2.0, get_swim_ratio(), Color(0.2, 0.7, 1.0))
	if flight_time_max > 0.0:
		_draw_meter(Vector2(-body_radius, body_radius + 12.0), body_radius * 2.0, get_flight_ratio(), Color(0.9, 0.9, 0.45))

func _draw_meter(start: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(start, Vector2(width, 3.0)), Color(0.06, 0.06, 0.07))
	draw_rect(Rect2(start, Vector2(width * ratio, 3.0)), color)
