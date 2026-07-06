extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const MovementFeelScript := preload("res://scripts/sim/movement_feel.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")

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
	_check_capsule_body_heading(arena, failures)
	_check_directional_scuttle(arena, failures)
	_check_dash_bypass(arena, failures)
	_check_dash_residual_bleed(arena, failures)
	_check_render_profile_keys(arena, failures)
	_check_landing_tell(arena, failures)
	_check_water_profile_overlay(arena, failures)
	_check_wave4_profile_seeds(failures)
	_check_render_state_flags(arena, failures)

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

func _check_capsule_body_heading(arena: Node, failures: Array[String]) -> void:
	var gator: Node = arena.player
	gator.apply_creature("alligator")
	gator.global_position = Vector2.ZERO
	gator.velocity = Vector2.ZERO
	gator.last_aim_direction = Vector2.RIGHT
	gator.body_heading = Vector2.RIGHT
	gator.set_input_frame(_aim_frame(Vector2.LEFT))
	for i in 6:
		gator.tick_sim(1.0 / 60.0)
	var gator_lagged: bool = gator.last_aim_direction.dot(Vector2.LEFT) > 0.99 and gator.body_heading.dot(Vector2.RIGHT) > 0.75
	var frog: Node = arena.bots[0]
	frog.apply_creature("bullfrog")
	frog.global_position = Vector2.ZERO
	frog.velocity = Vector2.ZERO
	frog.last_aim_direction = Vector2.RIGHT
	frog.body_heading = Vector2.RIGHT
	frog.set_input_frame(_aim_frame(Vector2.LEFT))
	frog.tick_sim(1.0 / 60.0)
	var circle_snapped: bool = frog.body_heading.dot(Vector2.LEFT) > 0.99
	if not gator_lagged or not circle_snapped:
		failures.append("capsule body heading should lag aim flips while circles snap; gator_aim=%s gator_body=%s frog_body=%s" % [
			str(gator.last_aim_direction),
			str(gator.body_heading),
			str(frog.body_heading)
		])

func _check_directional_scuttle(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var forward_speed := _one_tick_velocity(actor, "crayfish", Vector2.RIGHT)
	var lateral_speed := _one_tick_velocity(actor, "crayfish", Vector2.UP)
	var backward_speed := _one_tick_velocity(actor, "crayfish", Vector2.LEFT)
	var frog_lateral := _one_tick_velocity(actor, "bullfrog", Vector2.UP)
	if not (lateral_speed > forward_speed * 1.3 and backward_speed > lateral_speed * 1.05 and lateral_speed > frog_lateral * 2.0):
		failures.append("crayfish should scuttle laterally and snap backward relative to facing; forward=%.2f lateral=%.2f backward=%.2f frog_lateral=%.2f" % [
			forward_speed,
			lateral_speed,
			backward_speed,
			frog_lateral
		])

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

func _check_dash_residual_bleed(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("bullfrog")
	actor.global_position = Vector2(420.0, 300.0)
	actor.velocity = Vector2.ZERO
	actor.residual_velocity = Vector2.ZERO
	actor.dash_velocity = Vector2.RIGHT * 600.0
	actor.dash_timer = 1.0 / 60.0
	actor.set_input_frame(_move_frame(Vector2.LEFT))
	actor.tick_sim(1.0 / 60.0)
	var captured: bool = actor.dash_timer <= 0.0 and actor.dash_velocity == Vector2.ZERO and actor.residual_velocity.x > 590.0 and actor.velocity.x > 550.0
	var first_residual: float = actor.residual_velocity.length()
	actor.tick_sim(1.0 / 60.0)
	var decayed_once: bool = actor.residual_velocity.length() < first_residual * 0.70 and actor.residual_velocity.length() > first_residual * 0.65
	var moving_after_dash: bool = actor.velocity.x > 250.0
	if not captured or not decayed_once or not moving_after_dash:
		failures.append("dash residual should capture on expiry and decay deterministically; captured=%s decayed=%s moving=%s residual=%.2f velocity=%s" % [
			str(captured),
			str(decayed_once),
			str(moving_after_dash),
			actor.residual_velocity.length(),
			str(actor.velocity)
		])
	actor.residual_velocity = Vector2.ZERO

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
	if not float(frog.movement_profile.get("landing_thump", 0.0)) > float(toad.movement_profile.get("landing_thump", 0.0)):
		failures.append("bullfrog should expose heavier landing thump metadata than cane toad")
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

func _check_landing_tell(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("bullfrog")
	actor.global_position = Vector2.ZERO
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	actor.render_landing_timer = 0.0
	actor.render_landing_impact = 0.0
	actor.render_last_hop_airborne = true
	actor.anim_walk_phase = PI
	actor._process(1.0 / 60.0)
	var landing_state: Dictionary = actor.get_render_motion_state()
	var triggered: bool = float(landing_state.get("landing_t", 0.0)) > 0.85 and absf(float(landing_state.get("landing_impact", 0.0)) - 1.0) < 0.001
	actor._process(0.08)
	var decayed_state: Dictionary = actor.get_render_motion_state()
	var decayed: bool = float(decayed_state.get("landing_t", 1.0)) < float(landing_state.get("landing_t", 0.0))
	actor.apply_creature("water_shrew")
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.render_last_hop_airborne = true
	actor.anim_walk_phase = PI
	actor._process(1.0 / 60.0)
	var shrew_state: Dictionary = actor.get_render_motion_state()
	var gated: bool = float(shrew_state.get("landing_t", 0.0)) <= 0.001 and float(shrew_state.get("landing_impact", 0.0)) <= 0.001
	if not triggered or not decayed or not gated:
		failures.append("hop landing tell should trigger/decay for bullfrog and stay gated for non-hop profiles; triggered=%s decayed=%s gated=%s states=%s/%s/%s" % [
			str(triggered),
			str(decayed),
			str(gated),
			str(landing_state),
			str(decayed_state),
			str(shrew_state)
		])

func _check_water_profile_overlay(arena: Node, failures: Array[String]) -> void:
	var turtle: Node = arena.player
	turtle.apply_creature("snapping_turtle")
	var land_profile: Dictionary = turtle.movement_profile
	var water_profile: Dictionary = MovementFeelScript.profile_for_surface(land_profile, "water")
	if not float(water_profile.get("accel_time", 0.0)) < float(land_profile.get("accel_time", 0.0)):
		failures.append("snapping turtle should accelerate more smoothly in water; land=%s water=%s" % [str(land_profile), str(water_profile)])
	if not float(water_profile.get("turtle_stride", 0.0)) > float(land_profile.get("turtle_stride", 0.0)):
		failures.append("snapping turtle water overlay should paddle more than land creep")
	var beaver_profile: Dictionary = MovementFeelScript.profile_for("beaver")
	var beaver_water: Dictionary = MovementFeelScript.profile_for_surface(beaver_profile, "water")
	if not float(beaver_water.get("tail_wave", 0.0)) > float(beaver_profile.get("tail_wave", 0.0)):
		failures.append("beaver water overlay should emphasize tail-rudder motion")
	turtle.current_environment_profile = {"surface": "water"}
	if not float(turtle._active_movement_profile().get("turn_rate_deg", 0.0)) > float(land_profile.get("turn_rate_deg", 0.0)):
		failures.append("creature active profile should use water movement overlay")

func _check_wave4_profile_seeds(failures: Array[String]) -> void:
	var bog_turtle: Dictionary = MovementFeelScript.profile_for("bog_turtle")
	if String(bog_turtle.get("gait", "")) != "tiny_creep" or not float(bog_turtle.get("shell_stability", 0.0)) > 0.0:
		failures.append("bog turtle should expose tiny stubborn turtle movement metadata")
	var otter: Dictionary = MovementFeelScript.profile_for("otter")
	var otter_water: Dictionary = MovementFeelScript.profile_for_surface(otter, "water")
	if String(otter.get("gait", "")) != "bound_slide" or not float(otter_water.get("tail_wave", 0.0)) > float(otter.get("tail_wave", 0.0)):
		failures.append("otter should expose bound-slide land and stronger water tail metadata")
	var leech: Dictionary = MovementFeelScript.profile_for("leech")
	var leech_water: Dictionary = MovementFeelScript.profile_for_surface(leech, "water")
	if String(leech.get("gait", "")) != "inchworm_cluster" or not float(leech.get("inchworm_pulse", 0.0)) > 0.0 or not float(leech_water.get("tail_wave", 0.0)) > float(leech.get("tail_wave", 0.0)):
		failures.append("leech should expose inchworm land and undulating water metadata")

func _check_render_state_flags(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("cane_toad")
	actor.add_modifier("Thanatosis", {"move_speed_mult": 0.0}, 1.0)
	if not bool(actor.get_render_motion_state().get("rooted_pose", false)):
		failures.append("Thanatosis should expose rooted render pose")
	actor.apply_creature("crayfish")
	actor.add_modifier("Meral Display", {"forward_back_only": 2.0}, 1.0)
	var stance_state: Dictionary = actor.get_render_motion_state()
	actor.modifiers.clear()
	actor.last_aim_direction = Vector2.RIGHT
	actor.dash_velocity = Vector2.LEFT * 220.0
	actor.dash_timer = 0.2
	var escape_state: Dictionary = actor.get_render_motion_state()
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO
	if not bool(stance_state.get("display_stance", false)) or not bool(escape_state.get("escape_dash", false)):
		failures.append("crayfish should expose display and escape render states; stance=%s escape=%s" % [str(stance_state), str(escape_state)])
	actor.apply_creature("alligator")
	actor.add_modifier("Ambush", {"move_speed_mult": 0.7}, 1.0)
	if not bool(actor.get_render_motion_state().get("ambush_pose", false)):
		failures.append("Ambush should expose low ambush render pose")
	actor.remove_modifiers_from_source("Ambush")
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * 80.0
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var gator_walk_state: Dictionary = actor.get_render_motion_state()
	if not bool(gator_walk_state.get("high_walk_pose", false)) or bool(gator_walk_state.get("ambush_pose", false)):
		failures.append("moving alligator should expose high-walk posture outside Ambush; state=%s" % str(gator_walk_state))
	actor.apply_creature("owl")
	actor.state = CreatureStateScript.State.PERCHED
	if not bool(actor.get_render_motion_state().get("perched_pose", false)):
		failures.append("perched birds should expose perched render pose")
	actor.apply_creature("duck")
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var duck_water_state: Dictionary = actor.get_render_motion_state()
	var duck_paddle: bool = bool(duck_water_state.get("duck_paddle_pose", false)) and float(duck_water_state.get("duck_paddle_intensity", 0.0)) > 0.25
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var duck_idle_state: Dictionary = actor.get_render_motion_state()
	var duck_idle_clear: bool = not bool(duck_idle_state.get("duck_paddle_pose", false)) and float(duck_idle_state.get("duck_paddle_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var duck_land_state: Dictionary = actor.get_render_motion_state()
	var duck_land_clear: bool = not bool(duck_land_state.get("duck_paddle_pose", false))
	if not duck_paddle or not duck_idle_clear or not duck_land_clear:
		failures.append("moving duck should expose paddling render pose only in water; water=%s idle=%s land=%s state=%s/%s/%s" % [
			str(duck_paddle),
			str(duck_idle_clear),
			str(duck_land_clear),
			str(duck_water_state),
			str(duck_idle_state),
			str(duck_land_state)
		])

func _move_frame(direction: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = direction
	frame.aim = Vector2.RIGHT * 100.0
	return frame

func _aim_frame(direction: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = Vector2.ZERO
	frame.aim = direction * 100.0
	return frame

func _one_tick_velocity(actor: Node, creature_id: String, direction: Vector2) -> float:
	actor.apply_creature(creature_id)
	actor.global_position = Vector2.ZERO
	actor.velocity = Vector2.ZERO
	actor.last_aim_direction = Vector2.RIGHT
	actor.set_input_frame(_move_frame(direction))
	actor.tick_sim(1.0 / 60.0)
	return actor.velocity.length()
