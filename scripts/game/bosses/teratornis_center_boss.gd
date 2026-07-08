extends Node2D
## Teratornis center big boss (BB-BOSS-5). Neutral (team = -1), spawns at map center on a
## schedule, 50% larger than a side boss, map-wide (NO leash). Its signature Grand Hunt
## Shadow REVEALS creatures of both teams through the BB-VIS-1 vision service before the dive
## lands -- proving anti-comfort, map-wide readability. Mirrors the WildlifeEncounter defeat
## interface so it routes through arena.on_wildlife_defeated -> the shared claim window, which
## grants the claiming team a combat reward (no directed disruption for center bosses).
##
## Attack grammar: TEL_warning(+reveal) -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint.

const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

# Tuning (playtest-adjustable). Sized ~50% larger than the Champsosaurus side boss.
const SIZE_MULT := 1.5
const MAX_HEALTH := 520.0
const BODY_RADIUS := 36.0
const MOVE_SPEED := 54.0
const AGGRO_RANGE := 100000.0          # map-wide: always has a target
const REVEAL_RADIUS := 260.0           # Grand Hunt Shadow reveal footprint
const REVEAL_DURATION := 2.4
const DIVE_REACH := 70.0
const DIVE_RADIUS := 90.0
const DIVE_DAMAGE := 46.0
const WEAKPOINT_MULT := 1.6
const TEL_TIME := 0.9
const HIT_TIME := 0.14
const FX_TIME := 0.5
const RECOVERY_TIME := 1.2
const ATTACK_COOLDOWN := 1.6

var arena: Node = null
var team := -1
var zone_id := ""
var species_id := ""
var actor_name := "Teratornis"
var boss := true
var center_boss := true
var boss_family := "teratornis"
var max_health := MAX_HEALTH
var health := MAX_HEALTH
var body_radius := BODY_RADIUS
var alive := true

var home_center := Vector2.ZERO
var facing := Vector2.RIGHT
var phase := "idle"                    # idle | tel | hit | fx | recovery
var phase_timer := 0.0
var attack_cooldown := 0.0
var dive_center := Vector2.ZERO
var anim_time := 0.0

func setup(next_arena, zone: Dictionary, next_species_id: String, spawn_position: Vector2, _index := 0) -> void:
	arena = next_arena
	zone_id = String(zone.get("id", ""))
	species_id = next_species_id
	boss_family = String(zone.get("boss_family", "teratornis"))
	max_health = MAX_HEALTH
	health = MAX_HEALTH
	body_radius = BODY_RADIUS
	home_center = zone.get("center", spawn_position)
	global_position = spawn_position
	z_index = 7
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

func is_center_boss() -> bool:
	return true

func is_weakpoint_open() -> bool:
	return phase == "recovery"

func get_actor_name() -> String:
	return actor_name

func take_damage(amount: float, _source_team := -1, source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, source_actor, "teratornis")
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
		if dist <= DIVE_REACH + body_radius and attack_cooldown <= 0.0:
			_start_dive(target)
		elif dist > DIVE_REACH:
			global_position += facing * MOVE_SPEED * delta
	else:
		# No creatures anywhere: drift back toward center.
		var home_dir := home_center - global_position
		if home_dir.length() > 1.0:
			global_position += home_dir.normalized() * MOVE_SPEED * delta

func _start_dive(target: Node) -> void:
	phase = "tel"
	phase_timer = TEL_TIME
	dive_center = target.global_position
	# Grand Hunt Shadow: reveal creatures in the shadow to BOTH teams before the dive.
	_reveal_creatures_near(dive_center, REVEAL_RADIUS)
	if arena != null and is_instance_valid(arena):
		if arena.has_method("add_circle_telegraph"):
			arena.add_circle_telegraph(dive_center, DIVE_RADIUS, Color(0.86, 0.62, 0.32, 0.9), TEL_TIME, 3.0, false)
			arena.add_circle_telegraph(dive_center, REVEAL_RADIUS, Color(0.55, 0.6, 0.78, 0.28), REVEAL_DURATION, 2.0, true)
		if arena.has_method("add_line_telegraph"):
			arena.add_line_telegraph(global_position, dive_center, Color(0.86, 0.62, 0.32, 0.65), TEL_TIME, 3.0)

func _reveal_creatures_near(center: Vector2, radius: float) -> void:
	if arena == null or not is_instance_valid(arena) or not arena.has_method("reveal_entity_to_team"):
		return
	if not ("entities" in arena):
		return
	for entity in arena.entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if entity.global_position.distance_to(center) > radius:
			continue
		# Anti-comfort: reveal each fighter to BOTH teams so neither side hides near center.
		arena.reveal_entity_to_team(entity, 0, REVEAL_DURATION)
		arena.reveal_entity_to_team(entity, 1, REVEAL_DURATION)

func _advance_attack(delta: float) -> void:
	phase_timer -= delta
	if phase_timer > 0.0:
		return
	match phase:
		"tel":
			phase = "hit"
			phase_timer = HIT_TIME
			if arena != null and is_instance_valid(arena) and arena.has_method("damage_creatures_in_radius"):
				arena.damage_creatures_in_radius(team, dive_center, DIVE_RADIUS, DIVE_DAMAGE, self, "Grand Hunt Shadow")
		"hit":
			phase = "fx"
			phase_timer = FX_TIME
			if arena != null and is_instance_valid(arena) and arena.has_method("add_circle_telegraph"):
				arena.add_circle_telegraph(dive_center, DIVE_RADIUS * 0.85, Color(0.6, 0.5, 0.4, 0.4), FX_TIME + RECOVERY_TIME, 2.0, true)
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
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		var d: float = entity.global_position.distance_to(global_position)
		if d < best_dist:
			best = entity
			best_dist = d
	return best

# --- draw: readable oriented silhouette + phase cues (not final art) ---
func _draw() -> void:
	if not alive:
		return
	var f := facing
	var p := Vector2(-f.y, f.x)
	var base := Color(0.34, 0.28, 0.24)
	draw_circle(Vector2(3.0, 4.0), body_radius + 4.0, VisualGrammar.shadow_color(0.6))
	# Broad wings.
	draw_colored_polygon(PackedVector2Array([p * body_radius * 1.8, f * body_radius * 0.4 + p * body_radius * 0.3, -f * body_radius * 0.4 + p * body_radius * 0.4]), base.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([-p * body_radius * 1.8, f * body_radius * 0.4 - p * body_radius * 0.3, -f * body_radius * 0.4 - p * body_radius * 0.4]), base.darkened(0.08))
	draw_circle(Vector2.ZERO, body_radius, base)
	# Hooked beak.
	var beak_tip := f * (body_radius + 20.0)
	draw_colored_polygon(PackedVector2Array([f * body_radius + p * 8.0, f * body_radius - p * 8.0, beak_tip]), Color(0.85, 0.72, 0.4))
	draw_circle(f * body_radius * 0.3 + p * body_radius * 0.45, 3.0, Color(0.95, 0.9, 0.5))
	draw_circle(f * body_radius * 0.3 - p * body_radius * 0.45, 3.0, Color(0.95, 0.9, 0.5))
	if phase == "tel":
		draw_arc(dive_center - global_position, DIVE_RADIUS, 0.0, TAU, 28, Color(0.86, 0.62, 0.32, 0.7), 2.5)
	if is_weakpoint_open():
		var pulse := 0.6 + 0.4 * sin(anim_time * 9.0)
		draw_arc(p * body_radius * 1.2, body_radius * 0.5, 0.0, TAU, 20, Color(0.4, 1.0, 0.85, 0.9 * pulse), 2.5)
		draw_arc(-p * body_radius * 1.2, body_radius * 0.5, 0.0, TAU, 20, Color(0.4, 1.0, 0.85, 0.9 * pulse), 2.5)
	draw_arc(Vector2.ZERO, body_radius + 7.0, 0.0, TAU, 44, Color(1.0, 0.72, 0.3, 0.85), 3.0)
	_draw_health_bar()

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var width := maxf(body_radius * 2.2, 40.0)
	var y := -body_radius - 14.0
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 5.0)), Color(0.05, 0.03, 0.02, 0.85))
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 5.0)), Color(0.95, 0.72, 0.32, 0.95))
