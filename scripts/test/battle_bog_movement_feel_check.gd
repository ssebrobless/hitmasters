extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("movement feel check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null:
		push_error("movement feel check missing arena/player")
		quit(1)
		return

	_check_profile_ramp(arena, failures)
	_check_turn_inertia(arena, failures)
	_check_dash_bypass(arena, failures)
	_check_render_profile_keys(arena, failures)

	print("movement_feel failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_profile_ramp(arena: Node, failures: Array[String]) -> void:
	var bullfrog: Node = arena.player
	bullfrog.apply_creature("bullfrog")
	bullfrog.global_position = Vector2(200.0, 200.0)
	bullfrog.velocity = Vector2.ZERO
	var shrew: Node = arena.bots[0]
	shrew.apply_creature("water_shrew")
	shrew.global_position = Vector2(260.0, 200.0)
	shrew.velocity = Vector2.ZERO
	var frame := _move_frame(Vector2.RIGHT)
	bullfrog.set_input_frame(frame)
	shrew.set_input_frame(frame)
	bullfrog.tick_sim(1.0 / 60.0)
	shrew.tick_sim(1.0 / 60.0)
	var bullfrog_ratio: float = bullfrog.velocity.length() / bullfrog.get_speed_px()
	var shrew_ratio: float = shrew.velocity.length() / shrew.get_speed_px()
	if not (bullfrog_ratio > 0.05 and bullfrog_ratio < 0.6 and shrew_ratio > bullfrog_ratio + 0.2):
		failures.append("movement profiles should create distinct first-step acceleration; bullfrog=%.3f shrew=%.3f" % [bullfrog_ratio, shrew_ratio])

func _check_turn_inertia(arena: Node, failures: Array[String]) -> void:
	var turtle: Node = arena.player
	turtle.apply_creature("snapping_turtle")
	turtle.global_position = Vector2(300.0, 300.0)
	turtle.velocity = Vector2.ZERO
	turtle.set_input_frame(_move_frame(Vector2.RIGHT))
	for i in 18:
		turtle.tick_sim(1.0 / 60.0)
	turtle.set_input_frame(_move_frame(Vector2.UP))
	for i in 6:
		turtle.tick_sim(1.0 / 60.0)
	if not (turtle.velocity.x > 8.0 and turtle.velocity.y < -1.0):
		failures.append("heavy turtle profile should keep forward momentum while beginning a turn; velocity=%s" % str(turtle.velocity))

func _check_dash_bypass(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("bullfrog")
	actor.global_position = Vector2(420.0, 300.0)
	actor.velocity = Vector2.ZERO
	actor.dash_velocity = Vector2.RIGHT * 700.0
	actor.dash_timer = 0.2
	actor.set_input_frame(_move_frame(Vector2.LEFT))
	actor.tick_sim(1.0 / 60.0)
	if actor.velocity.x < 690.0:
		failures.append("dash velocity should bypass movement feel acceleration; velocity=%s" % str(actor.velocity))
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO

func _check_render_profile_keys(arena: Node, failures: Array[String]) -> void:
	var frog: Node = arena.player
	frog.apply_creature("bullfrog")
	var toad: Node = arena.bots[0]
	toad.apply_creature("cane_toad")
	if String(frog.movement_profile.get("gait", "")) != "heavy_hop":
		failures.append("bullfrog should expose heavy_hop gait metadata")
	if not float(toad.movement_profile.get("bob_px", 0.0)) < float(frog.movement_profile.get("bob_px", 0.0)):
		failures.append("cane toad should expose a smaller hop bob than bullfrog")
	if not float(toad.movement_profile.get("hop_leg_scale", 0.0)) < float(frog.movement_profile.get("hop_leg_scale", 0.0)):
		failures.append("cane toad should use shorter hop legs than bullfrog")
	if not float(toad.movement_profile.get("ground_contact", 0.0)) > float(frog.movement_profile.get("ground_contact", 0.0)):
		failures.append("cane toad should keep longer ground contact than bullfrog")
	var crayfish: Node = arena.bots[1]
	crayfish.apply_creature("crayfish")
	if not float(crayfish.movement_profile.get("scuttle_stride", 0.0)) > 1.0:
		failures.append("crayfish should expose a wider scuttle stride")
	var spider: Node = arena.bots[2]
	spider.apply_creature("wolf_spider")
	if not float(spider.movement_profile.get("low_slung", 0.0)) > 0.0:
		failures.append("wolf spider should expose low scuttle posture metadata")
	var firefly: Node = arena.player
	firefly.apply_creature("firefly")
	if not float(firefly.movement_profile.get("glow_breathe", 0.0)) > 0.0:
		failures.append("firefly should expose glow breathing metadata")
	var mosquito: Node = arena.bots[0]
	mosquito.apply_creature("mosquito_swarm")
	if not float(mosquito.movement_profile.get("swarm_jitter", 0.0)) > 0.0:
		failures.append("mosquito swarm should expose swarm jitter metadata")
	var snake: Node = arena.bots[1]
	snake.apply_creature("water_snake")
	if not float(snake.movement_profile.get("slither_amp", 0.0)) > 1.0:
		failures.append("water snake should expose amplified slither metadata")
	var gator: Node = arena.bots[2]
	gator.apply_creature("alligator")
	if not float(gator.movement_profile.get("crawl_weight", 0.0)) > 0.0:
		failures.append("alligator should expose heavy crawl metadata")
	var newt: Node = arena.bots[0]
	newt.apply_creature("newt")
	if not float(newt.movement_profile.get("tail_wave", 0.0)) > 1.0:
		failures.append("newt should expose slick tail-wave metadata")
	var heron: Node = arena.bots[1]
	heron.apply_creature("great_blue_heron")
	if not float(heron.movement_profile.get("bird_stride", 1.0)) < 1.0:
		failures.append("heron should expose patient wading stride metadata")
	var kingfisher: Node = arena.bots[2]
	kingfisher.apply_creature("kingfisher")
	if not float(kingfisher.movement_profile.get("perch_flutter", 1.0)) > 1.0:
		failures.append("kingfisher should expose dart-hover flutter metadata")
	var chorus: Node = arena.bots[0]
	chorus.apply_creature("chorus_frog")
	if not float(chorus.movement_profile.get("gait_rate_mult", 0.0)) > 1.0:
		failures.append("chorus frog should expose light rhythmic hop metadata")
	var duck: Node = arena.bots[1]
	duck.apply_creature("duck")
	if not float(duck.movement_profile.get("waddle_sway", 0.0)) > 0.0:
		failures.append("duck should expose waddle-paddle metadata")
	var beaver: Node = arena.bots[2]
	beaver.apply_creature("beaver")
	if not float(beaver.movement_profile.get("body_wiggle", 1.0)) < 1.0:
		failures.append("beaver should expose builder trundle metadata")
	var mink: Node = arena.bots[0]
	mink.apply_creature("mink")
	if not float(mink.movement_profile.get("body_wiggle", 0.0)) > 1.0:
		failures.append("mink should expose elastic bound metadata")
	var owl: Node = arena.bots[1]
	owl.apply_creature("owl")
	if not float(owl.movement_profile.get("wingbeat_mult", 1.0)) < 1.0:
		failures.append("owl should expose slow silent wingbeat metadata")
	var turtle2: Node = arena.bots[2]
	turtle2.apply_creature("snapping_turtle")
	if not float(turtle2.movement_profile.get("shell_stability", 0.0)) > 0.0:
		failures.append("snapping turtle should expose stable shell metadata")

func _move_frame(direction: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = direction
	frame.aim = Vector2.RIGHT * 100.0
	return frame
