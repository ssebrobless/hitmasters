extends RefCounted

const DEFAULT_PROFILE := {
	"accel_time": 0.08,
	"decel_time": 0.07,
	"turn_rate_deg": 900.0,
	"terrain_lerp_rate": 9.0,
	"gait": "walk",
	"gait_rate_mult": 1.0,
	"bob_px": 0.0
}

const PROFILES := {
	"bullfrog": {
		"accel_time": 0.14,
		"decel_time": 0.10,
		"turn_rate_deg": 620.0,
		"gait": "heavy_hop",
		"gait_rate_mult": 0.72,
		"bob_px": 2.4
	},
	"cane_toad": {
		"accel_time": 0.18,
		"decel_time": 0.08,
		"turn_rate_deg": 540.0,
		"gait": "squat_hop",
		"gait_rate_mult": 0.55,
		"bob_px": 1.2
	},
	"crayfish": {
		"accel_time": 0.07,
		"decel_time": 0.05,
		"turn_rate_deg": 1120.0,
		"gait": "scuttle",
		"gait_rate_mult": 1.55,
		"bob_px": 0.4
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
	"snapping_turtle": {
		"accel_time": 0.28,
		"decel_time": 0.18,
		"turn_rate_deg": 270.0,
		"terrain_lerp_rate": 5.0,
		"gait": "heavy_creep",
		"gait_rate_mult": 0.45,
		"bob_px": 0.2
	},
	"alligator": {
		"accel_time": 0.20,
		"decel_time": 0.14,
		"turn_rate_deg": 240.0,
		"terrain_lerp_rate": 6.0,
		"gait": "low_crawl",
		"gait_rate_mult": 0.65,
		"bob_px": 0.3
	},
	"water_snake": {
		"accel_time": 0.10,
		"decel_time": 0.08,
		"turn_rate_deg": 320.0,
		"gait": "slither",
		"gait_rate_mult": 1.25,
		"bob_px": 0.0
	},
	"wolf_spider": {
		"accel_time": 0.055,
		"decel_time": 0.045,
		"turn_rate_deg": 1350.0,
		"gait": "scuttle",
		"gait_rate_mult": 1.8,
		"bob_px": 0.25
	},
	"firefly": {
		"accel_time": 0.16,
		"decel_time": 0.22,
		"turn_rate_deg": 760.0,
		"terrain_lerp_rate": 4.0,
		"gait": "hover",
		"gait_rate_mult": 0.5,
		"bob_px": 1.8
	},
	"mosquito_swarm": {
		"accel_time": 0.055,
		"decel_time": 0.12,
		"turn_rate_deg": 1400.0,
		"terrain_lerp_rate": 7.0,
		"gait": "swarm_jitter",
		"gait_rate_mult": 2.4,
		"bob_px": 0.7
	}
}

static func profile_for(creature_id: String) -> Dictionary:
	var profile := DEFAULT_PROFILE.duplicate()
	var override: Dictionary = PROFILES.get(creature_id, {})
	for key in override.keys():
		profile[key] = override[key]
	return profile

static func profiled_velocity(current_velocity: Vector2, move: Vector2, top_speed_px: float, delta: float, profile: Dictionary) -> Vector2:
	if top_speed_px <= 0.0:
		return Vector2.ZERO
	var desired := Vector2.ZERO
	if move.length() > 0.001:
		desired = _turn_limited_direction(current_velocity, move.normalized(), delta, float(profile.get("turn_rate_deg", 900.0))) * top_speed_px
	var response_time := float(profile.get("accel_time", 0.08)) if desired.length() > current_velocity.length() else float(profile.get("decel_time", 0.07))
	if desired != Vector2.ZERO and current_velocity.length() > 1.0 and current_velocity.normalized().dot(desired.normalized()) < -0.25:
		response_time = maxf(response_time, float(profile.get("decel_time", 0.07)))
	var max_delta := top_speed_px / maxf(response_time, 0.001) * delta
	return current_velocity.move_toward(desired, max_delta)

static func gait_phase_delta(speed_px: float, delta: float, profile: Dictionary) -> float:
	if speed_px <= 4.0:
		return 0.0
	return delta * clampf(speed_px / 26.0, 3.0, 11.0) * float(profile.get("gait_rate_mult", 1.0))

static func render_anim(profile: Dictionary, walk_phase: float) -> Dictionary:
	return {
		"movement_gait": String(profile.get("gait", "walk")),
		"movement_bob_px": float(profile.get("bob_px", 0.0)),
		"movement_bob": sin(walk_phase) * float(profile.get("bob_px", 0.0))
	}

static func _turn_limited_direction(current_velocity: Vector2, desired_direction: Vector2, delta: float, turn_rate_deg: float) -> Vector2:
	if current_velocity.length() <= 4.0 or turn_rate_deg <= 0.0:
		return desired_direction
	var current_direction := current_velocity.normalized()
	var max_angle := deg_to_rad(turn_rate_deg) * delta
	var angle := clampf(current_direction.angle_to(desired_direction), -max_angle, max_angle)
	return current_direction.rotated(angle).normalized()
