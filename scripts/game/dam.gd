extends Node2D

# Beaver dam: a placeable wall. Registered as an arena entity so enemy melee
# and projectiles damage it; its rect blocks body movement (not projectiles
# or LOS — those stop by hitting it as an entity).

var arena: Node = null
var team := 0
var max_health := 200.0
var health := 200.0
var rect := Rect2()
var body_radius := 24.0

func setup(dam_arena: Node, dam_team: int, dam_rect: Rect2, dam_health: float) -> void:
	arena = dam_arena
	team = dam_team
	rect = dam_rect
	max_health = dam_health
	health = dam_health
	global_position = rect.get_center()
	body_radius = rect.size.length() * 0.5

func is_alive() -> bool:
	return health > 0.0

func is_scored_actor() -> bool:
	return false

func get_actor_name() -> String:
	return "Dam"

func repair(amount: float) -> void:
	health = minf(health + amount, max_health)
	queue_redraw()

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	health -= amount
	queue_redraw()
	if health <= 0.0:
		_collapse()

func take_damage_event(event: Resource) -> void:
	take_damage(event.amount, -1, event.source_actor)

func _collapse() -> void:
	if arena != null:
		arena.unregister_entity(self)
		if arena.has_method("unregister_dam"):
			arena.unregister_dam(self)
	queue_free()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var local := Rect2(rect.position - global_position, rect.size)
	var wood := Color(0.4, 0.28, 0.14)
	var wood_dark := Color(0.26, 0.18, 0.09)
	draw_rect(local.grow(2.0), wood_dark)
	draw_rect(local, wood)
	# Cross-laid stick texture.
	var along_x := local.size.x >= local.size.y
	var step := 9.0
	if along_x:
		var x := local.position.x + 4.0
		while x < local.end.x - 2.0:
			draw_line(Vector2(x, local.position.y + 2.0), Vector2(x + 6.0, local.end.y - 2.0), wood_dark, 2.0)
			x += step
	else:
		var y := local.position.y + 4.0
		while y < local.end.y - 2.0:
			draw_line(Vector2(local.position.x + 2.0, y), Vector2(local.end.x - 2.0, y + 6.0), wood_dark, 2.0)
			y += step
	# Health bar.
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(local.position + Vector2(0.0, -7.0), Vector2(local.size.x, 4.0)), Color(0.07, 0.07, 0.08))
	draw_rect(Rect2(local.position + Vector2(0.0, -7.0), Vector2(local.size.x * ratio, 4.0)), Color(0.75, 0.6, 0.3))
