extends CharacterBody2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const EnvironmentProfileScript := preload("res://scripts/sim/environment_profile.gd")
const MovementFeelScript := preload("res://scripts/sim/movement_feel.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const HurtboxScript := preload("res://scripts/sim/combat/hurtbox.gd")
const PerfStats := preload("res://scripts/game/perf_stats.gd")
const VisualStyle := preload("res://scripts/visual/visual_style.gd")
const TurtleKitScript := preload("res://scripts/sim/kits/snapping_turtle.gd")
const WaterSnakeKitScript := preload("res://scripts/sim/kits/water_snake.gd")
const AlligatorKitScript := preload("res://scripts/sim/kits/alligator.gd")
const WolfSpiderKitScript := preload("res://scripts/sim/kits/wolf_spider.gd")
const FireflyKitScript := preload("res://scripts/sim/kits/firefly.gd")
const MosquitoSwarmKitScript := preload("res://scripts/sim/kits/mosquito_swarm.gd")
const FrogKitScript := preload("res://scripts/sim/kits/chorus_frog.gd")
const NewtKitScript := preload("res://scripts/sim/kits/newt.gd")
const MinkKitScript := preload("res://scripts/sim/kits/mink.gd")
const BullfrogKitScript := preload("res://scripts/sim/kits/bullfrog.gd")
const CaneToadKitScript := preload("res://scripts/sim/kits/cane_toad.gd")
const CrayfishKitScript := preload("res://scripts/sim/kits/crayfish.gd")
const WaterShrewKitScript := preload("res://scripts/sim/kits/water_shrew.gd")
const BeaverKitScript := preload("res://scripts/sim/kits/beaver.gd")
const OwlKitScript := preload("res://scripts/sim/kits/owl.gd")
const HeronKitScript := preload("res://scripts/sim/kits/great_blue_heron.gd")
const KingfisherKitScript := preload("res://scripts/sim/kits/kingfisher.gd")
const DuckKitScript := preload("res://scripts/sim/kits/duck.gd")

const WRONG_TERRAIN_GRACE_SEC := 3.0
const WRONG_TERRAIN_EARLY_DPS := 0.02
const WRONG_TERRAIN_LATE_DPS := 0.05
const TAKEOFF_DISTANCE_UNITS := 2.0
const FLIGHT_GROUNDED_LOCKOUT_SEC := 3.0
const TERRAIN_SPEED_LERP_RATE := 9.0
const HUNGER_MAX := 100.0
const HUNGER_FULL_TO_EMPTY_SEC := 105.0

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
var body_capsule_half_len_px := 0.0
var base_speed_px := 0.0
var terrain_speed_px := 0.0
var terrain_speed_target_px := 0.0
var movement_profile: Dictionary = {}
var current_terrain_zone := TerrainMapScript.LAND
var previous_terrain_zone := TerrainMapScript.LAND
var current_environment_profile: Dictionary = {}
var swim_time_max := 0.0
var swim_time_remaining := 0.0
var wrong_terrain_seconds := 0.0
var flight_time_max := 0.0
var flight_time_remaining := 0.0
var flight_grounded_timer := 0.0
var flight_toggle_was_pressed := false
var flight_toggle_just_pressed := false
var flight_toggle_requires_release := false
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
var pass_obstacles_timer := 0.0
var modifiers: Array[Dictionary] = []
var healing_ticks: Array[Dictionary] = []
var damage_ticks: Array[Dictionary] = []
var secondary_resource_label := ""
var secondary_resource := 0.0
var secondary_resource_max := 0.0
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
var last_move_displacement_px := 0.0
var stealth_timer := 0.0
var low_window_timer := 0.0
var respawn_timer := 0.0
var respawn_duration := 5.0
var hunger := HUNGER_MAX
var hunger_satiated := false

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
	body_capsule_half_len_px = _footprint_capsule_half_len_px()
	movement_profile = MovementFeelScript.profile_for(creature_id)
	base_speed_px = _speed_px_for_ground()
	swim_time_max = _numeric_stat("swim_time_sec", 0.0)
	swim_time_remaining = swim_time_max
	_reset_terrain_profile()
	flight_time_max = _numeric_stat("flight_time_sec", 0.0)
	flight_time_remaining = flight_time_max
	flight_toggle_was_pressed = false
	flight_toggle_just_pressed = false
	flight_toggle_requires_release = false
	state = CreatureStateScript.State.AIRBORNE if has_movement("always_flying") else CreatureStateScript.State.NORMAL
	actor_name = String(creature_data.get("name", creature_id))
	modifiers.clear()
	healing_ticks.clear()
	damage_ticks.clear()
	secondary_resource_label = ""
	secondary_resource = 0.0
	secondary_resource_max = 0.0
	latched_attacker = null
	latch_victim = null
	latch_timer = 0.0
	latch_source = ""
	latch_execute_timer = 0.0
	kit = _make_kit()
	if kit != null:
		kit.setup(self)
	alive = true
	hunger = HUNGER_MAX
	hunger_satiated = false
	queue_redraw()

func set_input_frame(next_frame: Resource) -> void:
	input_frame = next_frame

func _physics_process(delta: float) -> void:
	var perf_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	tick_sim(delta)
	if PerfStats.enabled:
		PerfStats.add("creatures", int(Time.get_ticks_usec() - perf_start))

func _process(delta: float) -> void:
	render_flash_timer = maxf(render_flash_timer - delta, 0.0)
	render_shake_timer = maxf(render_shake_timer - delta, 0.0)
	anim_attack_timer = maxf(anim_attack_timer - delta, 0.0)
	anim_windup_timer = maxf(anim_windup_timer - delta, 0.0)
	if velocity.length() > 4.0:
		anim_walk_phase += MovementFeelScript.gait_phase_delta(velocity.length(), delta, movement_profile)
	if arena == null or not arena.has_method("is_near_view") or arena.is_near_view(global_position):
		queue_redraw()

func tick_sim(delta: float) -> void:
	if not alive:
		if arena != null and arena.has_method("uses_stock_respawn") and arena.uses_stock_respawn(self):
			if arena.tick_stock_respawn(self, delta):
				_respawn()
		else:
			respawn_timer = maxf(respawn_timer - delta, 0.0)
			if respawn_timer <= 0.0:
				_respawn()
		return

	_tick_timers(delta)
	_update_flight_toggle_edge()
	flight_grounded_timer = maxf(flight_grounded_timer - delta, 0.0)
	stealth_timer = maxf(stealth_timer - delta, 0.0)
	low_window_timer = maxf(low_window_timer - delta, 0.0)
	_update_flight(delta)
	_update_terrain(delta)
	_move_from_input(delta)
	_tick_hunger(delta)
	_try_auto_eat()
	_update_takeoff_charge_from_displacement(last_move_displacement_px)
	_tick_latch(delta)
	if kit != null and kit.has_method("tick"):
		var original_input_frame: Resource = input_frame
		if input_frame != null and not can_use_abilities():
			input_frame = _without_ability_buttons(input_frame)
		kit.tick(self, delta)
		input_frame = original_input_frame
	_commit_flight_toggle_edge()

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

func can_use_abilities() -> bool:
	return can_act() and _modifier_value("ability_use_mult", 1.0) > 0.5

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
	var before_health := health
	var amount: float = _modified_incoming_damage(event)
	if health - amount <= 0.0 and kit != null and kit.has_method("intercept_fatal_damage"):
		if kit.intercept_fatal_damage(self, event, amount):
			return
	health = maxf(health - amount, 0.0)
	if event.delivery == DamageEventScript.DELIVERY_MELEE and event.source_actor != null and is_instance_valid(event.source_actor) and event.source_actor != self:
		if kit != null and kit.has_method("on_melee_contact_damage"):
			kit.on_melee_contact_damage(self, event.source_actor, amount, event)
	if kit != null and kit.has_method("on_damage_taken"):
		kit.on_damage_taken(self, event, amount, before_health)
	# Struggle hit (decision #33): the victim's melee blows chunk the grip.
	if latch_victim != null and is_instance_valid(latch_victim) and event.source_actor == latch_victim and event.delivery == DamageEventScript.DELIVERY_MELEE:
		latch_timer = maxf(latch_timer - 0.75, 0.0)
		latch_victim.latch_timer = latch_timer
	# Spike rule (decision #20): a heavy ranged hit grounds a flying bird.
	if state == CreatureStateScript.State.AIRBORNE and not has_movement("always_flying") and event.delivery == DamageEventScript.DELIVERY_RANGED and amount >= 30.0:
		state = CreatureStateScript.State.NORMAL
		flight_grounded_timer = FLIGHT_GROUNDED_LOCKOUT_SEC
		flight_toggle_requires_release = true
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

func apply_dot(source_actor: Node, source_ability: String, total_damage: float, duration: float, max_stacks := 0) -> void:
	if not alive or total_damage <= 0.0 or duration <= 0.0:
		return
	if max_stacks > 0:
		var matching := 0
		var oldest_index := -1
		for i in damage_ticks.size():
			var tick: Dictionary = damage_ticks[i]
			if String(tick.get("source_ability", "")) == source_ability and tick.get("source_actor", null) == source_actor:
				matching += 1
				if oldest_index < 0:
					oldest_index = i
		if matching >= max_stacks and oldest_index >= 0:
			damage_ticks.remove_at(oldest_index)
	damage_ticks.append({
		"remaining": duration,
		"amount_remaining": total_damage,
		"per_second": total_damage / duration,
		"source_actor": source_actor,
		"source_ability": source_ability
	})

func get_secondary_resource_state() -> Dictionary:
	var max_value := maxf(secondary_resource_max, 0.0)
	return {
		"visible": max_value > 0.0,
		"label": secondary_resource_label,
		"value": clampf(secondary_resource, 0.0, max_value),
		"max": max_value,
		"ratio": clampf(secondary_resource / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	}

func can_eat_food_kind(food_kind: String) -> bool:
	var diet := String(creature_data.get("diet", "omnivore"))
	if food_kind == "plant":
		return diet == "herbivore" or diet == "omnivore" or diet == "nectarivore"
	if food_kind == "critter":
		return diet == "carnivore" or diet == "omnivore"
	return false

func consume_food(kind: String, food_value: float, heal_fraction: float) -> bool:
	if not alive or not can_eat_food_kind(kind):
		return false
	var before := hunger
	hunger = minf(hunger + food_value, HUNGER_MAX)
	if hunger >= HUNGER_MAX:
		hunger_satiated = true
	heal(max_health * heal_fraction)
	if arena != null and arena.has_method("record_food_consumed"):
		arena.record_food_consumed(self, kind, hunger - before)
	return true

func is_satiated() -> bool:
	return hunger_satiated

func reset_hunger_after_deposit() -> void:
	hunger_satiated = false
	hunger = HUNGER_MAX * 0.7

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

func is_untargetable() -> bool:
	return _modifier_value("untargetable", 1.0) > 1.5

func has_movement(tag: String) -> bool:
	return movement_tags.has(tag)

func get_current_zone() -> String:
	if arena != null and arena.has_method("get_terrain_zone"):
		return arena.get_terrain_zone(global_position)
	if terrain_map != null:
		return terrain_map.get_zone_at(global_position)
	return TerrainMapScript.LAND

func get_speed_px() -> float:
	if is_airborne():
		return _speed_px_for_flight()
	return terrain_speed_px if terrain_speed_px > 0.0 else _terrain_target_speed_px(get_current_zone())

func get_swim_ratio() -> float:
	if swim_time_max <= 0.0:
		return 1.0
	return clampf(swim_time_remaining / swim_time_max, 0.0, 1.0)

func get_flight_ratio() -> float:
	if flight_time_max <= 0.0:
		return 1.0
	return clampf(flight_time_remaining / flight_time_max, 0.0, 1.0)

func _move_from_input(delta: float) -> void:
	var start_position := global_position
	last_move_displacement_px = 0.0
	if state == CreatureStateScript.State.BURROWED:
		velocity = Vector2.ZERO
		return
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
	if _modifier_value("forward_back_only", 1.0) > 1.5 and move != Vector2.ZERO:
		var axis := last_aim_direction.normalized()
		move = axis * move.dot(axis)
	var speed_multiplier := latch_move_multiplier * _modifier_value("move_speed_mult", 1.0)
	if dash_timer > 0.0:
		velocity = dash_velocity
	else:
		velocity = MovementFeelScript.profiled_velocity(velocity, move, get_speed_px() * speed_multiplier, delta, movement_profile)
	if Engine.is_in_physics_frame():
		move_and_slide()
	else:
		global_position += velocity * delta
	if arena != null:
		if is_airborne():
			# Airborne creatures pass over obstacles; only the arena bounds apply.
			global_position = arena.clamp_to_arena(global_position)
		elif pass_obstacles_timer <= 0.0 and arena.has_method("resolve_body_position"):
			global_position = arena.resolve_body_position(global_position, body_radius)
	last_move_displacement_px = global_position.distance_to(start_position)

func _update_terrain(delta: float) -> void:
	var zone := get_current_zone()
	previous_terrain_zone = current_terrain_zone
	current_terrain_zone = zone
	current_environment_profile = _environment_profile_for_zone(zone)
	terrain_speed_target_px = _terrain_target_speed_px(zone)
	var terrain_lerp_rate := float(movement_profile.get("terrain_lerp_rate", TERRAIN_SPEED_LERP_RATE))
	terrain_speed_px = lerpf(terrain_speed_px if terrain_speed_px > 0.0 else terrain_speed_target_px, terrain_speed_target_px, clampf(delta * terrain_lerp_rate, 0.0, 1.0))

	if not is_airborne() and bool(current_environment_profile.get("drains_swim", false)):
		if _has_limited_swim_time():
			swim_time_remaining = maxf(swim_time_remaining - delta, 0.0)

	if not is_airborne() and _is_wrong_terrain():
		wrong_terrain_seconds += delta
		var rate := WRONG_TERRAIN_LATE_DPS if wrong_terrain_seconds > WRONG_TERRAIN_GRACE_SEC else WRONG_TERRAIN_EARLY_DPS
		take_damage(max_health * rate * delta)
	elif bool(current_environment_profile.get("restores_swim", true)):
		wrong_terrain_seconds = 0.0
		if swim_time_max > 0.0:
			swim_time_remaining = minf(swim_time_remaining + delta, swim_time_max)
	else:
		wrong_terrain_seconds = 0.0

func _update_flight(delta: float) -> void:
	if has_movement("always_flying"):
		state = CreatureStateScript.State.AIRBORNE
		return

	if state == CreatureStateScript.State.PERCHED:
		return

	if is_airborne():
		if _should_voluntary_land():
			state = CreatureStateScript.State.NORMAL
			takeoff_distance_px = 0.0
			flight_toggle_requires_release = true
			break_stealth()
			return
		flight_time_remaining = maxf(flight_time_remaining - delta, 0.0)
		takeoff_distance_px = 0.0
		if flight_time_max > 0.0 and flight_time_remaining <= 0.0:
			state = CreatureStateScript.State.NORMAL
			flight_grounded_timer = FLIGHT_GROUNDED_LOCKOUT_SEC
			flight_toggle_requires_release = true
			break_stealth()
		return

	if flight_time_max <= 0.0 or not has_movement("flight"):
		return

	flight_time_remaining = minf(flight_time_remaining + delta, flight_time_max)
	if flight_grounded_timer > 0.0 or input_frame == null:
		takeoff_distance_px = 0.0
		return

	if flight_toggle_requires_release or not input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE) or input_frame.move.length() <= 0.0:
		takeoff_distance_px = 0.0

func _update_flight_toggle_edge() -> void:
	var pressed: bool = input_frame != null and input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE)
	flight_toggle_just_pressed = pressed and not flight_toggle_was_pressed
	if not pressed:
		flight_toggle_requires_release = false

func _commit_flight_toggle_edge() -> void:
	flight_toggle_was_pressed = input_frame != null and input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE)
	if not flight_toggle_was_pressed:
		flight_toggle_just_pressed = false

func _should_voluntary_land() -> bool:
	return has_movement("flight") and flight_toggle_just_pressed and not flight_toggle_requires_release

func _update_takeoff_charge_from_displacement(displacement_px: float) -> void:
	if state == CreatureStateScript.State.PERCHED or is_airborne() or flight_time_max <= 0.0 or not has_movement("flight"):
		takeoff_distance_px = 0.0
		return
	if flight_grounded_timer > 0.0 or input_frame == null:
		takeoff_distance_px = 0.0
		return
	if flight_toggle_requires_release or not input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE) or input_frame.move.length() <= 0.0:
		takeoff_distance_px = 0.0
		return
	takeoff_distance_px += maxf(displacement_px, 0.0)
	if takeoff_distance_px >= TAKEOFF_DISTANCE_UNITS * SimConstants.UNIT_PX:
		state = CreatureStateScript.State.AIRBORNE
		takeoff_distance_px = 0.0
		flight_toggle_requires_release = true

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
	if _modifier_value("cc_immune", 1.0) > 1.5 and _is_disruption_modifier(values):
		return
	modifiers.append({"source": source, "values": values, "remaining": duration})

func add_capped_modifier(source: String, values: Dictionary, duration: float, max_stacks: int) -> void:
	if max_stacks > 0:
		var matching := 0
		var oldest_index := -1
		for i in modifiers.size():
			if String(modifiers[i].get("source", "")) == source:
				matching += 1
				if oldest_index < 0:
					oldest_index = i
		if matching >= max_stacks and oldest_index >= 0:
			modifiers.remove_at(oldest_index)
	add_modifier(source, values, duration)

func remove_modifiers_from_source(source: String) -> void:
	for i in range(modifiers.size() - 1, -1, -1):
		if String(modifiers[i].get("source", "")) == source:
			modifiers.remove_at(i)

func cleanse_negative_modifiers() -> void:
	for i in range(modifiers.size() - 1, -1, -1):
		var values: Dictionary = modifiers[i].get("values", {})
		if _is_negative_modifier(values):
			modifiers.remove_at(i)

func get_modifier_value(key: String, fallback: float) -> float:
	return _modifier_value(key, fallback)

func _without_ability_buttons(frame: Resource) -> Resource:
	var filtered := InputFrameScript.new()
	filtered.move = frame.move
	filtered.aim = frame.aim
	filtered.buttons = int(frame.buttons)
	filtered.set_button(InputFrameScript.BUTTON_ABILITY_Q, false)
	filtered.set_button(InputFrameScript.BUTTON_ABILITY_E, false)
	return filtered

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
	# Decision #33: the latched pair moves at 45% of the victim's base speed.
	latch_move_multiplier = 0.45

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
	if kit != null and kit.has_method("on_kill"):
		kit.on_kill(self, _victim)

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
	damage_ticks.clear()
	if kit != null and kit.has_method("reset_for_respawn"):
		kit.reset_for_respawn(self)
	swim_time_remaining = swim_time_max
	flight_time_remaining = flight_time_max
	flight_grounded_timer = 0.0
	flight_toggle_was_pressed = false
	flight_toggle_just_pressed = false
	flight_toggle_requires_release = false
	wrong_terrain_seconds = 0.0
	_reset_terrain_profile()
	dash_velocity = Vector2.ZERO
	dash_timer = 0.0
	pass_obstacles_timer = 0.0
	primary_timer = 0.4
	q_timer = maxf(q_timer, 1.0)
	e_timer = maxf(e_timer, 1.0)
	state = CreatureStateScript.State.AIRBORNE if has_movement("always_flying") else CreatureStateScript.State.NORMAL
	if arena != null:
		if arena.has_method("get_actor_respawn_position"):
			global_position = arena.get_actor_respawn_position(self)
		elif arena.has_method("get_team_spawn"):
			global_position = arena.get_team_spawn(team)
		if arena.has_method("register_entity"):
			arena.register_entity(self)
		if arena.has_method("on_actor_respawned"):
			arena.on_actor_respawned(self)
		if arena.has_method("add_circle_telegraph"):
			arena.add_circle_telegraph(global_position, body_radius + 26.0, Color(0.45, 0.72, 1.0, 0.75) if team == 0 else Color(1.0, 0.4, 0.35, 0.75), 0.6, 4.0, true)
	hunger = HUNGER_MAX
	hunger_satiated = false
	queue_redraw()

func _tick_timers(delta: float) -> void:
	primary_timer = maxf(primary_timer - delta, 0.0)
	q_timer = maxf(q_timer - delta, 0.0)
	e_timer = maxf(e_timer - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	pass_obstacles_timer = maxf(pass_obstacles_timer - delta, 0.0)
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
	for i in range(damage_ticks.size() - 1, -1, -1):
		if not alive:
			break
		var tick: Dictionary = damage_ticks[i]
		var tick_amount: float = minf(float(tick["amount_remaining"]), float(tick["per_second"]) * delta)
		if tick_amount > 0.0:
			var source_actor: Node = tick.get("source_actor", null)
			if source_actor != null and not is_instance_valid(source_actor):
				source_actor = null
			var event := DamageEventScript.new()
			event.setup(tick_amount, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, source_actor, String(tick.get("source_ability", "")))
			take_damage_event(event)
		tick["amount_remaining"] = float(tick["amount_remaining"]) - tick_amount
		tick["remaining"] = float(tick["remaining"]) - delta
		damage_ticks[i] = tick
		if float(tick["remaining"]) <= 0.0 or float(tick["amount_remaining"]) <= 0.0:
			damage_ticks.remove_at(i)

func _tick_hunger(delta: float) -> void:
	if hunger_satiated:
		return
	hunger = maxf(hunger - (HUNGER_MAX / HUNGER_FULL_TO_EMPTY_SEC) * delta, 0.0)
	if hunger <= 0.0 and alive:
		var event := DamageEventScript.new()
		event.setup(max_health * 10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, null, "Starvation")
		take_damage_event(event)

func _try_auto_eat() -> void:
	if arena != null and arena.has_method("try_eat_nearby_food"):
		arena.try_eat_nearby_food(self)

func _tick_latch(delta: float) -> void:
	if latch_victim != null and is_instance_valid(latch_victim):
		var offset: Vector2 = global_position - latch_victim.global_position
		if offset == Vector2.ZERO:
			offset = Vector2.LEFT
		var drag_direction: Vector2 = offset.normalized()
		# Grip meter (decision #33): the victim struggling — moving against
		# the drag — drains the latch 1.5x. Attacker owns the grip; the
		# victim's timer mirrors it so both sides read the same value.
		var grip_drain := delta
		var victim_velocity: Vector2 = latch_victim.velocity
		if victim_velocity.length() > 8.0 and victim_velocity.normalized().dot(drag_direction) < -0.3:
			grip_drain = delta * 1.5
		latch_timer = maxf(latch_timer - grip_drain, 0.0)
		latch_victim.latch_timer = latch_timer
		latch_execute_timer = maxf(latch_execute_timer - delta, 0.0)
		if max_health > latch_victim.max_health:
			latch_victim.global_position += drag_direction * get_speed_px() * 0.18 * delta
		global_position = latch_victim.global_position + drag_direction * (body_radius + latch_victim.body_radius * 0.5)
		if latch_execute_timer == 0.0 and latch_source == "Choke":
			latch_victim.take_damage_event(make_damage_event(latch_victim.health, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, latch_source))
			release_latch("execute")
		elif latch_timer <= 0.0:
			release_latch("timeout")
	elif latched_attacker != null and is_instance_valid(latched_attacker):
		if latched_attacker.latch_victim == self:
			# Attacker mirrors the grip onto us each tick; no double drain.
			if latch_timer <= 0.0:
				latched_attacker.release_latch("timeout")
		else:
			# Stale link: our attacker moved on to someone else.
			latch_timer = maxf(latch_timer - delta, 0.0)
			if latch_timer <= 0.0:
				latched_attacker = null
				latch_move_multiplier = 1.0

func _modified_incoming_damage(event: Resource) -> float:
	if _modifier_value("invulnerable", 1.0) > 1.5:
		return 0.0
	var amount: float = event.amount
	amount *= _modifier_value("damage_taken_mult", 1.0)
	# Decision #33: while latched on, third parties deal 75% — the victim's
	# own fight-back stays the premier answer to a latch.
	if latch_victim != null and is_instance_valid(latch_victim) and event.source_actor != null and event.source_actor != latch_victim:
		amount *= 0.75
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
	if kit != null and kit.has_method("modify_incoming_damage"):
		amount = kit.modify_incoming_damage(self, event, amount)
	return amount

func _modifier_value(key: String, fallback: float) -> float:
	var output := fallback
	for modifier in modifiers:
		var values: Dictionary = modifier.get("values", {})
		if values.has(key):
			output *= float(values[key])
	return output

func _is_disruption_modifier(values: Dictionary) -> bool:
	if values.has("can_act_mult") and float(values["can_act_mult"]) <= 0.5:
		return true
	if values.has("ability_use_mult") and float(values["ability_use_mult"]) <= 0.5:
		return true
	return values.has("move_speed_mult") and float(values["move_speed_mult"]) <= 0.0

func _is_negative_modifier(values: Dictionary) -> bool:
	for key in values.keys():
		var value := float(values[key])
		match String(key):
			"can_act_mult", "ability_use_mult", "move_speed_mult", "attack_speed_mult", "damage_dealt_mult", "healing_received_mult":
				if value < 1.0:
					return true
			"damage_taken_mult":
				if value > 1.0:
					return true
	return false

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
	if _percent_regex == null:
		_percent_regex = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)%")
	if _percent_regex == null:
		return fallback
	var results := _percent_regex.search_all(text)
	if index < 0 or index >= results.size():
		return fallback
	return float(results[index].get_string(1)) / 100.0

func _make_kit() -> RefCounted:
	match creature_id:
		"snapping_turtle":
			return TurtleKitScript.new()
		"water_snake":
			return WaterSnakeKitScript.new()
		"alligator":
			return AlligatorKitScript.new()
		"wolf_spider":
			return WolfSpiderKitScript.new()
		"firefly":
			return FireflyKitScript.new()
		"mosquito_swarm":
			return MosquitoSwarmKitScript.new()
		"chorus_frog":
			return FrogKitScript.new()
		"newt":
			return NewtKitScript.new()
		"mink":
			return MinkKitScript.new()
		"bullfrog":
			return BullfrogKitScript.new()
		"cane_toad":
			return CaneToadKitScript.new()
		"crayfish":
			return CrayfishKitScript.new()
		"water_shrew":
			return WaterShrewKitScript.new()
		"beaver":
			return BeaverKitScript.new()
		"owl":
			return OwlKitScript.new()
		"great_blue_heron":
			return HeronKitScript.new()
		"kingfisher":
			return KingfisherKitScript.new()
		"duck":
			return DuckKitScript.new()
		_:
			return null

func _is_wrong_terrain() -> bool:
	if current_environment_profile.is_empty():
		current_environment_profile = _environment_profile_for_zone(get_current_zone())
	return bool(current_environment_profile.get("wrong_terrain_now", false))

func _uses_deep_water_swim_speed() -> bool:
	return EnvironmentProfileScript.uses_swim_speed_in_deep_water(_effective_movement_tags())

func _has_limited_swim_time() -> bool:
	return EnvironmentProfileScript.has_limited_swim_time(_effective_movement_tags()) and swim_time_max > 0.0

func _reset_terrain_profile() -> void:
	current_terrain_zone = get_current_zone()
	previous_terrain_zone = current_terrain_zone
	current_environment_profile = _environment_profile_for_zone(current_terrain_zone)
	terrain_speed_target_px = _terrain_target_speed_px(current_terrain_zone)
	terrain_speed_px = terrain_speed_target_px

func _environment_profile_for_zone(zone: String) -> Dictionary:
	if terrain_map != null and terrain_map.has_method("get_environment_profile_for_zone"):
		return terrain_map.get_environment_profile_for_zone(zone, _effective_movement_tags(), swim_time_remaining)
	return EnvironmentProfileScript.for_zone(zone, _effective_movement_tags(), swim_time_remaining)

func _effective_movement_tags() -> Array:
	var tags := movement_tags.duplicate()
	if _modifier_value("water_walk", 1.0) > 1.5 and not tags.has("water_walk"):
		tags.append("water_walk")
	return tags

func _terrain_target_speed_px(zone: String) -> float:
	var profile := _environment_profile_for_zone(zone)
	var speed_mult := float(profile.get("speed_mult", 1.0))
	if zone == TerrainMapScript.WATER and _uses_deep_water_swim_speed():
		return _speed_px_for_water() * speed_mult
	return _speed_px_for_ground() * speed_mult

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

# Capsule bodies (decision #19: Water Snake 0.4x2.5, Alligator 0.9x3.0) keep
# body_radius as the capsule radius and expose the core-segment half length
# so the hurtbox hull (decision #21) covers the full designed body.
func _footprint_capsule_half_len_px() -> float:
	var footprint: Dictionary = creature_data.get("footprint", {})
	if String(footprint.get("shape", "circle")) != "capsule":
		return 0.0
	var length_px: float = _catalog().units_to_px(float(footprint.get("length_units", 0.0)))
	return maxf(0.0, length_px * 0.5 - _footprint_radius_px())

func get_hurtbox_hull() -> Dictionary:
	return HurtboxScript.hull_of(self)

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
	var anim := MovementFeelScript.render_anim(movement_profile, anim_walk_phase)
	anim.merge({
		"walk_phase": anim_walk_phase,
		"moving": velocity.length() > 4.0,
		"attack_t": 1.0 - anim_attack_timer / anim_attack_duration if anim_attack_timer > 0.0 else -1.0,
		"attack_reach": anim_attack_reach,
		"attack_aim": anim_attack_aim,
		"windup_t": 1.0 - anim_windup_timer / anim_windup_duration if anim_windup_timer > 0.0 else -1.0,
		"shake_offset": shake_offset
	})
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
	_draw_meter(Vector2(-body_radius, body_radius + 24.0), body_radius * 2.0, clampf(hunger / HUNGER_MAX, 0.0, 1.0), Color(0.92, 0.7, 0.28) if not hunger_satiated else Color(0.45, 1.0, 0.52))

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
