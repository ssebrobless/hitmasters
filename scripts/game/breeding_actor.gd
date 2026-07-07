extends Node2D

const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

var arena: Node = null
var cue_id := ""
var team := -1
var slot_index := -1
var creature_id := ""
var family := ""
var actor_name := "Breeding animal"
var max_health := 90.0
var health := 90.0
var body_radius := 13.0
var body_capsule_half_len_px := 0.0
var alive := true

func setup(next_arena: Node, cue: Dictionary, spawn_position: Vector2) -> void:
	arena = next_arena
	cue_id = String(cue.get("id", ""))
	team = int(cue.get("team", -1))
	slot_index = int(cue.get("slot_index", -1))
	creature_id = String(cue.get("creature_id", "animal"))
	family = String(cue.get("family", ""))
	actor_name = "%s breeding %s" % [_team_name(), _species_label()]
	max_health = _breeding_health()
	health = max_health
	global_position = spawn_position
	z_index = 7
	queue_redraw()

func is_alive() -> bool:
	return alive

func is_scored_actor() -> bool:
	return false

func is_breeding_actor() -> bool:
	return true

func is_untargetable() -> bool:
	return arena != null and arena.has_method("is_breeding_actor_targetable") and not arena.is_breeding_actor_targetable(self)

func get_actor_name() -> String:
	return actor_name

func take_damage(amount: float, _source_team := -1, source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, source_actor, "breeding")
	take_damage_event(event)

func take_damage_event(event: Resource) -> void:
	if not alive:
		return
	if arena != null and arena.has_method("can_damage_breeding_actor") and not arena.can_damage_breeding_actor(self, event.source_actor):
		if arena.has_method("show_breeding_actor_shielded"):
			arena.show_breeding_actor_shielded(self, event.source_actor)
		return
	var amount := maxf(float(event.amount), 0.0)
	health = maxf(health - amount, 0.0)
	_emit_hit_event(event, amount)
	queue_redraw()
	if health <= 0.0:
		_die(event.source_actor)

func _die(source_actor: Node = null) -> void:
	alive = false
	visible = false
	if arena != null and is_instance_valid(arena) and arena.has_method("on_breeding_actor_defeated"):
		arena.on_breeding_actor_defeated(self, source_actor)
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

func _draw() -> void:
	if not alive:
		return
	var base := _family_color()
	var targetable := not is_untargetable()
	var alpha := 0.92 if targetable else 0.48
	draw_circle(Vector2(1.5, 2.0), body_radius + 4.0, VisualGrammar.shadow_color(0.55))
	draw_circle(Vector2.ZERO, body_radius + 3.0, Color(base.r, base.g, base.b, 0.16 if targetable else 0.08))
	draw_circle(Vector2.ZERO, body_radius, Color(base.r, base.g, base.b, alpha))
	draw_circle(Vector2(body_radius * 0.32, -body_radius * 0.22), body_radius * 0.46, Color(base.r, base.g, base.b, minf(alpha + 0.08, 1.0)).lightened(0.14))
	draw_arc(Vector2.ZERO, body_radius + 5.0, 0.0, TAU, 32, Color(1.0, 0.78, 0.28, 0.88 if targetable else 0.36), 2.5)
	if not targetable:
		draw_arc(Vector2.ZERO, body_radius + 8.0, PI * 0.15, PI * 1.85, 24, Color(0.52, 0.82, 1.0, 0.35), 2.0)
	_draw_health_bar()

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var width := maxf(body_radius * 2.4, 26.0)
	var y := -body_radius - 10.0
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 3.0)), Color(0.05, 0.03, 0.025, 0.82))
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 3.0)), Color(0.95, 0.72, 0.32, 0.95))

func _team_name() -> String:
	return "Blue" if team == 0 else "Red"

func _species_label() -> String:
	return creature_id.replace("_", " ").capitalize()

func _breeding_health() -> float:
	match family:
		"reptile":
			return 115.0
		"mammal":
			return 96.0
		"bird":
			return 84.0
		"crawly":
			return 72.0
		_:
			return 88.0

func _family_color() -> Color:
	return VisualGrammar.family_color(family)
