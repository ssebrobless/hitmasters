extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

const SWOOP_RANGE_UNITS := 6.0
const LOW_WINDOW_SEC := 0.7

var context_was_pressed := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0

func tick(actor: Node, _delta: float) -> void:
	if actor.input_frame == null:
		return

	# R: perch on cover while flying; R again to resume flight.
	var context_pressed: bool = actor.input_frame.is_pressed(InputFrameScript.BUTTON_CONTEXT_ACTION)
	if context_pressed and not context_was_pressed:
		if actor.state == CreatureStateScript.State.PERCHED:
			actor.state = CreatureStateScript.State.AIRBORNE
		elif actor.state == CreatureStateScript.State.AIRBORNE and actor.get_current_zone() == TerrainMapScript.COVER:
			actor.state = CreatureStateScript.State.PERCHED
			actor.velocity = Vector2.ZERO
	context_was_pressed = context_pressed

	var elevated: bool = actor.state == CreatureStateScript.State.AIRBORNE or actor.state == CreatureStateScript.State.PERCHED

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		if elevated:
			_swoop(actor)
		else:
			var peck: float = float(actor.stats.get("primary_damage", {}).get("ground_peck", 20.0)) if typeof(actor.stats.get("primary_damage")) == TYPE_DICTIONARY else 20.0
			MeleeHit.hit(actor, 1.0 * SimConstants.UNIT_PX, peck, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Peck")
			actor.primary_timer = 1.1 / actor.get_modifier_value("attack_speed_mult", 1.0)

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		if actor.state == CreatureStateScript.State.AIRBORNE:
			var q := KitHelpers.ability(actor.creature_data, "Q")
			var duration := KitHelpers.nth_number(String(q.get("summary", "")), 0, 10.0)
			actor.begin_stealth(duration, "Silent Flight")
			actor.q_timer = KitHelpers.cooldown_seconds(q)

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		var e := KitHelpers.ability(actor.creature_data, "E")
		var radius_units := KitHelpers.first_number(String(e.get("summary", "")), 12.0)
		_reveal(actor, radius_units * SimConstants.UNIT_PX)
		actor.e_timer = KitHelpers.cooldown_seconds(e)

func _swoop(actor: Node) -> void:
	# Aimed dive: strikes at the cursor point within swoop range; the impact
	# opens the owl's low counter-hit window (ground attacks can connect).
	var swoop_damage: float = float(actor.stats.get("primary_damage", {}).get("swoop", 50.0)) if typeof(actor.stats.get("primary_damage")) == TYPE_DICTIONARY else 50.0
	var to_cursor: Vector2 = actor.input_frame.aim - actor.global_position
	var reach: float = minf(to_cursor.length(), SWOOP_RANGE_UNITS * SimConstants.UNIT_PX)
	MeleeHit.hit(actor, reach, swoop_damage, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_AIR, "Swoop")
	actor.open_low_window(LOW_WINDOW_SEC)
	actor.break_stealth()
	actor.primary_timer = 2.1 / actor.get_modifier_value("attack_speed_mult", 1.0)

func _reveal(actor: Node, radius_px: float) -> void:
	if actor.arena == null:
		return
	for entity in actor.arena.entities:
		if entity == null or not is_instance_valid(entity) or entity.team == actor.team:
			continue
		if entity.global_position.distance_to(actor.global_position) > radius_px:
			continue
		if entity.has_method("break_stealth"):
			entity.break_stealth()
	actor.emit_vfx_event("aura_applied", {"actor": actor, "target": actor, "radius_px": radius_px, "duration": 3.0, "source_ability": "Auditory Mapping", "friendly": true})
