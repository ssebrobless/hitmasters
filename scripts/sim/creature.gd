extends CharacterBody2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const VisualStyle := preload("res://scripts/visual/visual_style.gd")
const TurtleKitScript := preload("res://scripts/sim/kits/snapping_turtle.gd")
const FrogKitScript := preload("res://scripts/sim/kits/chorus_frog.gd")
const MinkKitScript := preload("res://scripts/sim/kits/mink.gd")
const BeaverKitScript := preload("res://scripts/sim/kits/beaver.gd")
const OwlKitScript := preload("res://scripts/sim/kits/owl.gd")
const DuckKitScript := preload("res://scripts/sim/kits/duck.gd")

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
var actor_name := "Creature"
var kit: RefCounted = null
var primary_timer := 0.0
var q_timer := 0.0
var e_timer := 0.0
var q_charges := 0
var e_charges := 0
var dash_velocity := Vector2.ZERO
var dash_timer := 0.0
var modifiers: Array[Dictionary] = []
var healing_ticks: Array[Dictionary] = []
var latched_attacker: Node = null
var latch_victim: Node = null
var latch_timer := 0.0
var latch_source := ""
var latch_execute_timer := 0.0
var latch_move_multiplier := 1.0
var last_aim_direction := Vector2.RIGHT
var render_flash_timer := 0.0
var render_shake_timer := 0.0
var anim_walk_phase := 0.0
var anim_attack_timer := 0.0
var anim_attack_duration := 0.001
var anim_attack_reach := 0.0
var anim_attack_aim := Vector2.RIGHT
var anim_windup_timer := 0.0
var anim_windup_duration := 0.001
var stealth_timer := 0.0
var low_window_timer := 0.0
var respawn_timer := 0.0
var respawn_duration := 5.0

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
	actor_name = String(creature_data.get("name", creature_id))
	modifiers.clear()
	healing_ticks.clear()
	latched_attacker = null
	latch_victim = null
	latch_timer = 0.0
	latch_source = ""
	latch_execute_timer = 0.0
	kit = _make_kit()
	if kit != null:
		kit.setup(self)
	alive = true
	queue_redraw()

func set_input_frame(next_frame: Resource) -> void:
	input_frame = next_frame

func _physics_process(delta: float) -> void:
	tick_sim(delta)

func _process(delta: float) -> void:
	render_flash_timer = maxf(render_flash_timer - delta, 0.0)
	render_shake_timer = maxf(render_shake_timer - delta, 0.0)
	anim_attack_timer = maxf(anim_attack_timer - delta, 0.0)
	anim_windup_timer = maxf(anim_windup_timer - delta, 0.0)
	if velocity.length() > 4.0:
		anim_walk_phase += delta * clampf(velocity.length() / 26.0, 3.0, 11.0)
	if arena == null or not arena.has_method("is_near_view") or arena.is_near_view(global_position):
		queue_redraw()

func tick_sim(delta: float) -> void:
	if not alive:
		# Interim respawn (fixed timer) until M5 replaces this with habitat
		# stock selection per decision #6.
		respawn_timer = maxf(respawn_timer - delta, 0.0)
		if respawn_timer <= 0.0:
			_respawn()
		return

	_tick_timers(delta)
	flight_grounded_timer = maxf(flight_grounded_timer - delta, 0.0)
	stealth_timer = maxf(stealth_timer - delta, 0.0)
	low_window_timer = maxf(low_window_timer - delta, 0.0)
	_update_flight(delta)
	_update_terrain(delta)
	_move_from_input(delta)
	_tick_latch(delta)
	if kit != null and kit.has_method("tick"):
		kit.tick(self, delta)

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, _source_actor, "")
	take_damage_event(event)

func begin_stealth(duration: float, _source: String) -> void:
	stealth_timer = duration

func break_stealth() -> void:
	stealth_timer = 0.0

func is_stealthed() -> bool:
	return stealth_timer > 0.0

func can_act() -> bool:
	# Stun/self-lock modifiers (e.g. Lingual Lure) zero out can_act_mult.
	return alive and _modifier_value("can_act_mult", 1.0) > 0.5

func open_low_window(duration: float) -> void:
	low_window_timer = duration

func _dodges_event(event: Resource) -> bool:
	# Elevated creatures (true flight or perch, not always-flying bugs) dodge
	# ground melee — except during their low attack window.
	if event.delivery != DamageEventScript.DELIVERY_MELEE or event.plane != DamageEventScript.PLANE_GROUND:
		return false
	if low_window_timer > 0.0 or has_movement("always_flying"):
		return false
	return state == CreatureStateScript.State.AIRBORNE or state == CreatureStateScript.State.PERCHED

func take_damage_event(event: Resource) -> void:
	if not alive:
		return
	if _dodges_event(event):
		emit_vfx_event("attack_dodged", {"target": self, "position": global_position})
		return
	break_stealth()
	var amount: float = _modified_incoming_damage(event)
	health = maxf(health - amount, 0.0)
	# Spike rule (decision #20): a heavy ranged hit grounds a flying bird.
	if state == CreatureStateScript.State.AIRBORNE and not has_movement("always_flying") and event.delivery == DamageEventScript.DELIVERY_RANGED and amount >= 30.0:
		state = CreatureStateScript.State.NORMAL
		flight_grounded_timer = FLIGHT_GROUNDED_LOCKOUT_SEC
		emit_vfx_event("spiked", {"target": self, "position": global_position})
	if event.source_actor != null or String(event.source_ability) != "":
		emit_vfx_event("hit_landed", {
			"source": event.source_actor,
			"target": self,
			"amount": amount,
			"heavy": amount >= 50.0,
			"position": global_position,
			"source_ability": event.source_ability
		})
	if health <= 0.0:
		if event.source_actor != null and is_instance_valid(event.source_actor) and event.source_actor.has_method("on_kill"):
			event.source_actor.on_kill(self)
		if arena != null and arena.has_method("record_death"):
			arena.record_death(self, event.source_actor)
		if latch_victim != null:
			release_latch("death")
		if latched_attacker != null and is_instance_valid(latched_attacker):
			latched_attacker.release_latch("victim_death")
		break_stealth()
		low_window_timer = 0.0
		state = CreatureStateScript.State.NORMAL
		alive = false
		visible = false
		velocity = Vector2.ZERO
		respawn_timer = respawn_duration
		if arena != null and arena.has_method("unregister_entity"):
			arena.unregister_entity(self)

func heal(amount: float) -> void:
	if alive:
		var before := health
		health = minf(health + amount * _modifier_value("healing_received_mult", 1.0), max_health)
		var healed := health - before
		if healed > 0.0:
			emit_vfx_event("heal_tick", {
				"target": self,
				"amount": healed,
				"position": global_position
			})

func emit_vfx_event(event_type: String, payload: Dictionary = {}) -> void:
	_apply_own_anim(event_type, payload)
	if arena == null or not arena.has_method("record_vfx_event"):
		return
	var event := payload.duplicate()
	event["type"] = event_type
	arena.record_vfx_event(event)

func _apply_own_anim(event_type: String, payload: Dictionary) -> void:
	if payload.get("actor", null) != self:
		return
	match event_type:
		"windup_started":
			anim_windup_duration = maxf(float(payload.get("duration", 0.001)), 0.001)
			anim_windup_timer = anim_windup_duration
		"attack_swung":
			break_stealth()
			anim_attack_duration = clampf(_attack_interval_sec() * 0.55, 0.32, 0.6)
			anim_attack_timer = anim_attack_duration
			anim_attack_reach = float(payload.get("reach_px", body_radius * 1.5))
			anim_attack_aim = payload.get("aim", last_aim_direction)
			anim_windup_timer = 0.0

func apply_render_hit_feedback(amount: float) -> void:
	render_flash_timer = 0.1
	if amount >= 50.0:
		render_shake_timer = 0.1
	queue_redraw()

func is_alive() -> bool:
	return alive

func get_actor_name() -> String:
	return actor_name

func is_scored_actor() -> bool:
	return true

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
	if state == CreatureStateScript.State.PERCHED:
		velocity = Vector2.ZERO
		if input_frame != null and input_frame.aim != Vector2.ZERO:
			last_aim_direction = (input_frame.aim - global_position).normalized()
		return
	var move := Vector2.ZERO
	if input_frame != null:
		move = input_frame.move.normalized()
		if input_frame.aim != Vector2.ZERO:
			last_aim_direction = (input_frame.aim - global_position).normalized()
	var speed_multiplier := latch_move_multiplier * _modifier_value("move_speed_mult", 1.0)
	velocity = (dash_velocity if dash_timer > 0.0 else move * get_speed_px() * speed_multiplier)
	if Engine.is_in_physics_frame():
		move_and_slide()
	else:
		global_position += velocity * delta
	if arena != null:
		if is_airborne():
			# Airborne creatures pass over obstacles; only the arena bounds apply.
			global_position = arena.clamp_to_arena(global_position)
		elif arena.has_method("resolve_body_position"):
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

	if state == CreatureStateScript.State.PERCHED:
		return

	if is_airborne():
		flight_time_remaining = maxf(flight_time_remaining - delta, 0.0)
		takeoff_distance_px = 0.0
		if flight_time_max > 0.0 and flight_time_remaining <= 0.0:
			state = CreatureStateScript.State.NORMAL
			flight_grounded_timer = FLIGHT_GROUNDED_LOCKOUT_SEC
			break_stealth()
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

func get_aim_direction() -> Vector2:
	if input_frame != null and input_frame.aim != Vector2.ZERO:
		var direction: Vector2 = input_frame.aim - global_position
		if direction != Vector2.ZERO:
			last_aim_direction = direction.normalized()
	return last_aim_direction

func make_damage_event(amount: float, delivery: int, plane: int, source_ability: String) -> Resource:
	var event := DamageEventScript.new()
	event.setup(amount * _modifier_value("damage_dealt_mult", 1.0), delivery, plane, self, source_ability)
	return event

func add_modifier(source: String, values: Dictionary, duration: float) -> void:
	modifiers.append({"source": source, "values": values, "remaining": duration})

func get_modifier_value(key: String, fallback: float) -> float:
	return _modifier_value(key, fallback)

func break_latch(_reason: String) -> void:
	if latched_attacker != null and is_instance_valid(latched_attacker) and latched_attacker.has_method("release_latch"):
		latched_attacker.release_latch("victim_displacement")
	if latch_victim != null:
		release_latch("self_displacement")

func attach_to_victim(victim: Node, duration: float, source_ability: String, execute_after := 0.0) -> void:
	# One latch at a time: starting a new one cleanly releases the old, and
	# stealing a victim releases their previous attacker.
	if latch_victim != null:
		release_latch("relatch")
	if victim.latched_attacker != null and is_instance_valid(victim.latched_attacker) and victim.latched_attacker != self:
		victim.latched_attacker.release_latch("victim_stolen")
	latch_victim = victim
	latch_timer = duration
	latch_source = source_ability
	latch_execute_timer = execute_after
	state = CreatureStateScript.State.LATCHED
	emit_vfx_event("latch_started", {
		"attacker": self,
		"victim": victim,
		"duration": duration,
		"execute_after": execute_after,
		"source_ability": source_ability
	})

func receive_latch(attacker: Node, duration: float, source_ability: String) -> void:
	latched_attacker = attacker
	latch_timer = duration
	latch_source = source_ability
	latch_move_multiplier = 0.65

func release_latch(_reason: String) -> void:
	if latch_victim != null:
		emit_vfx_event("latch_ended", {
			"attacker": self,
			"victim": latch_victim,
			"reason": _reason,
			"source_ability": latch_source
		})
	elif latched_attacker != null:
		emit_vfx_event("latch_ended", {
			"attacker": latched_attacker,
			"victim": self,
			"reason": _reason,
			"source_ability": latch_source
		})
	if latch_victim != null and is_instance_valid(latch_victim) and latch_victim.latched_attacker == self:
		latch_victim.latched_attacker = null
		latch_victim.latch_move_multiplier = 1.0
	latch_victim = null
	latched_attacker = null
	latch_timer = 0.0
	latch_source = ""
	latch_execute_timer = 0.0
	latch_move_multiplier = 1.0
	if not is_airborne():
		state = CreatureStateScript.State.NORMAL

func has_latch() -> bool:
	return latch_victim != null or latched_attacker != null

func on_kill(_victim: Node) -> void:
	var diet := String(creature_data.get("diet", ""))
	if diet == "carnivore" or diet == "omnivore":
		healing_ticks.append({"remaining": 2.0, "amount_remaining": max_health * 0.05})

func damage_enemy_cores_near(center: Vector2, radius: float, damage: float, source_ability: String) -> void:
	if arena == null or not arena.has_method("record_core_damage"):
		return
	for core_team in arena.cores.keys():
		var core = arena.cores[core_team]
		if core.team == team:
			continue
		if arena.has_method("can_damage_core") and not arena.can_damage_core(core.team):
			continue
		if core.global_position.distance_to(center) <= radius + core.radius:
			core.take_damage(damage, team, self)
			arena.record_core_damage(team, damage, self)

func damage_enemy_cores_line(range_px: float, damage: float, source_ability: String) -> void:
	if arena == null:
		return
	var aim := get_aim_direction()
	for core_team in arena.cores.keys():
		var core = arena.cores[core_team]
		if core.team == team:
			continue
		if arena.has_method("can_damage_core") and not arena.can_damage_core(core.team):
			continue
		var offset: Vector2 = core.global_position - global_position
		var along := offset.dot(aim)
		if along >= 0.0 and along <= range_px and absf(offset.cross(aim)) <= core.radius:
			core.take_damage(damage, team, self)
			arena.record_core_damage(team, damage, self)

func _respawn() -> void:
	alive = true
	visible = true
	health = max_health
	modifiers.clear()
	healing_ticks.clear()
	swim_time_remaining = swim_time_max
	flight_time_remaining = flight_time_max
	flight_grounded_timer = 0.0
	wrong_terrain_seconds = 0.0
	dash_velocity = Vector2.ZERO
	dash_timer = 0.0
	primary_timer = 0.4
	q_timer = maxf(q_timer, 1.0)
	e_timer = maxf(e_timer, 1.0)
	state = CreatureStateScript.State.AIRBORNE if has_movement("always_flying") else CreatureStateScript.State.NORMAL
	if arena != null:
		if arena.has_method("get_team_spawn"):
			global_position = arena.get_team_spawn(team)
		if arena.has_method("register_entity"):
			arena.register_entity(self)
		if arena.has_method("add_circle_telegraph"):
			arena.add_circle_telegraph(global_position, body_radius + 26.0, Color(0.45, 0.72, 1.0, 0.75) if team == 0 else Color(1.0, 0.4, 0.35, 0.75), 0.6, 4.0, true)
	queue_redraw()

func _tick_timers(delta: float) -> void:
	primary_timer = maxf(primary_timer - delta, 0.0)
	q_timer = maxf(q_timer - delta, 0.0)
	e_timer = maxf(e_timer - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	if dash_timer <= 0.0:
		dash_velocity = Vector2.ZERO
	for i in range(modifiers.size() - 1, -1, -1):
		modifiers[i]["remaining"] = float(modifiers[i]["remaining"]) - delta
		if float(modifiers[i]["remaining"]) <= 0.0:
			modifiers.remove_at(i)
	for i in range(healing_ticks.size() - 1, -1, -1):
		var tick: Dictionary = healing_ticks[i]
		var heal_amount: float = minf(float(tick["amount_remaining"]), max_health * 0.05 * delta / 2.0)
		heal(heal_amount)
		tick["amount_remaining"] = float(tick["amount_remaining"]) - heal_amount
		tick["remaining"] = float(tick["remaining"]) - delta
		healing_ticks[i] = tick
		if float(tick["remaining"]) <= 0.0 or float(tick["amount_remaining"]) <= 0.0:
			healing_ticks.remove_at(i)

func _tick_latch(delta: float) -> void:
	if latch_victim != null and is_instance_valid(latch_victim):
		latch_timer = maxf(latch_timer - delta, 0.0)
		latch_execute_timer = maxf(latch_execute_timer - delta, 0.0)
		var offset: Vector2 = global_position - latch_victim.global_position
		if offset == Vector2.ZERO:
			offset = Vector2.LEFT
		var drag_direction: Vector2 = offset.normalized()
		if max_health > latch_victim.max_health:
			latch_victim.global_position += drag_direction * get_speed_px() * 0.18 * delta
		global_position = latch_victim.global_position + drag_direction * (body_radius + latch_victim.body_radius * 0.5)
		if latch_execute_timer == 0.0 and latch_source == "Choke":
			latch_victim.take_damage_event(make_damage_event(latch_victim.health, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, latch_source))
			release_latch("execute")
		elif latch_timer <= 0.0:
			release_latch("timeout")
	elif latched_attacker != null and is_instance_valid(latched_attacker):
		latch_timer = maxf(latch_timer - delta, 0.0)
		if latch_timer <= 0.0:
			# Only release if the attacker is still latched to US — otherwise
			# our stale timer would cut an unrelated newer latch.
			if latched_attacker.latch_victim == self:
				latched_attacker.release_latch("timeout")
			else:
				latched_attacker = null
				latch_move_multiplier = 1.0

func _modified_incoming_damage(event: Resource) -> float:
	var amount: float = event.amount
	amount *= _modifier_value("damage_taken_mult", 1.0)
	if creature_id == "snapping_turtle":
		amount *= 1.0 - _passive_percent("Protective Shell", 0.0)
	var source_actor = event.source_actor
	if source_actor != null and is_instance_valid(source_actor):
		var source_max_health_value: Variant = source_actor.get("max_health")
		var source_creature_id_value: Variant = source_actor.get("creature_id")
		var source_max_health := float(source_max_health_value) if source_max_health_value != null else 0.0
		var source_creature_id := String(source_creature_id_value) if source_creature_id_value != null else ""
		if creature_id == "mink" and source_max_health > max_health:
			amount *= 1.0 - _passive_percent("Fearless", 0.0)
		if source_creature_id == "mink" and max_health > source_max_health and source_actor.has_method("get_passive_percent"):
			amount *= 1.0 + source_actor.get_passive_percent("Fearless", 1, 0.0)
	return amount

func _modifier_value(key: String, fallback: float) -> float:
	var output := fallback
	for modifier in modifiers:
		var values: Dictionary = modifier.get("values", {})
		if values.has(key):
			output *= float(values[key])
	return output

func _passive_percent(passive_name: String, fallback: float) -> float:
	return get_passive_percent(passive_name, 0, fallback)

func get_passive_percent(passive_name: String, index: int = 0, fallback: float = 0.0) -> float:
	for passive: Dictionary in creature_data.get("passives", []):
		if String(passive.get("name", "")) == passive_name:
			return _nth_percent(String(passive.get("summary", "")), index, fallback)
	return fallback

static var _percent_regex: RegEx = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)%")

func _first_percent(text: String, fallback: float) -> float:
	return _nth_percent(text, 0, fallback)

func _nth_percent(text: String, index: int, fallback: float) -> float:
	var results := _percent_regex.search_all(text)
	if index < 0 or index >= results.size():
		return fallback
	return float(results[index].get_string(1)) / 100.0

func _make_kit() -> RefCounted:
	match creature_id:
		"snapping_turtle":
			return TurtleKitScript.new()
		"chorus_frog":
			return FrogKitScript.new()
		"mink":
			return MinkKitScript.new()
		"beaver":
			return BeaverKitScript.new()
		"owl":
			return OwlKitScript.new()
		"duck":
			return DuckKitScript.new()
		_:
			return null

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

func _attack_interval_sec() -> float:
	var interval := _numeric_stat("attack_interval_sec", 0.0)
	if interval > 0.0:
		return interval
	var rate := _numeric_stat("attack_rate_per_sec", 0.0)
	if rate > 0.0:
		return 1.0 / rate
	return 0.9

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
	var shake_offset := Vector2.ZERO
	if render_shake_timer > 0.0:
		var shake_phase := render_shake_timer * 120.0
		shake_offset = Vector2(sin(shake_phase), cos(shake_phase * 1.37)) * 2.0
	var anim := {
		"walk_phase": anim_walk_phase,
		"moving": velocity.length() > 4.0,
		"attack_t": 1.0 - anim_attack_timer / anim_attack_duration if anim_attack_timer > 0.0 else -1.0,
		"attack_reach": anim_attack_reach,
		"attack_aim": anim_attack_aim,
		"windup_t": 1.0 - anim_windup_timer / anim_windup_duration if anim_windup_timer > 0.0 else -1.0,
		"shake_offset": shake_offset
	}
	var draw_alpha := 0.4 if is_stealthed() else 1.0
	if wrong_terrain_seconds > 0.0:
		_draw_wrong_terrain_warning()
	VisualStyle.draw_battle_creature(self, creature_id, team, body_radius, last_aim_direction, render_flash_timer / 0.1, draw_alpha, is_airborne() or state == CreatureStateScript.State.PERCHED, anim)
	if arena != null and arena.get("player") == self:
		VisualStyle.draw_aim_indicator(self, body_radius, last_aim_direction)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0, 5.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0 * (health / max_health), 5.0)), Color(0.3, 1.0, 0.45))
	if swim_time_max > 0.0:
		_draw_meter(Vector2(-body_radius, body_radius + 6.0), body_radius * 2.0, get_swim_ratio(), Color(0.2, 0.7, 1.0))
	if flight_time_max > 0.0:
		_draw_meter(Vector2(-body_radius, body_radius + 12.0), body_radius * 2.0, get_flight_ratio(), Color(0.9, 0.9, 0.45))
	if has_latch():
		draw_rect(Rect2(Vector2(-body_radius, body_radius + 18.0), Vector2(body_radius * 2.0, 3.0)), Color(1.0, 0.35, 0.25))

func _draw_meter(start: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(start, Vector2(width, 3.0)), Color(0.06, 0.06, 0.07))
	draw_rect(Rect2(start, Vector2(width * ratio, 3.0)), color)

func _draw_wrong_terrain_warning() -> void:
	var danger_t := clampf(wrong_terrain_seconds / WRONG_TERRAIN_GRACE_SEC, 0.0, 1.0)
	var late := wrong_terrain_seconds > WRONG_TERRAIN_GRACE_SEC
	var pulse := sin(Time.get_ticks_msec() * 0.012) * 0.5 + 0.5
	var color := Color(0.24, 0.72, 1.0, 0.26 + danger_t * 0.2)
	if late:
		color = Color(1.0, 0.25, 0.16, 0.46 + pulse * 0.18)
	var ring_radius := body_radius + 7.0 + pulse * (3.0 if late else 1.5)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, color, 2.5)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + pulse * 0.5
		var bubble := Vector2(cos(angle), sin(angle)) * (body_radius * 0.55 + float(i) * 2.0)
		draw_circle(bubble, 1.8 + danger_t * 1.4, color.lightened(0.15))
