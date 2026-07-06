extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Charges := preload("res://scripts/sim/abilities/charges.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const BITE_MOD_SOURCE := "Water Shrew Bite"
const BITE_MAX_STACKS := 3
const BITE_MOD_SEC := 2.0
const WATER_WALK_SOURCE := "Water Walk"
const PROENKEPHALIN_SOURCE := "Proenkephalin A"

var proenkephalin_charges := Charges.new()
var proenkephalin_primed := false
var water_walk_timer := 0.0

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var e := KitHelpers.ability(actor.creature_data, "E")
	proenkephalin_charges.setup(int(e.get("charges", 2)), KitHelpers.cooldown_seconds(e))
	actor.e_charges = proenkephalin_charges.charges
	proenkephalin_primed = false
	water_walk_timer = 0.0

func reset_for_respawn(actor: Node) -> void:
	proenkephalin_charges.setup(proenkephalin_charges.max_charges, proenkephalin_charges.recharge_seconds)
	actor.e_charges = proenkephalin_charges.charges
	proenkephalin_primed = false
	water_walk_timer = 0.0
	actor.remove_modifiers_from_source(WATER_WALK_SOURCE)

func tick(actor: Node, delta: float) -> void:
	proenkephalin_charges.tick(actor.get_ability_delta(delta) if actor.has_method("get_ability_delta") else delta)
	actor.e_charges = proenkephalin_charges.charges
	_tick_water_walk(actor, delta)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		proenkephalin_primed = false
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_bite(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_start_water_walk(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and proenkephalin_charges.can_spend() and not proenkephalin_primed:
		proenkephalin_primed = true
		proenkephalin_charges.spend()
		actor.e_charges = proenkephalin_charges.charges

func _bite(actor: Node) -> void:
	var hits := MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 8.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite", {"max_hits": 1})
	for hit in hits:
		if hit == null or not is_instance_valid(hit) or not hit.has_method("add_capped_modifier"):
			continue
		hit.add_capped_modifier(BITE_MOD_SOURCE, {
			"move_speed_mult": 0.97,
			"damage_dealt_mult": 0.98,
			"damage_taken_mult": 1.02
		}, BITE_MOD_SEC, BITE_MAX_STACKS)
		if proenkephalin_primed:
			hit.add_modifier(PROENKEPHALIN_SOURCE, {
				"move_speed_mult": 0.0,
				"ability_use_mult": 0.0
			}, 1.0)
			proenkephalin_primed = false
			var e := KitHelpers.ability(actor.creature_data, "E")
			actor.e_timer = KitHelpers.cooldown_seconds(e)
		break
	actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.6)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _start_water_walk(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var summary := String(q.get("summary", ""))
	var speed_bonus := 1.0 + KitHelpers.first_percent(summary, 0.35)
	water_walk_timer = KitHelpers.nth_number(summary, 1, 4.0)
	actor.remove_modifiers_from_source(WATER_WALK_SOURCE)
	actor.add_modifier(WATER_WALK_SOURCE, {
		"move_speed_mult": speed_bonus,
		"water_walk": 2.0
	}, water_walk_timer)
	actor.q_timer = KitHelpers.cooldown_seconds(q)

func _tick_water_walk(actor: Node, delta: float) -> void:
	if water_walk_timer <= 0.0:
		return
	water_walk_timer = maxf(water_walk_timer - delta, 0.0)
	var idle: bool = actor.input_frame == null or actor.input_frame.move.length() <= 0.05
	if water_walk_timer <= 0.0 or idle:
		water_walk_timer = 0.0
		actor.remove_modifiers_from_source(WATER_WALK_SOURCE)
