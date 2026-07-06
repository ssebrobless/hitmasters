extends Node2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const TRIGGER_RADIUS_UNITS := 0.9

var arena: Node = null
var source_actor: Node = null
var owner_kit: RefCounted = null
var team := 0
var body_radius := TRIGGER_RADIUS_UNITS * SimConstants.UNIT_PX
var retired := false

func setup(mine_arena: Node, source_actor: Node, kit: RefCounted, mine_position: Vector2) -> void:
	arena = mine_arena
	self.source_actor = source_actor
	owner_kit = kit
	team = int(source_actor.team)
	global_position = mine_position

func _physics_process(_delta: float) -> void:
	if retired:
		return
	if source_actor == null or not is_instance_valid(source_actor):
		retire()
		return
	if arena != null:
		for entity in arena.entities:
			if not TargetFilter.is_live_damage_target(source_actor, entity, {"require_damage_api": false}):
				continue
			if entity.global_position.distance_to(global_position) <= body_radius + entity.body_radius:
				if owner_kit != null and owner_kit.has_method("spawn_glowworm_field"):
					owner_kit.spawn_glowworm_field(source_actor, global_position)
				retire()
				return
	queue_redraw()

func is_alive() -> bool:
	return not retired

func retire() -> void:
	if retired:
		return
	retired = true
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.1, 0.08, 0.03, 0.9))
	draw_circle(Vector2.ZERO, 3.0, Color(0.95, 0.9, 0.25, 0.9))
