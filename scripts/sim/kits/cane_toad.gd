extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const Projectile := preload("res://scripts/sim/abilities/projectile.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const POISON_STREAM_TICK_SEC := 0.25
const POISON_STREAM_DOT_TOTAL := 20.0
const POISON_STREAM_DOT_SEC := 2.0
const POISON_STREAM_AMMO_PER_SEC := 10.0
const BUFOTOXIN_TOTAL := 24.0
const BUFOTOXIN_SEC := 2.0
const BUFOTOXIN_MAX_STACKS := 5
const TOXIC_SKIN_TOTAL := 20.0
const TOXIC_SKIN_SEC := 3.0
const TOXIC_SKIN_MAX_STACKS := 3

var toxic_skin_timer := 0.0
var thanatosis_timer := 0.0

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.secondary_resource_label = "TOXIN"
	actor.secondary_resource_max = float(actor.stats.get("ammo", 100.0))
	actor.secondary_resource = actor.secondary_resource_max
	toxic_skin_timer = 0.0
	thanatosis_timer = 0.0

func reset_for_respawn(actor: Node) -> void:
	actor.secondary_resource = actor.secondary_resource_max
	toxic_skin_timer = 0.0
	thanatosis_timer = 0.0

func tick(actor: Node, delta: float) -> void:
	toxic_skin_timer = maxf(toxic_skin_timer - delta, 0.0)
	thanatosis_timer = maxf(thanatosis_timer - delta, 0.0)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY):
		_tick_poison_stream(actor, delta)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_start_toxic_skin(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0 and thanatosis_timer <= 0.0:
		_start_thanatosis(actor)

func on_melee_contact_damage(actor: Node, attacker: Node, _amount: float, _event: Resource) -> void:
	if attacker == null or not is_instance_valid(attacker) or not attacker.has_method("apply_dot"):
		return
	attacker.apply_dot(actor, "Bufotoxin", BUFOTOXIN_TOTAL, BUFOTOXIN_SEC, BUFOTOXIN_MAX_STACKS)
	if toxic_skin_timer > 0.0:
		var bonus := 1.0 + _thanatosis_toxic_bonus(actor)
		attacker.apply_dot(actor, "Toxic Skin", TOXIC_SKIN_TOTAL * bonus, TOXIC_SKIN_SEC, TOXIC_SKIN_MAX_STACKS)

func _tick_poison_stream(actor: Node, delta: float) -> void:
	if actor.secondary_resource <= 0.0:
		return
	var spent: float = minf(actor.secondary_resource, POISON_STREAM_AMMO_PER_SEC * delta)
	actor.secondary_resource = maxf(actor.secondary_resource - spent, 0.0)
	if actor.primary_timer > 0.0:
		return
	var range_units := KitHelpers.range_units(actor.stats, 3.0) * (2.0 if thanatosis_timer > 0.0 else 1.0)
	var hits := Projectile.instant_line(actor, range_units * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 5.0)), DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Poison Stream", {
		"half_width_px": SimConstants.UNIT_PX * 0.5
	})
	for hit in hits:
		if hit != null and is_instance_valid(hit) and hit.has_method("apply_dot"):
			hit.apply_dot(actor, "Poison Stream", POISON_STREAM_DOT_TOTAL, POISON_STREAM_DOT_SEC)
	actor.primary_timer = POISON_STREAM_TICK_SEC / actor.get_modifier_value("attack_speed_mult", 1.0)

func _start_toxic_skin(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	toxic_skin_timer = KitHelpers.first_number(String(q.get("summary", "")), 10.0)
	actor.q_timer = KitHelpers.cooldown_seconds(q)

func _start_thanatosis(actor: Node) -> void:
	var e := KitHelpers.ability(actor.creature_data, "E")
	thanatosis_timer = KitHelpers.first_number(String(e.get("summary", "")), 5.0)
	actor.add_modifier("Thanatosis", {"move_speed_mult": 0.0}, thanatosis_timer)
	actor.e_timer = KitHelpers.cooldown_seconds(e)

func _thanatosis_toxic_bonus(actor: Node) -> float:
	if thanatosis_timer <= 0.0:
		return 0.0
	var e := KitHelpers.ability(actor.creature_data, "E")
	return KitHelpers.first_percent(String(e.get("summary", "")), 0.05)
