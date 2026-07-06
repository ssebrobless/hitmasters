extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const Charges := preload("res://scripts/sim/abilities/charges.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const FireflyProjectileScript := preload("res://scripts/sim/entities/firefly_projectile.gd")
const GlowwormMineScript := preload("res://scripts/sim/entities/glowworm_mine.gd")
const GlowwormFieldScript := preload("res://scripts/sim/entities/glowworm_field.gd")

const BIOLUM_RADIUS_UNITS := 4.0
const BIOLUM_HEAL_PER_SEC := 20.0
const FLASH_RADIUS_UNITS := 7.0
const FLASH_HEAL_MULT := 1.15
const FLASH_SPEED_MULT := 1.05
const FLASH_REFRESH_SEC := 0.24
const MAX_MINES := 3
const MAX_FIELDS := 8

var flash_timer := 0.0
var glowworm_charges := Charges.new()
var mines: Array[Node] = []
var fields: Array[Node] = []
var projectiles: Array[Node] = []

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var e := KitHelpers.ability(actor.creature_data, "E")
	glowworm_charges.setup(int(e.get("charges", 3)), KitHelpers.cooldown_seconds(e))
	actor.e_charges = glowworm_charges.charges
	flash_timer = 0.0
	mines.clear()
	fields.clear()
	projectiles.clear()

func reset_for_respawn(_actor: Node) -> void:
	_retire_all()
	flash_timer = 0.0
	glowworm_charges.setup(glowworm_charges.max_charges, glowworm_charges.recharge_seconds)

func tick(actor: Node, delta: float) -> void:
	_prune()
	glowworm_charges.tick(delta)
	actor.e_charges = glowworm_charges.charges
	flash_timer = maxf(flash_timer - delta, 0.0)
	_tick_bioluminescence(actor, delta)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and actor.primary_timer <= 0.0:
		_fire_projectile(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_start_flash_train(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) and glowworm_charges.can_spend():
		_place_glowworm(actor)

func spawn_glowworm_field(actor: Node, position: Vector2) -> void:
	if actor.arena == null:
		return
	_prune()
	while fields.size() >= MAX_FIELDS:
		var field: Node = fields.pop_front()
		if field != null and is_instance_valid(field) and field.has_method("retire"):
			field.retire()
	var field = GlowwormFieldScript.new()
	actor.arena.add_child(field)
	field.setup(actor.arena, actor, position)
	fields.append(field)

func _tick_bioluminescence(actor: Node, delta: float) -> void:
	if actor.arena == null:
		return
	var radius_units := FLASH_RADIUS_UNITS if flash_timer > 0.0 else BIOLUM_RADIUS_UNITS
	var heal_per_sec := BIOLUM_HEAL_PER_SEC * (FLASH_HEAL_MULT if flash_timer > 0.0 else 1.0)
	var radius_px := radius_units * SimConstants.UNIT_PX
	for entity in actor.arena.entities:
		if not TargetFilter.is_live_ally_target(actor, entity, {"require_method": "heal"}):
			continue
		if entity.global_position.distance_to(actor.global_position) > radius_px + entity.body_radius:
			continue
		entity.heal(heal_per_sec * delta)
		if flash_timer > 0.0 and entity.has_method("add_modifier"):
			entity.add_modifier("Flash-Train", {"move_speed_mult": FLASH_SPEED_MULT}, FLASH_REFRESH_SEC)
			if actor.has_method("emit_vfx_event"):
				actor.emit_vfx_event("aura_applied", {"actor": actor, "target": entity, "radius_px": radius_px, "duration": FLASH_REFRESH_SEC, "source_ability": "Flash-Train", "friendly": true})

func _fire_projectile(actor: Node) -> void:
	if actor.arena == null:
		return
	var projectile = FireflyProjectileScript.new()
	actor.arena.add_child(projectile)
	var range_px := KitHelpers.range_units(actor.stats, 10.0) * SimConstants.UNIT_PX
	projectile.setup(actor.arena, actor, actor.global_position + actor.get_aim_direction() * (actor.body_radius + 4.0), actor.get_aim_direction(), range_px, float(actor.stats.get("primary_damage", 3.0)))
	projectiles.append(projectile)
	actor.primary_timer = (1.0 / maxf(float(actor.stats.get("attack_rate_per_sec", 1.3)), 0.05)) / actor.get_modifier_value("attack_speed_mult", 1.0)

func _start_flash_train(actor: Node) -> void:
	var q := KitHelpers.ability(actor.creature_data, "Q")
	flash_timer = KitHelpers.nth_number(String(q.get("summary", "")), 3, 8.0)
	actor.q_timer = KitHelpers.cooldown_seconds(q)

func _place_glowworm(actor: Node) -> void:
	if actor.arena == null or not glowworm_charges.spend():
		return
	actor.e_charges = glowworm_charges.charges
	_prune()
	while mines.size() >= MAX_MINES:
		var mine: Node = mines.pop_front()
		if mine != null and is_instance_valid(mine) and mine.has_method("retire"):
			mine.retire()
	var mine = GlowwormMineScript.new()
	actor.arena.add_child(mine)
	var position: Vector2 = actor.global_position + actor.get_aim_direction() * (actor.body_radius + 8.0)
	mine.setup(actor.arena, actor, self, position)
	mines.append(mine)

func _prune() -> void:
	_prune_list(mines)
	_prune_list(fields)
	_prune_list(projectiles)

func _prune_list(list: Array[Node]) -> void:
	for i in range(list.size() - 1, -1, -1):
		if list[i] == null or not is_instance_valid(list[i]):
			list.remove_at(i)
		elif list[i].has_method("is_alive") and not list[i].is_alive():
			list.remove_at(i)

func _retire_all() -> void:
	for list in [mines, fields, projectiles]:
		for node in list:
			if node != null and is_instance_valid(node):
				if node.has_method("retire"):
					node.retire()
				else:
					node.queue_free()
		list.clear()
