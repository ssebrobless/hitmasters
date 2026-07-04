extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Aura := preload("res://scripts/sim/abilities/aura.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const DamScript := preload("res://scripts/game/dam.gd")

const DAM_LENGTH_UNITS := 3.0
const DAM_THICKNESS_UNITS := 0.9
const MAX_DAMS := 3
const PLACE_RANGE_UNITS := 4.0

var dams: Array[Node] = []
var rotate_placement := false
var context_was_pressed := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0

func tick(actor: Node, _delta: float) -> void:
	if actor.input_frame == null:
		return
	_prune_dams()
	if not actor.can_act():
		return

	# R toggles dam placement orientation.
	var context_pressed: bool = actor.input_frame.is_pressed(InputFrameScript.BUTTON_CONTEXT_ACTION)
	if context_pressed and not context_was_pressed:
		rotate_placement = not rotate_placement
	context_was_pressed = context_pressed

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Chomp")
		var rate := float(actor.stats.get("attack_rate_per_sec", 1.0))
		actor.primary_timer = (1.0 / maxf(rate, 0.05)) / actor.get_modifier_value("attack_speed_mult", 1.0)

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		var q := KitHelpers.ability(actor.creature_data, "Q")
		var summary := String(q.get("summary", ""))
		var radius_units := KitHelpers.first_number(summary, 8.0)
		var dr := 1.0 - KitHelpers.first_percent(summary, 0.15)
		var duration := KitHelpers.nth_number(summary, 2, 4.0)
		Aura.apply(actor, radius_units * SimConstants.UNIT_PX, duration, {"damage_taken_mult": dr}, {}, "Tail Slap")
		for dam in dams:
			if dam != null and is_instance_valid(dam) and dam.global_position.distance_to(actor.global_position) <= radius_units * SimConstants.UNIT_PX:
				dam.repair(dam.health * 0.2)
		actor.q_timer = KitHelpers.cooldown_seconds(q)

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0 and dams.size() < MAX_DAMS:
		_place_dam(actor)
		actor.e_timer = 0.6

func _place_dam(actor: Node) -> void:
	if actor.arena == null or not actor.arena.has_method("register_dam"):
		return
	var aim: Vector2 = actor.get_aim_direction()
	var place_point: Vector2 = actor.global_position + aim.limit_length(1.0) * minf((actor.input_frame.aim - actor.global_position).length(), PLACE_RANGE_UNITS * SimConstants.UNIT_PX)
	# Wall lies perpendicular to aim, snapped to axis; R flips it.
	var wall_vertical := absf(aim.x) > absf(aim.y)
	if rotate_placement:
		wall_vertical = not wall_vertical
	var length := DAM_LENGTH_UNITS * SimConstants.UNIT_PX
	var thickness := DAM_THICKNESS_UNITS * SimConstants.UNIT_PX
	var size := Vector2(thickness, length) if wall_vertical else Vector2(length, thickness)
	var rect := Rect2(place_point - size * 0.5, size)
	var e := KitHelpers.ability(actor.creature_data, "E")
	var dam_health := KitHelpers.first_number(String(e.get("summary", "")), 200.0)
	var dam = DamScript.new()
	actor.arena.add_child(dam)
	dam.setup(actor.arena, actor.team, rect, dam_health)
	actor.arena.register_dam(dam)
	dams.append(dam)
	actor.emit_vfx_event("attack_swung", {"actor": actor, "position": place_point, "aim": aim, "reach_px": length * 0.5, "source_ability": "Dam"})

func _prune_dams() -> void:
	for i in range(dams.size() - 1, -1, -1):
		if dams[i] == null or not is_instance_valid(dams[i]):
			dams.remove_at(i)
