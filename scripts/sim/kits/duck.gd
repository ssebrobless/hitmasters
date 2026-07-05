extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const DucklingScript := preload("res://scripts/sim/pets/duckling.gd")

const MAX_DUCKLINGS := 4
const NEST_CHANNEL_SEC := 4.0
const CHAIN_DAMAGES := [10.0, 10.0, 15.0]

var ducklings: Array[Node] = []
var chain_index := 0
var nest_channel := 0.0
var mobbing_armed := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0

func reset_for_respawn(_actor: Node) -> void:
	_retire_ducklings()
	chain_index = 0
	nest_channel = 0.0
	mobbing_armed = false

func tick(actor: Node, delta: float) -> void:
	if actor.input_frame == null:
		return
	_prune()
	if not actor.can_act():
		nest_channel = 0.0
		return

	# Nesting: channel while standing still; hatch ducklings on completion.
	if nest_channel > 0.0:
		if actor.input_frame.move.length() > 0.0 or actor.is_airborne():
			nest_channel = 0.0
		else:
			nest_channel -= delta
			if nest_channel <= 0.0:
				_hatch(actor)
				var q := KitHelpers.ability(actor.creature_data, "Q")
				actor.q_timer = float(q.get("cooldown_after_hatch_sec", 25.0))

	# Cannot attack while flying.
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0 and not actor.is_airborne():
		var damage: float = CHAIN_DAMAGES[chain_index]
		var ability_name := "Bite" if chain_index == 2 else "Wing"
		var reach_units := 1.0 if chain_index == 2 else 1.5
		var hits := MeleeHit.hit(actor, reach_units * SimConstants.UNIT_PX, damage, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, ability_name)
		chain_index = (chain_index + 1) % CHAIN_DAMAGES.size()
		if mobbing_armed and not hits.is_empty():
			_mob(actor)
			mobbing_armed = false
		actor.primary_timer = float(actor.stats.get("attack_interval_sec", 0.85)) / actor.get_modifier_value("attack_speed_mult", 1.0)

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0 and nest_channel <= 0.0 and ducklings.size() < MAX_DUCKLINGS and not actor.is_airborne():
		nest_channel = NEST_CHANNEL_SEC
		actor.emit_vfx_event("windup_started", {"actor": actor, "position": actor.global_position, "aim": actor.get_aim_direction(), "reach_px": 20.0, "duration": NEST_CHANNEL_SEC, "source_ability": "Nesting"})

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and actor.e_timer <= 0.0:
		mobbing_armed = true
		var e := KitHelpers.ability(actor.creature_data, "E")
		actor.e_timer = KitHelpers.cooldown_seconds(e)

func _hatch(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	var duckling_health := KitHelpers.nth_number(String(q.get("summary", "")), 2, 80.0)
	var to_hatch: int = mini(4, MAX_DUCKLINGS - ducklings.size())
	for i in to_hatch:
		var duckling = DucklingScript.new()
		actor.arena.add_child(duckling)
		var angle := TAU * float(i) / 4.0
		duckling.setup(actor.arena, actor, actor.team, actor.global_position + Vector2(cos(angle), sin(angle)) * 18.0, ducklings.size(), duckling_health)
		actor.arena.register_entity(duckling)
		ducklings.append(duckling)

func _mob(actor: Node) -> void:
	var e := KitHelpers.ability(actor.creature_data, "E")
	var summary := String(e.get("summary", ""))
	var dr := 1.0 - KitHelpers.first_percent(summary, 0.85)
	var speed_bonus := 1.0 + KitHelpers.nth_number(summary, 1, 20.0) / 100.0
	var duration := KitHelpers.nth_number(summary, 2, 6.0)
	for duckling in ducklings:
		if duckling != null and is_instance_valid(duckling):
			duckling.add_modifier("Mobbing", {"damage_taken_mult": dr, "move_speed_mult": speed_bonus, "attack_speed_mult": speed_bonus}, duration)
			actor.emit_vfx_event("aura_applied", {"actor": actor, "target": duckling, "duration": duration, "source_ability": "Mobbing", "friendly": true})

func _prune() -> void:
	for i in range(ducklings.size() - 1, -1, -1):
		if ducklings[i] == null or not is_instance_valid(ducklings[i]):
			ducklings.remove_at(i)
		elif ducklings[i].has_method("is_alive") and not ducklings[i].is_alive():
			ducklings.remove_at(i)

func _retire_ducklings() -> void:
	for duckling in ducklings:
		if duckling == null or not is_instance_valid(duckling):
			continue
		if duckling.has_method("retire"):
			duckling.retire()
		else:
			if duckling.get("arena") != null and duckling.get("arena").has_method("unregister_entity"):
				duckling.get("arena").unregister_entity(duckling)
			duckling.queue_free()
	ducklings.clear()
