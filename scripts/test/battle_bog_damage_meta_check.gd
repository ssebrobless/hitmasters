extends SceneTree

const CreatureCatalogScript := preload("res://scripts/data/creature_catalog.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Projectile := preload("res://scripts/sim/abilities/projectile.gd")

class FakeArena:
	extends Node
	var entities: Array[Node] = []
	var cores := {}
	var vfx_events: Array[Dictionary] = []
	var terrain := TerrainMapScript.new()

	func _init() -> void:
		terrain.configure("3v3")

	func add_actor(actor: Node) -> void:
		add_child(actor)
		entities.append(actor)

	func get_terrain_zone(point: Vector2) -> String:
		return terrain.get_zone_at(point)

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func record_vfx_event(event: Dictionary) -> void:
		vfx_events.append(event.duplicate())

	func record_death(_victim: Node, _killer: Node = null) -> void:
		pass

func _initialize() -> void:
	_ensure_catalog()
	var failures: Array[String] = []
	_check_metadata_from_melee(failures)
	_check_metadata_from_line(failures)
	_check_region_multiplier(failures)
	_check_render_hitstop(failures)
	print("damage_meta failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _ensure_catalog() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null:
		catalog = CreatureCatalogScript.new()
		catalog.name = "CreatureCatalog"
		get_root().add_child(catalog)
	catalog.load_catalog()

func _check_metadata_from_melee(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "bullfrog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 24.0)
	MeleeHit.hit(actor, 40.0, 10.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Meta Bite")
	var event := _last_hit(arena)
	if event.is_empty() or not _has_hit_meta(event):
		failures.append("melee hit should populate hit_position/hit_normal/region; event=%s" % str(event))
	arena.queue_free()

func _check_metadata_from_line(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "chorus_frog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 60.0)
	Projectile.instant_line(actor, 100.0, 10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Meta Tongue", {"half_width_px": 8.0})
	var event := _last_hit(arena)
	if target.health >= target.max_health or event.is_empty() or not _has_hit_meta(event):
		failures.append("line hit should damage target and populate hit metadata; health=%.2f event=%s" % [target.health, str(event)])
	arena.queue_free()

func _check_region_multiplier(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "bullfrog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 40.0)
	var before: float = target.health
	var event: Resource = actor.make_damage_event(10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Region Probe")
	event.set_hit(target.global_position, Vector2.LEFT, "hull", 1.35)
	target.take_damage_event(event)
	var loss: float = before - target.health
	if absf(loss - 13.5) > 0.01:
		failures.append("region_mult should scale incoming damage; loss=%.2f" % loss)
	arena.queue_free()

func _check_render_hitstop(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "bullfrog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 48.0)
	actor.anim_attack_timer = 0.20
	target.anim_attack_timer = 0.20
	target.velocity = Vector2.RIGHT * 120.0
	var event: Resource = actor.make_damage_event(60.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Heavy Meta")
	event.set_hit(target.global_position, Vector2.LEFT)
	target.take_damage_event(event)
	var both_stopped: bool = actor.render_hitstop_timer > 0.0 and target.render_hitstop_timer > 0.0
	var frozen_before: float = target.anim_attack_timer
	target._process(0.01)
	var render_frozen: bool = absf(target.anim_attack_timer - frozen_before) < 0.0001 and target.render_hitstop_timer > 0.0
	target.set_input_frame(_frame(Vector2.RIGHT))
	var before_pos: Vector2 = target.global_position
	target.tick_sim(0.10)
	var sim_advanced: bool = target.global_position.distance_to(before_pos) > 0.1
	if not both_stopped or not render_frozen or not sim_advanced:
		failures.append("heavy hitstop should freeze render timers only; both=%s frozen=%s sim=%s timers=%.3f/%.3f pos_delta=%.2f" % [
			str(both_stopped),
			str(render_frozen),
			str(sim_advanced),
			actor.render_hitstop_timer,
			target.render_hitstop_timer,
			target.global_position.distance_to(before_pos)
		])
	arena.queue_free()

func _has_hit_meta(event: Dictionary) -> bool:
	var hit_position: Vector2 = event.get("hit_position", Vector2.ZERO)
	var hit_normal: Vector2 = event.get("hit_normal", Vector2.ZERO)
	return hit_position != Vector2.ZERO and hit_normal.length() > 0.9 and String(event.get("region", "")) == "hull"

func _last_hit(arena: FakeArena) -> Dictionary:
	for i in range(arena.vfx_events.size() - 1, -1, -1):
		if String(arena.vfx_events[i].get("type", "")) == "hit_landed":
			return arena.vfx_events[i]
	return {}

func _frame(move: Vector2) -> Resource:
	var frame := preload("res://scripts/sim/input_frame.gd").new()
	frame.move = move
	frame.aim = Vector2.RIGHT
	return frame

func _creature(arena: FakeArena, creature_id: String, team: int, position: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_actor(creature)
	creature.setup(arena, team, position, creature_id, arena.terrain)
	creature.global_position = position
	return creature
