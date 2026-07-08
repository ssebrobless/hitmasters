extends Node2D
## Champsosaurus side boss (BB-BOSS-3). First concrete boss; the shared boss_actor
## base is extracted later (BB-BOSS-6). Neutral (team = -1): its attacks threaten
## creatures of BOTH teams. Mirrors the WildlifeEncounter defeat/clear interface so
## it plugs into arena.on_wildlife_defeated (-> objective_state "claimable") and the
## existing zone bookkeeping. Deterministic: delta-based timers, no Input, no RNG.
##
## Attack grammar: TEL_warning -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint.

const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

# Tuning (playtest-adjustable).
const MAX_HEALTH := 260.0
const BODY_RADIUS := 24.0
const MOVE_SPEED := 62.0
const AGGRO_RANGE := 190.0
const LEASH_MARGIN := 28.0
const MIDDLE_REACH := 150.0        # px past map center (x=0) the boss may reach
const BITE_REACH := 40.0
const BITE_RADIUS := 34.0
const BITE_DAMAGE := 40.0
const WEAKPOINT_MULT := 1.6
const TEL_TIME := 0.7
const HIT_TIME := 0.12
const FX_TIME := 0.4
const RECOVERY_TIME := 1.0
const ATTACK_COOLDOWN := 1.2

var arena: Node = null
var team := -1
var zone_id := ""
var zone_side := ""
var species_id := ""
var actor_name := "Champsosaurus"
var boss := true
var max_health := MAX_HEALTH
var health := MAX_HEALTH
var body_radius := BODY_RADIUS
var alive := true

var home_center := Vector2.ZERO
var leash_rect := Rect2()
var facing := Vector2.RIGHT
var phase := "idle"                 # idle | tel | hit | fx | recovery
var phase_timer := 0.0
var attack_cooldown := 0.0
var bite_center := Vector2.ZERO
var anim_time := 0.0

func setup(next_arena, zone: Dictionary, next_species_id: String, spawn_position: Vector2, _index := 0) -> void:
	arena = next_arena
	zone_id = String(zone.get("id", ""))
	zone_side = String(zone.get("side", "neutral"))
	species_id = next_species_id
	max_health = MAX_HEALTH
	health = MAX_HEALTH
	body_radius = BODY_RADIUS
	home_center = zone.get("center", spawn_position)
	var radius: Vector2 = zone.get("radius", Vector2(120.0, 96.0))
	# Asymmetric soft leash: full home zone plus a reach into the middle contest
	# band, but never deep into enemy territory past the map center.
	var min_y := home_center.y - radius.y - LEASH_MARGIN
	var max_y := home_center.y + radius.y + LEASH_MARGIN
	var min_x: float
	var max_x: float
	if zone_side == "red":
		min_x = -MIDDLE_REACH
		max_x = home_center.x + radius.x + LEASH_MARGIN
	else:
		min_x = home_center.x - radius.x - LEASH_MARGIN
		max_x = MIDDLE_REACH
	leash_rect = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	if arena != null and is_instance_valid(arena):
		leash_rect = leash_rect.intersection(arena.ARENA_RECT)
	global_position = spawn_position
	facing = Vector2.LEFT if zone_side == "red" else Vector2.RIGHT
	z_index = 6
	queue_redraw()

# --- entity interface (mirrors WildlifeEncounter so arena plumbing works) ---
func is_alive() -> bool:
	return alive

func is_scored_actor() -> bool:
	return false

func is_wildlife_encounter() -> bool:
	return true

func is_boss_actor() -> bool:
	return true

func is_weakpoint_open() -> bool:
	return phase == "recovery"

func get_actor_name() -> String:
	return actor_name

func take_damage(amount: float, _source_team := -1, source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, source_actor, "champsosaurus")
	take_damage_event(event)

func take_damage_event(event: Resource) -> void:
	if not alive:
		return
	var amount := maxf(float(event.amount), 0.0)
	if is_weakpoint_open():
		amount *= WEAKPOINT_MULT
	health = maxf(health - amount, 0.0)
	_emit_hit_event(event, amount)
	queue_redraw()
	if health <= 0.0:
		_die(event.source_actor)

func _die(source_actor: Node = null) -> void:
	alive = false
	visible = false
	if source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("on_kill"):
		source_actor.on_kill(self)
	if arena != null and is_instance_valid(arena) and arena.has_method("on_wildlife_defeated"):
		arena.on_wildlife_defeated(self, source_actor)
	elif arena != null and is_instance_valid(arena) and arena.has_method("unregister_entity"):
		arena.unregister_entity(self)
	queue_free()

func _emit_hit_event(event: Resource, amount: float) -> void:
	if arena == null or not is_instance_valid(arena) or not arena.has_method("record_vfx_event"):
		return
	var hit_position: Vector2 = event.hit_position if event.hit_position != Vector2.ZERO else global_position
	arena.record_vfx_event({
		"type": "hit_landed",
		"source": event.source_actor,
		"target": self,
		"amount": amount,
		"heavy": amount >= 50.0,
		"counter_hit": false,
		"position": global_position,
		"hit_position": hit_position,
		"hit_normal": event.hit_normal,
		"region": event.region,
		"region_mult": event.region_mult,
		"source_ability": event.source_ability
	})

# --- AI (deterministic; driven by _physics_process delta) ---
func _physics_process(delta: float) -> void:
	if not alive:
		return
	anim_time += delta
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if phase == "idle":
		_idle_behavior(delta)
	else:
		_advance_attack(delta)
	queue_redraw()

func _idle_behavior(delta: float) -> void:
	var target := _find_target()
	if target != null:
		var to_target: Vector2 = target.global_position - global_position
		var dist := to_target.length()
		if dist > 0.001:
			facing = to_target / dist
		if dist <= BITE_REACH + body_radius and attack_cooldown <= 0.0:
			_start_bite()
		elif dist > BITE_REACH:
			global_position = _clamp_to_leash(global_position + facing * MOVE_SPEED * delta)
	elif not leash_rect.has_point(global_position):
		var home_dir := home_center - global_position
		if home_dir.length() > 0.001:
			global_position = _clamp_to_leash(global_position + home_dir.normalized() * MOVE_SPEED * delta)

func _start_bite() -> void:
	phase = "tel"
	phase_timer = TEL_TIME
	bite_center = global_position + facing * (BITE_REACH + body_radius)
	if arena != null and is_instance_valid(arena):
		if arena.has_method("add_circle_telegraph"):
			arena.add_circle_telegraph(bite_center, BITE_RADIUS, Color(0.95, 0.86, 0.32, 0.9), TEL_TIME, 3.0, false)
		if arena.has_method("add_line_telegraph"):
			arena.add_line_telegraph(global_position, bite_center, Color(0.95, 0.86, 0.32, 0.7), TEL_TIME, 3.0)

func _advance_attack(delta: float) -> void:
	phase_timer -= delta
	if phase_timer > 0.0:
		return
	match phase:
		"tel":
			phase = "hit"
			phase_timer = HIT_TIME
			if arena != null and is_instance_valid(arena) and arena.has_method("damage_enemies_in_radius"):
				arena.damage_enemies_in_radius(team, bite_center, BITE_RADIUS, BITE_DAMAGE, self, "Jaw Gate")
		"hit":
			phase = "fx"
			phase_timer = FX_TIME
			# FX afterstate: churned shallow-water residue lingers over the bite.
			if arena != null and is_instance_valid(arena) and arena.has_method("add_circle_telegraph"):
				arena.add_circle_telegraph(bite_center, BITE_RADIUS * 0.9, Color(0.42, 0.55, 0.6, 0.4), FX_TIME + RECOVERY_TIME, 2.0, true)
		"fx":
			phase = "recovery"
			phase_timer = RECOVERY_TIME
		"recovery":
			phase = "idle"
			attack_cooldown = ATTACK_COOLDOWN

func _find_target() -> Node:
	if arena == null or not is_instance_valid(arena) or not ("entities" in arena):
		return null
	var best: Node = null
	var best_dist := AGGRO_RANGE
	for entity in arena.entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if not ("team" in entity):
			continue
		var t := int(entity.get("team"))
		if t != 0 and t != 1:
			continue
		# Only aggro real creatures -- skip huts, dams, minions, and breeding actors.
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		var point: Vector2 = entity.global_position
		if not leash_rect.has_point(point):
			continue
		var d := point.distance_to(global_position)
		if d < best_dist:
			best = entity
			best_dist = d
	return best

func _clamp_to_leash(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, leash_rect.position.x, leash_rect.end.x),
		clampf(p.y, leash_rect.position.y, leash_rect.end.y)
	)

func within_leash(point: Vector2) -> bool:
	return leash_rect.has_point(point)

# --- draw: readable oriented silhouette + phase cues (not final art) ---
func _draw() -> void:
	if not alive:
		return
	var f := facing
	var p := Vector2(-f.y, f.x)
	var base := Color(0.30, 0.42, 0.30)
	draw_circle(Vector2(2.0, 3.0), body_radius + 3.0, VisualGrammar.shadow_color(0.62))
	draw_circle(Vector2.ZERO, body_radius, base)
	draw_circle(-f * body_radius * 0.6, body_radius * 0.7, base.darkened(0.05))
	var snout_l := f * body_radius + p * (body_radius * 0.28)
	var snout_r := f * body_radius - p * (body_radius * 0.28)
	var snout_tip := f * (body_radius + 22.0)
	draw_colored_polygon(PackedVector2Array([snout_l, snout_r, snout_tip]), base.lightened(0.06))
	draw_circle(f * body_radius * 0.2 + p * body_radius * 0.5, 2.2, Color(0.9, 0.9, 0.82))
	draw_circle(f * body_radius * 0.2 - p * body_radius * 0.5, 2.2, Color(0.9, 0.9, 0.82))
	if phase == "tel":
		var jaw := f * (body_radius + 22.0)
		draw_line(f * body_radius, jaw + p * 10.0, Color(0.95, 0.86, 0.32, 0.9), 3.0)
		draw_line(f * body_radius, jaw - p * 10.0, Color(0.95, 0.86, 0.32, 0.9), 3.0)
	if is_weakpoint_open():
		var wp := f * (body_radius * 0.6)
		var pulse := 0.6 + 0.4 * sin(anim_time * 10.0)
		draw_circle(wp, body_radius * 0.42, Color(0.3, 0.9, 0.8, 0.35 * pulse))
		draw_arc(wp, body_radius * 0.42, 0.0, TAU, 20, Color(0.4, 1.0, 0.85, 0.9), 2.0)
	draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 40, Color(1.0, 0.76, 0.28, 0.85), 3.0)
	_draw_health_bar()

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var width := maxf(body_radius * 2.4, 30.0)
	var y := -body_radius - 12.0
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 4.0)), Color(0.05, 0.03, 0.02, 0.85))
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 4.0)), Color(0.95, 0.72, 0.32, 0.95))
