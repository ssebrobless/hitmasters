extends "res://scripts/game/bosses/boss_actor.gd"
## Teratornis boss family (BB-BOSS-5, reframed onto the shared boss_actor base in
## BB-BOSS-6). In center mode it becomes neutral, 50% larger, and map-wide. Grand Hunt
## Shadow reveals creatures of BOTH teams through the BB-VIS-1 vision service before the
## dive lands -- anti-comfort, map-wide readability.

const SIZE_MULT := 1.5
const REVEAL_RADIUS := 260.0
const REVEAL_DURATION := 2.4

func _configure() -> void:
	super._configure()
	z_index = 7

func _compute_attack_center(target: Node) -> Vector2:
	if target != null and is_instance_valid(target):
		facing = _facing_toward(target.global_position)
		return target.global_position
	return global_position + facing * (attack_reach + body_radius)

func _on_attack_telegraph() -> void:
	# Grand Hunt Shadow: reveal creatures in the shadow to BOTH teams before the dive.
	_reveal_creatures_near(attack_center, REVEAL_RADIUS)
	if arena == null or not is_instance_valid(arena):
		return
	if arena.has_method("add_circle_telegraph"):
		arena.add_circle_telegraph(attack_center, attack_radius, tel_color, tel_time, 3.0, false)
		arena.add_circle_telegraph(attack_center, REVEAL_RADIUS, Color(0.55, 0.6, 0.78, 0.28), REVEAL_DURATION, 2.0, true)
	if arena.has_method("add_line_telegraph"):
		arena.add_line_telegraph(global_position, attack_center, Color(tel_color.r, tel_color.g, tel_color.b, 0.65), tel_time, 3.0)

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
		arena.reveal_entity_to_team(entity, 0, REVEAL_DURATION)
		arena.reveal_entity_to_team(entity, 1, REVEAL_DURATION)

func _draw_body() -> void:
	var f := facing
	var p := Vector2(-f.y, f.x)
	# Broad wings.
	draw_colored_polygon(PackedVector2Array([p * body_radius * 1.8, f * body_radius * 0.4 + p * body_radius * 0.3, -f * body_radius * 0.4 + p * body_radius * 0.4]), body_color.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([-p * body_radius * 1.8, f * body_radius * 0.4 - p * body_radius * 0.3, -f * body_radius * 0.4 - p * body_radius * 0.4]), body_color.darkened(0.08))
	draw_circle(Vector2.ZERO, body_radius, body_color)
	# Hooked beak.
	var beak_tip := f * (body_radius + 20.0)
	draw_colored_polygon(PackedVector2Array([f * body_radius + p * 8.0, f * body_radius - p * 8.0, beak_tip]), Color(0.85, 0.72, 0.4))
	draw_circle(f * body_radius * 0.3 + p * body_radius * 0.45, 3.0, Color(0.95, 0.9, 0.5))
	draw_circle(f * body_radius * 0.3 - p * body_radius * 0.45, 3.0, Color(0.95, 0.9, 0.5))

func _draw_weakpoint_cue() -> void:
	var p := Vector2(-facing.y, facing.x)
	var pulse := 0.6 + 0.4 * sin(anim_time * 9.0)
	draw_arc(p * body_radius * 1.2, body_radius * 0.5, 0.0, TAU, 20, Color(0.4, 1.0, 0.85, 0.9 * pulse), 2.5)
	draw_arc(-p * body_radius * 1.2, body_radius * 0.5, 0.0, TAU, 20, Color(0.4, 1.0, 0.85, 0.9 * pulse), 2.5)
