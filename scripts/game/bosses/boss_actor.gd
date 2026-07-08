extends Node2D
## Shared boss framework (BB-BOSS-6), extracted from the Champsosaurus + Teratornis
## prototypes. A neutral (team -1) leashed-or-roaming attacker that mirrors the
## WildlifeEncounter defeat interface so it plugs into arena.on_wildlife_defeated -> the
## claim window. Concrete families are thin subclasses overriding _configure() tuning and a
## few attack/draw hooks. Deterministic: delta timers, no Input, no RNG.
##
## Attack grammar: TEL_warning -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint.

const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

# Center big bosses are the same family actor scaled up and unleashed (map-wide).
const CENTER_SIZE_MULT := 1.5
const CENTER_HEALTH_MULT := 2.0

const FAMILY_PROFILES := {
	"champsosaurus": {
		"label": "Champsosaurus",
		"attack": "Jaw Gate",
		"max_health": 260.0,
		"body_radius": 24.0,
		"move_speed": 62.0,
		"aggro_range": 190.0,
		"attack_reach": 40.0,
		"attack_radius": 34.0,
		"attack_damage": 40.0,
		"weakpoint_mult": 1.6,
		"tel_time": 0.7,
		"hit_time": 0.12,
		"fx_time": 0.4,
		"recovery_time": 1.0,
		"attack_cooldown": 1.2,
		"body_color": Color(0.30, 0.42, 0.30),
		"tel_color": Color(0.95, 0.86, 0.32, 0.9),
		"fx_color": Color(0.42, 0.55, 0.6, 0.4)
	},
	"platyhystrix": {
		"label": "Platyhystrix",
		"attack": "Spore Ward Burst",
		"max_health": 280.0,
		"body_radius": 25.0,
		"move_speed": 48.0,
		"aggro_range": 175.0,
		"attack_reach": 36.0,
		"attack_radius": 42.0,
		"attack_damage": 34.0,
		"weakpoint_mult": 1.5,
		"tel_time": 0.75,
		"hit_time": 0.14,
		"fx_time": 0.55,
		"recovery_time": 1.1,
		"attack_cooldown": 1.35,
		"body_color": Color(0.36, 0.48, 0.26),
		"tel_color": Color(0.76, 0.92, 0.35, 0.9),
		"fx_color": Color(0.42, 0.66, 0.32, 0.36)
	},
	"american_mastodon": {
		"label": "American Mastodon",
		"attack": "Trample Shock",
		"max_health": 380.0,
		"body_radius": 31.0,
		"move_speed": 42.0,
		"aggro_range": 165.0,
		"attack_reach": 45.0,
		"attack_radius": 48.0,
		"attack_damage": 44.0,
		"weakpoint_mult": 1.45,
		"tel_time": 0.85,
		"hit_time": 0.16,
		"fx_time": 0.45,
		"recovery_time": 1.25,
		"attack_cooldown": 1.5,
		"body_color": Color(0.46, 0.39, 0.31),
		"tel_color": Color(0.95, 0.69, 0.34, 0.9),
		"fx_color": Color(0.55, 0.45, 0.34, 0.38)
	},
	"arthropleura": {
		"label": "Arthropleura",
		"attack": "Segment Sweep",
		"max_health": 300.0,
		"body_radius": 26.0,
		"move_speed": 56.0,
		"aggro_range": 185.0,
		"attack_reach": 42.0,
		"attack_radius": 40.0,
		"attack_damage": 36.0,
		"weakpoint_mult": 1.55,
		"tel_time": 0.7,
		"hit_time": 0.14,
		"fx_time": 0.5,
		"recovery_time": 1.05,
		"attack_cooldown": 1.25,
		"body_color": Color(0.34, 0.29, 0.22),
		"tel_color": Color(0.88, 0.78, 0.36, 0.9),
		"fx_color": Color(0.34, 0.42, 0.28, 0.38)
	},
	"teratornis": {
		"label": "Teratornis",
		"attack": "Grand Hunt Shadow",
		"max_health": 260.0,
		"body_radius": 24.0,
		"move_speed": 54.0,
		"aggro_range": 190.0,
		"attack_reach": 70.0,
		"attack_radius": 60.0,
		"attack_damage": 40.0,
		"weakpoint_mult": 1.6,
		"tel_time": 0.9,
		"hit_time": 0.14,
		"fx_time": 0.5,
		"recovery_time": 1.2,
		"attack_cooldown": 1.6,
		"body_color": Color(0.34, 0.28, 0.24),
		"tel_color": Color(0.86, 0.62, 0.32, 0.9),
		"fx_color": Color(0.6, 0.5, 0.4, 0.4)
	}
}

# --- Tuning (subclasses override in _configure()) ---
var max_health := 260.0
var body_radius := 24.0
var move_speed := 62.0
var aggro_range := 190.0
var attack_reach := 40.0
var attack_radius := 34.0
var attack_damage := 40.0
var weakpoint_mult := 1.6
var tel_time := 0.7
var hit_time := 0.12
var fx_time := 0.4
var recovery_time := 1.0
var attack_cooldown_time := 1.2
var uses_leash := true
var leash_margin := 28.0
var middle_reach := 150.0
var body_color := Color(0.30, 0.42, 0.30)
var tel_color := Color(0.95, 0.86, 0.32, 0.9)
var fx_color := Color(0.42, 0.55, 0.6, 0.4)
var attack_name := "Area"

# --- State ---
var arena: Node = null
var team := -1
var zone_id := ""
var zone_side := ""
var species_id := ""
var actor_name := "Boss"
var boss := true
var center_boss := false
var boss_family := ""
var health := 260.0
var alive := true
var home_center := Vector2.ZERO
var leash_rect := Rect2()
var facing := Vector2.RIGHT
var phase := "idle"                    # idle | tel | hit | fx | recovery
var phase_timer := 0.0
var attack_cooldown := 0.0
var attack_center := Vector2.ZERO
var anim_time := 0.0

func setup(next_arena, zone: Dictionary, next_species_id: String, spawn_position: Vector2, index := 0) -> void:
	arena = next_arena
	zone_id = String(zone.get("id", ""))
	zone_side = String(zone.get("side", "neutral"))
	species_id = next_species_id
	boss_family = String(zone.get("boss_family", boss_family))
	center_boss = bool(zone.get("center_boss", false))
	_configure()
	_apply_center_mode()
	health = max_health
	home_center = zone.get("center", spawn_position)
	facing = Vector2.LEFT if zone_side == "red" else Vector2.RIGHT
	_setup_leash(zone)
	global_position = spawn_position
	z_index = 6
	_on_spawn(zone, index)
	queue_redraw()

# --- Overridable hooks (defaults reproduce the Champsosaurus "Jaw Gate" behavior) ---
func _configure() -> void:
	_apply_family_profile(boss_family)

func _apply_family_profile(family: String) -> void:
	var profile: Dictionary = FAMILY_PROFILES.get(family, FAMILY_PROFILES["champsosaurus"])
	actor_name = String(profile.get("label", family.capitalize()))
	attack_name = String(profile.get("attack", attack_name))
	max_health = float(profile.get("max_health", max_health))
	body_radius = float(profile.get("body_radius", body_radius))
	move_speed = float(profile.get("move_speed", move_speed))
	aggro_range = float(profile.get("aggro_range", aggro_range))
	attack_reach = float(profile.get("attack_reach", attack_reach))
	attack_radius = float(profile.get("attack_radius", attack_radius))
	attack_damage = float(profile.get("attack_damage", attack_damage))
	weakpoint_mult = float(profile.get("weakpoint_mult", weakpoint_mult))
	tel_time = float(profile.get("tel_time", tel_time))
	hit_time = float(profile.get("hit_time", hit_time))
	fx_time = float(profile.get("fx_time", fx_time))
	recovery_time = float(profile.get("recovery_time", recovery_time))
	attack_cooldown_time = float(profile.get("attack_cooldown", attack_cooldown_time))
	body_color = profile.get("body_color", body_color)
	tel_color = profile.get("tel_color", tel_color)
	fx_color = profile.get("fx_color", fx_color)

func _apply_center_mode() -> void:
	if not center_boss:
		return
	uses_leash = false
	max_health *= CENTER_HEALTH_MULT
	body_radius *= CENTER_SIZE_MULT
	attack_radius *= CENTER_SIZE_MULT
	attack_damage *= 1.15
	aggro_range = 100000.0
	z_index = maxi(z_index, 7)

func _on_spawn(_zone: Dictionary, _index: int) -> void:
	pass

func _compute_attack_center(target: Node) -> Vector2:
	if target != null and is_instance_valid(target):
		facing = _facing_toward(target.global_position)
	return global_position + facing * (attack_reach + body_radius)

func _on_attack_telegraph() -> void:
	if arena == null or not is_instance_valid(arena):
		return
	if arena.has_method("add_circle_telegraph"):
		arena.add_circle_telegraph(attack_center, attack_radius, tel_color, tel_time, 3.0, false)
	if arena.has_method("add_line_telegraph"):
		arena.add_line_telegraph(global_position, attack_center, Color(tel_color.r, tel_color.g, tel_color.b, 0.7), tel_time, 3.0)

func _on_attack_hit() -> void:
	if arena != null and is_instance_valid(arena) and arena.has_method("damage_creatures_in_radius"):
		arena.damage_creatures_in_radius(team, attack_center, attack_radius, attack_damage, self, attack_name)

func _on_attack_fx() -> void:
	if arena != null and is_instance_valid(arena) and arena.has_method("add_circle_telegraph"):
		arena.add_circle_telegraph(attack_center, attack_radius * 0.9, fx_color, fx_time + recovery_time, 2.0, true)

func _draw_body() -> void:
	match boss_family:
		"platyhystrix":
			_draw_platyhystrix_body()
			return
		"american_mastodon":
			_draw_mastodon_body()
			return
		"arthropleura":
			_draw_arthropleura_body()
			return
	var f := facing
	var p := Vector2(-f.y, f.x)
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_circle(-f * body_radius * 0.6, body_radius * 0.7, body_color.darkened(0.05))
	var snout_l := f * body_radius + p * (body_radius * 0.28)
	var snout_r := f * body_radius - p * (body_radius * 0.28)
	var snout_tip := f * (body_radius + 22.0)
	draw_colored_polygon(PackedVector2Array([snout_l, snout_r, snout_tip]), body_color.lightened(0.06))

func _draw_platyhystrix_body() -> void:
	var f := facing
	var p := Vector2(-f.y, f.x)
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_circle(-f * body_radius * 0.45, body_radius * 0.72, body_color.darkened(0.08))
	for i in range(4):
		var t := -0.55 + float(i) * 0.32
		var base := f * body_radius * t
		draw_colored_polygon(PackedVector2Array([
			base + p * body_radius * 0.4,
			base - p * body_radius * 0.4,
			base + p * body_radius * 0.08 - f * body_radius * 0.18
		]), body_color.lightened(0.14))

func _draw_mastodon_body() -> void:
	var f := facing
	var p := Vector2(-f.y, f.x)
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_circle(-f * body_radius * 0.65, body_radius * 0.78, body_color.darkened(0.06))
	draw_circle(f * body_radius * 0.72, body_radius * 0.52, body_color.lightened(0.04))
	draw_line(f * body_radius * 1.0 + p * body_radius * 0.16, f * body_radius * 1.28 + p * body_radius * 0.42, Color(0.86, 0.8, 0.64), 3.0)
	draw_line(f * body_radius * 1.0 - p * body_radius * 0.16, f * body_radius * 1.28 - p * body_radius * 0.42, Color(0.86, 0.8, 0.64), 3.0)

func _draw_arthropleura_body() -> void:
	var f := facing
	var p := Vector2(-f.y, f.x)
	for i in range(4):
		var offset := f * ((float(i) - 1.5) * body_radius * 0.52)
		var r := body_radius * (0.72 if i == 1 or i == 2 else 0.62)
		draw_circle(offset, r, body_color.lightened(0.04 * i))
		draw_line(offset + p * r * 0.65, offset - p * r * 0.65, body_color.darkened(0.12), 2.0)

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
	return center_boss

func is_weakpoint_open() -> bool:
	return phase == "recovery"

func get_actor_name() -> String:
	return actor_name

func take_damage(amount: float, _source_team := -1, source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, source_actor, boss_family)
	take_damage_event(event)

func take_damage_event(event: Resource) -> void:
	if not alive:
		return
	var amount := maxf(float(event.amount), 0.0)
	if is_weakpoint_open():
		amount *= weakpoint_mult
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
		if dist <= attack_reach + body_radius and attack_cooldown <= 0.0:
			_start_attack(target)
		elif dist > attack_reach:
			global_position = _clamp_to_leash(global_position + facing * move_speed * delta)
	elif uses_leash and not leash_rect.has_point(global_position):
		var home_dir := home_center - global_position
		if home_dir.length() > 0.001:
			global_position = _clamp_to_leash(global_position + home_dir.normalized() * move_speed * delta)
	elif not uses_leash:
		var home_dir := home_center - global_position
		if home_dir.length() > 1.0:
			global_position += home_dir.normalized() * move_speed * delta

func _start_attack(target: Node) -> void:
	phase = "tel"
	phase_timer = tel_time
	attack_center = _compute_attack_center(target)
	_on_attack_telegraph()

func _advance_attack(delta: float) -> void:
	phase_timer -= delta
	if phase_timer > 0.0:
		return
	match phase:
		"tel":
			phase = "hit"
			phase_timer = hit_time
			_on_attack_hit()
		"hit":
			phase = "fx"
			phase_timer = fx_time
			_on_attack_fx()
		"fx":
			phase = "recovery"
			phase_timer = recovery_time
		"recovery":
			phase = "idle"
			attack_cooldown = attack_cooldown_time

func _find_target() -> Node:
	if arena == null or not is_instance_valid(arena) or not ("entities" in arena):
		return null
	var best: Node = null
	var best_dist := aggro_range
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
		var point: Vector2 = entity.global_position
		if uses_leash and not leash_rect.has_point(point):
			continue
		var d := point.distance_to(global_position)
		if d < best_dist:
			best = entity
			best_dist = d
	return best

func _facing_toward(point: Vector2) -> Vector2:
	var to := point - global_position
	return to.normalized() if to.length() > 0.001 else facing

func _setup_leash(zone: Dictionary) -> void:
	if not uses_leash:
		leash_rect = Rect2(Vector2(-100000.0, -100000.0), Vector2(200000.0, 200000.0))
		return
	var radius: Vector2 = zone.get("radius", Vector2(120.0, 96.0))
	var min_y := home_center.y - radius.y - leash_margin
	var max_y := home_center.y + radius.y + leash_margin
	var min_x: float
	var max_x: float
	if zone_side == "red":
		min_x = -middle_reach
		max_x = home_center.x + radius.x + leash_margin
	else:
		min_x = home_center.x - radius.x - leash_margin
		max_x = middle_reach
	leash_rect = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	if arena != null and is_instance_valid(arena):
		leash_rect = leash_rect.intersection(arena.ARENA_RECT)

func _clamp_to_leash(p: Vector2) -> Vector2:
	if not uses_leash:
		return p
	return Vector2(
		clampf(p.x, leash_rect.position.x, leash_rect.end.x),
		clampf(p.y, leash_rect.position.y, leash_rect.end.y)
	)

func within_leash(point: Vector2) -> bool:
	return leash_rect.has_point(point)

# --- draw: readable silhouette + phase cues (not final art) ---
func _draw() -> void:
	if not alive:
		return
	draw_circle(Vector2(2.0, 3.0), body_radius + 3.0, VisualGrammar.shadow_color(0.62))
	_draw_body()
	if phase == "tel":
		_draw_telegraph_cue()
	if is_weakpoint_open():
		_draw_weakpoint_cue()
	draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 40, Color(1.0, 0.76, 0.28, 0.85), 3.0)
	_draw_health_bar()

func _draw_telegraph_cue() -> void:
	draw_arc(attack_center - global_position, attack_radius, 0.0, TAU, 28, Color(tel_color.r, tel_color.g, tel_color.b, 0.7), 2.5)

func _draw_weakpoint_cue() -> void:
	var pulse := 0.6 + 0.4 * sin(anim_time * 10.0)
	draw_circle(Vector2.ZERO, body_radius * 0.42, Color(0.3, 0.9, 0.8, 0.35 * pulse))
	draw_arc(Vector2.ZERO, body_radius * 0.42, 0.0, TAU, 20, Color(0.4, 1.0, 0.85, 0.9), 2.0)

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var width := maxf(body_radius * 2.4, 30.0)
	var y := -body_radius - 12.0
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 4.0)), Color(0.05, 0.03, 0.02, 0.85))
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 4.0)), Color(0.95, 0.72, 0.32, 0.95))
