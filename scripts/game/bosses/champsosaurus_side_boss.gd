extends "res://scripts/game/bosses/boss_actor.gd"
## Champsosaurus side boss (BB-BOSS-3, reframed onto the shared boss_actor base in BB-BOSS-6).
## Aquatic ambush reptile. Jaw Gate: bite at the snout, churned-shallow residue, jaw/neck
## weakpoint on recovery. The base defaults already encode its tuning; this subclass only
## names the attack and supplies the oriented silhouette + phase cues.

func _configure() -> void:
	super._configure()

func _draw_body() -> void:
	super._draw_body()
	var f := facing
	var p := Vector2(-f.y, f.x)
	draw_circle(f * body_radius * 0.2 + p * body_radius * 0.5, 2.2, Color(0.9, 0.9, 0.82))
	draw_circle(f * body_radius * 0.2 - p * body_radius * 0.5, 2.2, Color(0.9, 0.9, 0.82))

func _draw_telegraph_cue() -> void:
	var f := facing
	var p := Vector2(-f.y, f.x)
	var jaw := f * (body_radius + 22.0)
	draw_line(f * body_radius, jaw + p * 10.0, tel_color, 3.0)
	draw_line(f * body_radius, jaw - p * 10.0, tel_color, 3.0)

func _draw_weakpoint_cue() -> void:
	var wp := facing * (body_radius * 0.6)
	var pulse := 0.6 + 0.4 * sin(anim_time * 10.0)
	draw_circle(wp, body_radius * 0.42, Color(0.3, 0.9, 0.8, 0.35 * pulse))
	draw_arc(wp, body_radius * 0.42, 0.0, TAU, 20, Color(0.4, 1.0, 0.85, 0.9), 2.0)
