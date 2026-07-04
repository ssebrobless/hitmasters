extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TurtleHook := preload("res://scripts/ai/bot_kit_hooks/snapping_turtle_bot.gd")
const FrogHook := preload("res://scripts/ai/bot_kit_hooks/chorus_frog_bot.gd")
const MinkHook := preload("res://scripts/ai/bot_kit_hooks/mink_bot.gd")
const BeaverHook := preload("res://scripts/ai/bot_kit_hooks/beaver_bot.gd")
const OwlHook := preload("res://scripts/ai/bot_kit_hooks/owl_bot.gd")
const DuckHook := preload("res://scripts/ai/bot_kit_hooks/duck_bot.gd")

var hooks := {}

func build_frame(actor: Node) -> Resource:
	var frame := InputFrameScript.new()
	var target := _choose_target(actor)
	if target == null:
		frame.move = Vector2.ZERO
		frame.aim = actor.global_position + Vector2.RIGHT
		return frame

	var offset: Vector2 = target.global_position - actor.global_position
	var distance := offset.length()
	var direction := offset.normalized()
	frame.aim = target.global_position
	frame.move = direction if distance > _preferred_range(actor) else Vector2(-direction.y, direction.x) * (1.0 if actor.team == 0 else -1.0)
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, distance <= _primary_range(actor))
	_hook(actor).apply(actor, target, frame, distance)
	return frame

func _choose_target(actor: Node) -> Node:
	if actor.arena == null:
		return null
	var enemy: Node = actor.arena.get_closest_enemy(actor, 900.0)
	if enemy != null:
		return enemy
	return actor.arena.get_enemy_core(actor.team)

func _hook(actor: Node) -> RefCounted:
	if hooks.has(actor.creature_id):
		return hooks[actor.creature_id]
	var hook: RefCounted
	match actor.creature_id:
		"snapping_turtle":
			hook = TurtleHook.new()
		"chorus_frog":
			hook = FrogHook.new()
		"mink":
			hook = MinkHook.new()
		"beaver":
			hook = BeaverHook.new()
		"owl":
			hook = OwlHook.new()
		"duck":
			hook = DuckHook.new()
		_:
			hook = FrogHook.new()
	hooks[actor.creature_id] = hook
	return hook

func _preferred_range(actor: Node) -> float:
	match actor.creature_id:
		"chorus_frog":
			return 46.0
		"snapping_turtle":
			return 24.0
		"mink":
			return 18.0
		"beaver":
			return 22.0
		"owl":
			return 60.0
		"duck":
			return 20.0
		_:
			return 32.0

func _primary_range(actor: Node) -> float:
	return _preferred_range(actor) + actor.body_radius * 1.5
