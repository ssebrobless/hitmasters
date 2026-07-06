extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Dash := preload("res://scripts/sim/abilities/dash.gd")
const Aura := preload("res://scripts/sim/abilities/aura.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

var choke_active := false
var choke_latch_active := false
var choke_cooldown_on_release := 0.0
var choke_contact_resolved := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0

func reset_for_respawn(_actor: Node) -> void:
	choke_active = false
	choke_latch_active = false
	choke_cooldown_on_release = 0.0
	choke_contact_resolved = false

func tick(actor: Node, _delta: float) -> void:
	_update_choke_release_cooldown(actor)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		choke_active = false
		choke_contact_resolved = false
		return
	if choke_active:
		# The choke bite only connects during the dash itself; missing puts
		# Choke on a short cooldown, landing puts it on the full latch-length
		# cooldown per the roster ("after release, equal to latch duration").
		if actor.dash_timer <= 0.0:
			choke_active = false
			choke_contact_resolved = false
			actor.q_timer = 3.0
		elif not choke_contact_resolved:
			var hits := MeleeHit.hit(actor, actor.body_radius * 1.5, _choke_damage(actor), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Choke", {"max_hits": 1, "allow_harvest": false})
			# Only creatures that can be latched consume the Choke.
			choke_contact_resolved = not hits.is_empty()
			var latchable: Node = null
			for hit in hits:
				if hit != null and is_instance_valid(hit) and hit.has_method("receive_latch"):
					latchable = hit
					break
			if latchable != null:
				var q := KitHelpers.ability(actor.creature_data, "Q")
				var execute_seconds := KitHelpers.nth_number(String(q.get("summary", "")), 2, 10.0)
				Latch.start(actor, latchable, execute_seconds, "Choke", execute_seconds)
				choke_active = false
				choke_latch_active = true
				choke_cooldown_on_release = execute_seconds
				actor.q_timer = 0.2
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		MeleeHit.hit(actor, KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX, float(actor.stats.get("primary_damage", 0.0)), DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Bite")
		actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.0)) / actor.get_modifier_value("attack_speed_mult", 1.0)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0 and not choke_active and not choke_latch_active:
		var q := KitHelpers.ability(actor.creature_data, "Q")
		var distance_units := KitHelpers.first_number(String(q.get("summary", "")), 0.0)
		var duration := (distance_units * SimConstants.UNIT_PX) / maxf(actor.get_speed_px() * 2.0, 1.0)
		Dash.start(actor, actor.get_aim_direction(), distance_units * SimConstants.UNIT_PX, duration)
		choke_active = true
		choke_contact_resolved = false
		actor.q_timer = maxf(duration, 0.2)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		var e := KitHelpers.ability(actor.creature_data, "E")
		var summary := String(e.get("summary", ""))
		var radius_units := KitHelpers.first_number(summary, 0.0)
		var ally_dr := 1.0 - KitHelpers.first_percent(summary, 0.0)
		var ally_damage := 1.0 + KitHelpers.nth_number(summary, 2, 0.0) / 100.0
		var enemy_heal := 1.0 - KitHelpers.nth_number(summary, 4, 0.0) / 100.0
		var duration := KitHelpers.nth_number(summary, 5, 0.0)
		Aura.apply(actor, radius_units * SimConstants.UNIT_PX, duration, {"damage_taken_mult": ally_dr, "damage_dealt_mult": ally_damage}, {"healing_received_mult": enemy_heal}, "Scent Marking")
		actor.e_timer = KitHelpers.cooldown_seconds(e)

func _choke_damage(actor: Node) -> float:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	return KitHelpers.nth_number(String(q.get("summary", "")), 1, 0.0)

func _update_choke_release_cooldown(actor: Node) -> void:
	if not choke_latch_active:
		return
	var still_latched: bool = actor.latch_victim != null and is_instance_valid(actor.latch_victim) and actor.latch_source == "Choke"
	if still_latched:
		actor.q_timer = maxf(actor.q_timer, 0.2)
		return
	choke_latch_active = false
	actor.q_timer = maxf(actor.q_timer, choke_cooldown_on_release)
	choke_cooldown_on_release = 0.0
