extends Node2D

const Hurtbox := preload("res://scripts/sim/combat/hurtbox.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

var arena: Node = null
var source_actor: Node = null
var source_kit: RefCounted = null
var team := 0
var velocity := Vector2.RIGHT
var speed := 150.0
var radius := 5.0
var remaining_range_px := 0.0
var retired := false

func setup(projectile_arena: Node, actor: Node, kit: RefCounted, start_position: Vector2, direction: Vector2, range_px: float) -> void:
	arena = projectile_arena
	source_actor = actor
	source_kit = kit
	team = int(actor.team)
	global_position = start_position
	velocity = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	remaining_range_px = range_px

func _physics_process(delta: float) -> void:
	if retired:
		return
	if source_actor == null or not is_instance_valid(source_actor):
		retire()
		return
	var step := velocity * speed * delta
	global_position += step
	remaining_range_px -= step.length()
	if _hit_enemy() or remaining_range_px <= 0.0:
		_expand()
	queue_redraw()

func _hit_enemy() -> bool:
	if arena == null:
		return false
	for entity in arena.entities:
		if not TargetFilter.is_live_damage_target(source_actor, entity, {"require_damage_api": false}):
			continue
		if Hurtbox.overlaps_circle(Hurtbox.hull_of(entity), global_position, radius):
			return true
	return false

func _expand() -> void:
	if source_kit != null and source_kit.has_method("spawn_mosquito_field"):
		source_kit.spawn_mosquito_field(source_actor, global_position, 3.0)
	retire()

func is_alive() -> bool:
	return not retired

func retire() -> void:
	if retired:
		return
	retired = true
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0.12, 0.12, 0.14, 0.55))
	draw_circle(Vector2.ZERO, radius, Color(0.45, 0.45, 0.48, 0.9))
