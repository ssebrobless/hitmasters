extends Node2D
class_name Projectile

const VisualStyle := preload("res://scripts/visual/visual_style.gd")

var arena: Node = null
var team := 0
var velocity := Vector2.RIGHT
var speed := 760.0
var damage := 10.0
var radius := 7.0
var lifetime := 1.6
var pierce := false
var hit_entities: Array[Node] = []
var color := Color.WHITE
var previous_position := Vector2.ZERO
var source_actor: Node = null

func setup(projectile_arena: Node, projectile_team: int, start_position: Vector2, direction: Vector2, projectile_damage: float, projectile_speed: float, projectile_color: Color, does_pierce := false, projectile_radius := 7.0, projectile_lifetime := 1.6, projectile_source_actor: Node = null) -> void:
	arena = projectile_arena
	team = projectile_team
	position = start_position
	previous_position = start_position
	velocity = direction.normalized()
	rotation = velocity.angle()
	damage = projectile_damage
	speed = projectile_speed
	color = projectile_color
	pierce = does_pierce
	radius = projectile_radius
	lifetime = projectile_lifetime
	source_actor = projectile_source_actor

func _physics_process(delta: float) -> void:
	previous_position = position
	position += velocity * speed * delta
	lifetime -= delta

	if arena != null:
		arena.resolve_projectile_hits(self)
		if not arena.is_inside_arena(position):
			queue_free()

	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	VisualStyle.draw_pixel_projectile(self, color, radius)
