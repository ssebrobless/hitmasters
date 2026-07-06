extends RefCounted

const DEFAULT_PROFILE := {
	"accel_time": 0.08,
	"decel_time": 0.07,
	"turn_rate_deg": 900.0,
	"terrain_lerp_rate": 9.0,
	"gait": "walk",
	"gait_rate_mult": 1.0,
	"bob_px": 0.0,
	"hop_leg_scale": 1.0,
	"ground_contact": 0.6,
	"landing_squash": 0.0,
	"landing_thump": 0.0,
	"scuttle_stride": 1.0,
	"tail_curl": 0.0,
	"low_slung": 0.0,
	"swarm_radius_mult": 1.0,
	"swarm_jitter": 0.0,
	"glow_breathe": 0.0,
	"wingbeat_mult": 1.0,
	"slither_amp": 1.0,
	"tail_sway": 1.0,
	"crawl_weight": 0.0,
	"body_wiggle": 1.0,
	"tail_wave": 1.0,
	"bird_stride": 1.0,
	"perch_flutter": 1.0,
	"turtle_stride": 1.0,
	"shell_stability": 0.0,
	"waddle_sway": 0.0,
	"forward_speed_mult": 1.0,
	"lateral_speed_mult": 1.0,
	"backward_speed_mult": 1.0,
	"lateral_accel_time": -1.0,
	"backward_accel_time": -1.0,
	"cluster_spread": 1.0,
	"inchworm_pulse": 0.0,
	"water_profile": {}
}

const PROFILES := {
	"bullfrog": {
		"accel_time": 0.14,
		"decel_time": 0.10,
		"turn_rate_deg": 620.0,
		"gait": "heavy_hop",
		"gait_rate_mult": 0.72,
		"bob_px": 2.4,
		"hop_leg_scale": 1.18,
		"ground_contact": 0.56,
		"landing_squash": 0.08,
		"landing_thump": 1.0
	},
	"cane_toad": {
		"accel_time": 0.18,
		"decel_time": 0.08,
		"turn_rate_deg": 540.0,
		"gait": "squat_hop",
		"gait_rate_mult": 0.55,
		"bob_px": 1.2,
		"hop_leg_scale": 0.68,
		"ground_contact": 0.82,
		"landing_squash": 0.13,
		"landing_thump": 0.45
	},
	"chorus_frog": {
		"accel_time": 0.06,
		"decel_time": 0.05,
		"turn_rate_deg": 1180.0,
		"gait": "rhythmic_hop",
		"gait_rate_mult": 1.35,
		"bob_px": 1.1,
		"hop_leg_scale": 0.74,
		"ground_contact": 0.46,
		"landing_squash": 0.04,
		"landing_thump": 0.2
	},
	"crayfish": {
		"accel_time": 0.07,
		"decel_time": 0.05,
		"turn_rate_deg": 1120.0,
		"gait": "scuttle",
		"gait_rate_mult": 1.55,
		"bob_px": 0.4,
		"scuttle_stride": 1.35,
		"tail_curl": 0.55,
		"forward_speed_mult": 0.9,
		"lateral_speed_mult": 1.2,
		"backward_speed_mult": 1.1,
		"lateral_accel_time": 0.045,
		"backward_accel_time": 0.035
	},
	"water_shrew": {
		"accel_time": 0.035,
		"decel_time": 0.035,
		"turn_rate_deg": 1600.0,
		"terrain_lerp_rate": 14.0,
		"gait": "skitter",
		"gait_rate_mult": 2.1,
		"bob_px": 0.5
	},
	"newt": {
		"accel_time": 0.12,
		"decel_time": 0.09,
		"turn_rate_deg": 720.0,
		"terrain_lerp_rate": 7.0,
		"gait": "slick_crawl",
		"gait_rate_mult": 0.9,
		"bob_px": 0.15,
		"body_wiggle": 1.45,
		"tail_wave": 1.55
	},
	"snapping_turtle": {
		"accel_time": 0.28,
		"decel_time": 0.18,
		"turn_rate_deg": 270.0,
		"terrain_lerp_rate": 5.0,
		"gait": "heavy_creep",
		"gait_rate_mult": 0.45,
		"bob_px": 0.2,
		"turtle_stride": 0.42,
		"shell_stability": 0.82,
		"water_profile": {
			"accel_time": 0.16,
			"decel_time": 0.24,
			"turn_rate_deg": 390.0,
			"gait_rate_mult": 0.62,
			"bob_px": 0.12,
			"turtle_stride": 0.68
		}
	},
	"bog_turtle": {
		"accel_time": 0.30,
		"decel_time": 0.20,
		"turn_rate_deg": 300.0,
		"terrain_lerp_rate": 5.0,
		"gait": "tiny_creep",
		"gait_rate_mult": 0.52,
		"bob_px": 0.08,
		"turtle_stride": 0.34,
		"shell_stability": 0.9,
		"water_profile": {
			"accel_time": 0.18,
			"decel_time": 0.24,
			"turn_rate_deg": 440.0,
			"gait_rate_mult": 0.68,
			"turtle_stride": 0.62
		}
	},
	"alligator": {
		"accel_time": 0.20,
		"decel_time": 0.14,
		"turn_rate_deg": 240.0,
		"terrain_lerp_rate": 6.0,
		"gait": "low_crawl",
		"gait_rate_mult": 0.65,
		"bob_px": 0.3,
		"tail_sway": 1.35,
		"crawl_weight": 0.32,
		"water_profile": {
			"accel_time": 0.13,
			"decel_time": 0.20,
			"turn_rate_deg": 360.0,
			"tail_sway": 1.8,
			"crawl_weight": 0.12
		}
	},
	"water_snake": {
		"accel_time": 0.10,
		"decel_time": 0.08,
		"turn_rate_deg": 320.0,
		"gait": "slither",
		"gait_rate_mult": 1.25,
		"bob_px": 0.0,
		"slither_amp": 1.35,
		"water_profile": {
			"accel_time": 0.08,
			"decel_time": 0.12,
			"turn_rate_deg": 410.0,
			"slither_amp": 1.65
		}
	},
	"great_blue_heron": {
		"accel_time": 0.22,
		"decel_time": 0.14,
		"turn_rate_deg": 420.0,
		"terrain_lerp_rate": 5.0,
		"gait": "patient_wade",
		"gait_rate_mult": 0.48,
		"bob_px": 0.25,
		"bird_stride": 0.52,
		"wingbeat_mult": 0.62
	},
	"kingfisher": {
		"accel_time": 0.055,
		"decel_time": 0.06,
		"turn_rate_deg": 1250.0,
		"gait": "dart_hover",
		"gait_rate_mult": 1.65,
		"bob_px": 1.15,
		"bird_stride": 1.25,
		"wingbeat_mult": 1.45,
		"perch_flutter": 1.35
	},
	"owl": {
		"accel_time": 0.18,
		"decel_time": 0.16,
		"turn_rate_deg": 620.0,
		"terrain_lerp_rate": 5.0,
		"gait": "silent_glide",
		"gait_rate_mult": 0.58,
		"bob_px": 1.0,
		"bird_stride": 0.72,
		"wingbeat_mult": 0.55,
		"perch_flutter": 0.62
	},
	"duck": {
		"accel_time": 0.14,
		"decel_time": 0.11,
		"turn_rate_deg": 650.0,
		"terrain_lerp_rate": 7.0,
		"gait": "waddle_paddle",
		"gait_rate_mult": 0.78,
		"bob_px": 0.65,
		"bird_stride": 0.76,
		"wingbeat_mult": 0.85,
		"waddle_sway": 0.34,
		"water_profile": {
			"accel_time": 0.10,
			"decel_time": 0.15,
			"turn_rate_deg": 760.0,
			"bob_px": 0.45,
			"waddle_sway": 0.16
		}
	},
	"mink": {
		"accel_time": 0.045,
		"decel_time": 0.055,
		"turn_rate_deg": 1450.0,
		"gait": "elastic_bound",
		"gait_rate_mult": 1.7,
		"bob_px": 0.8,
		"body_wiggle": 1.28,
		"tail_wave": 1.35,
		"water_profile": {
			"accel_time": 0.08,
			"decel_time": 0.10,
			"turn_rate_deg": 980.0,
			"body_wiggle": 1.0,
			"tail_wave": 1.65
		}
	},
	"otter": {
		"accel_time": 0.055,
		"decel_time": 0.06,
		"turn_rate_deg": 1350.0,
		"terrain_lerp_rate": 7.5,
		"gait": "bound_slide",
		"gait_rate_mult": 1.65,
		"bob_px": 0.72,
		"body_wiggle": 1.18,
		"tail_wave": 1.28,
		"water_profile": {
			"accel_time": 0.045,
			"decel_time": 0.085,
			"turn_rate_deg": 1180.0,
			"body_wiggle": 1.36,
			"tail_wave": 1.72
		}
	},
	"beaver": {
		"accel_time": 0.22,
		"decel_time": 0.16,
		"turn_rate_deg": 430.0,
		"terrain_lerp_rate": 5.5,
		"gait": "builder_trundle",
		"gait_rate_mult": 0.58,
		"bob_px": 0.28,
		"body_wiggle": 0.42,
		"tail_wave": 0.55,
		"water_profile": {
			"accel_time": 0.14,
			"decel_time": 0.22,
			"turn_rate_deg": 620.0,
			"body_wiggle": 0.58,
			"tail_wave": 0.95
		}
	},
	"wolf_spider": {
		"accel_time": 0.055,
		"decel_time": 0.045,
		"turn_rate_deg": 1350.0,
		"gait": "scuttle",
		"gait_rate_mult": 1.8,
		"bob_px": 0.25,
		"scuttle_stride": 1.45,
		"low_slung": 0.22
	},
	"firefly": {
		"accel_time": 0.16,
		"decel_time": 0.22,
		"turn_rate_deg": 760.0,
		"terrain_lerp_rate": 4.0,
		"gait": "hover",
		"gait_rate_mult": 0.5,
		"bob_px": 1.8,
		"glow_breathe": 0.32,
		"wingbeat_mult": 0.72
	},
	"mosquito_swarm": {
		"accel_time": 0.055,
		"decel_time": 0.12,
		"turn_rate_deg": 1400.0,
		"terrain_lerp_rate": 7.0,
		"gait": "swarm_jitter",
		"gait_rate_mult": 2.4,
		"bob_px": 0.7,
		"swarm_radius_mult": 1.18,
		"swarm_jitter": 0.46
	},
	"leech": {
		"accel_time": 0.22,
		"decel_time": 0.18,
		"turn_rate_deg": 520.0,
		"terrain_lerp_rate": 5.0,
		"gait": "inchworm_cluster",
		"gait_rate_mult": 0.78,
		"bob_px": 0.05,
		"body_wiggle": 1.45,
		"tail_wave": 1.35,
		"cluster_spread": 0.78,
		"inchworm_pulse": 0.45,
		"water_profile": {
			"accel_time": 0.10,
			"decel_time": 0.14,
			"turn_rate_deg": 760.0,
			"gait": "undulating_cluster",
			"gait_rate_mult": 1.28,
			"body_wiggle": 1.75,
			"tail_wave": 1.95,
			"cluster_spread": 1.05,
			"inchworm_pulse": 0.2
		}
	}
}

static func profile_for(creature_id: String) -> Dictionary:
	var profile := DEFAULT_PROFILE.duplicate()
	var override: Dictionary = PROFILES.get(creature_id, {})
	for key in override.keys():
		profile[key] = override[key]
	return profile

static func profile_for_surface(profile: Dictionary, surface: String) -> Dictionary:
	if surface != "water":
		return profile
	var overlay: Dictionary = profile.get("water_profile", {})
	if overlay.is_empty():
		return profile
	var active := profile.duplicate()
	for key in overlay.keys():
		active[key] = overlay[key]
	return active

static func profiled_velocity(current_velocity: Vector2, move: Vector2, top_speed_px: float, delta: float, profile: Dictionary, facing_direction := Vector2.ZERO) -> Vector2:
	if top_speed_px <= 0.0:
		return Vector2.ZERO
	var desired := Vector2.ZERO
	if move.length() > 0.001:
		var desired_direction := move.normalized()
		var desired_speed := top_speed_px * _directional_speed_mult(desired_direction, facing_direction, profile)
		desired = _turn_limited_direction(current_velocity, desired_direction, delta, float(profile.get("turn_rate_deg", 900.0))) * desired_speed
	var response_time := _directional_accel_time(float(profile.get("accel_time", 0.08)), move, facing_direction, profile) if desired.length() > current_velocity.length() else float(profile.get("decel_time", 0.07))
	if desired != Vector2.ZERO and current_velocity.length() > 1.0 and current_velocity.normalized().dot(desired.normalized()) < -0.25:
		response_time = maxf(response_time, float(profile.get("decel_time", 0.07)))
	var response_speed := top_speed_px if desired == Vector2.ZERO or desired.length() < current_velocity.length() else desired.length()
	var max_delta := response_speed / maxf(response_time, 0.001) * delta
	return current_velocity.move_toward(desired, max_delta)

static func gait_phase_delta(speed_px: float, delta: float, profile: Dictionary) -> float:
	if speed_px <= 4.0:
		return 0.0
	return delta * clampf(speed_px / 26.0, 3.0, 11.0) * float(profile.get("gait_rate_mult", 1.0))

static func render_anim(profile: Dictionary, walk_phase: float) -> Dictionary:
	return {
		"movement_gait": String(profile.get("gait", "walk")),
		"movement_bob_px": float(profile.get("bob_px", 0.0)),
		"movement_bob": sin(walk_phase) * float(profile.get("bob_px", 0.0)),
		"hop_leg_scale": float(profile.get("hop_leg_scale", 1.0)),
		"ground_contact": float(profile.get("ground_contact", 0.6)),
		"landing_squash": float(profile.get("landing_squash", 0.0)),
		"landing_thump": float(profile.get("landing_thump", 0.0)),
		"scuttle_stride": float(profile.get("scuttle_stride", 1.0)),
		"tail_curl": float(profile.get("tail_curl", 0.0)),
		"low_slung": float(profile.get("low_slung", 0.0)),
		"swarm_radius_mult": float(profile.get("swarm_radius_mult", 1.0)),
		"swarm_jitter": float(profile.get("swarm_jitter", 0.0)),
		"glow_breathe": float(profile.get("glow_breathe", 0.0)),
		"wingbeat_mult": float(profile.get("wingbeat_mult", 1.0)),
		"slither_amp": float(profile.get("slither_amp", 1.0)),
		"tail_sway": float(profile.get("tail_sway", 1.0)),
		"crawl_weight": float(profile.get("crawl_weight", 0.0)),
		"body_wiggle": float(profile.get("body_wiggle", 1.0)),
		"tail_wave": float(profile.get("tail_wave", 1.0)),
		"bird_stride": float(profile.get("bird_stride", 1.0)),
		"perch_flutter": float(profile.get("perch_flutter", 1.0)),
		"turtle_stride": float(profile.get("turtle_stride", 1.0)),
		"shell_stability": float(profile.get("shell_stability", 0.0)),
		"waddle_sway": float(profile.get("waddle_sway", 0.0)),
		"cluster_spread": float(profile.get("cluster_spread", 1.0)),
		"inchworm_pulse": float(profile.get("inchworm_pulse", 0.0))
	}

static func _turn_limited_direction(current_velocity: Vector2, desired_direction: Vector2, delta: float, turn_rate_deg: float) -> Vector2:
	if current_velocity.length() <= 4.0 or turn_rate_deg <= 0.0:
		return desired_direction
	var current_direction := current_velocity.normalized()
	var max_angle := deg_to_rad(turn_rate_deg) * delta
	var angle := clampf(current_direction.angle_to(desired_direction), -max_angle, max_angle)
	return current_direction.rotated(angle).normalized()

static func _directional_speed_mult(move_direction: Vector2, facing_direction: Vector2, profile: Dictionary) -> float:
	if move_direction.length() <= 0.001 or facing_direction.length() <= 0.001:
		return 1.0
	var forward := facing_direction.normalized()
	var move := move_direction.normalized()
	var forward_weight := maxf(move.dot(forward), 0.0)
	var backward_weight := maxf(-move.dot(forward), 0.0)
	var lateral_weight := absf(move.cross(forward))
	var total := maxf(forward_weight + backward_weight + lateral_weight, 0.001)
	return (
		forward_weight * float(profile.get("forward_speed_mult", 1.0))
		+ lateral_weight * float(profile.get("lateral_speed_mult", 1.0))
		+ backward_weight * float(profile.get("backward_speed_mult", 1.0))
	) / total

static func _directional_accel_time(default_time: float, move_direction: Vector2, facing_direction: Vector2, profile: Dictionary) -> float:
	if move_direction.length() <= 0.001 or facing_direction.length() <= 0.001:
		return default_time
	var forward := facing_direction.normalized()
	var move := move_direction.normalized()
	var backward_weight := maxf(-move.dot(forward), 0.0)
	var lateral_weight := absf(move.cross(forward))
	var backward_time := float(profile.get("backward_accel_time", -1.0))
	var lateral_time := float(profile.get("lateral_accel_time", -1.0))
	if backward_weight >= lateral_weight and backward_weight > 0.5 and backward_time > 0.0:
		return backward_time
	if lateral_weight > 0.5 and lateral_time > 0.0:
		return lateral_time
	return default_time
