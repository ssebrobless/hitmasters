extends Node2D

# Mud hut: lane structure. Spawns lane minion waves (driven by the arena) and
# maintains a 5-minion defender squad (1 tanky, 2 melee, 2 pebble-throwers)
# that respawns 5 s after death. Does not attack. Registered as an arena
# entity so it can be damaged.

signal hut_destroyed(hut)

const MinionScript := preload("res://scripts/game/minion.gd")

const DEFENDER_RESPAWN_SEC := 5.0
const DEFENDER_KINDS := ["tank", "melee", "melee", "pebble", "pebble"]

var arena: Node = null
var team := 0
var lane_index := 0
var max_health := 800.0
var health := 800.0
var body_radius := 30.0
var respawn_queue: Array[Dictionary] = []
var defenders: Array[Node] = []

func setup(hut_arena: Node, hut_team: int, hut_lane: int, hut_position: Vector2) -> void:
	arena = hut_arena
	team = hut_team
	lane_index = hut_lane
	global_position = hut_position
	health = max_health
	for i in DEFENDER_KINDS.size():
		_spawn_defender(String(DEFENDER_KINDS[i]), i)

func is_alive() -> bool:
	return health > 0.0

func is_scored_actor() -> bool:
	return false

func get_actor_name() -> String:
	return "%s Hut" % ("Blue" if team == 0 else "Red")

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	queue_redraw()
	if health <= 0.0:
		_destroyed()

func take_damage_event(event: Resource) -> void:
	take_damage(event.amount, -1, event.source_actor)

func _destroyed() -> void:
	for defender in defenders:
		if defender != null and is_instance_valid(defender):
			defender.leash_hut = null
	if arena != null:
		arena.unregister_entity(self)
		if arena.has_method("on_hut_destroyed"):
			arena.on_hut_destroyed(self)
	hut_destroyed.emit(self)
	queue_free()

func on_defender_died(kind: String, slot: int) -> void:
	if health <= 0.0:
		return
	respawn_queue.append({"kind": kind, "slot": slot, "remaining": DEFENDER_RESPAWN_SEC})

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return
	for i in range(respawn_queue.size() - 1, -1, -1):
		respawn_queue[i]["remaining"] = float(respawn_queue[i]["remaining"]) - delta
		if float(respawn_queue[i]["remaining"]) <= 0.0:
			_spawn_defender(String(respawn_queue[i]["kind"]), int(respawn_queue[i]["slot"]))
			respawn_queue.remove_at(i)

func _spawn_defender(kind: String, slot: int) -> void:
	if arena == null:
		return
	var angle := TAU * float(slot) / 5.0
	var minion = MinionScript.new()
	arena.add_child(minion)
	minion.setup(arena, team, global_position + Vector2(cos(angle), sin(angle)) * 52.0, kind, Vector2.ZERO, self, slot)
	arena.register_entity(minion)
	if arena.has_method("track_minion"):
		arena.track_minion(minion)
	defenders.append(minion)
	for i in range(defenders.size() - 1, -1, -1):
		if defenders[i] == null or not is_instance_valid(defenders[i]):
			defenders.remove_at(i)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var mud := Color(0.42, 0.3, 0.18)
	var mud_dark := Color(0.28, 0.2, 0.12)
	var accent := Color(0.25, 0.65, 1.0) if team == 0 else Color(1.0, 0.28, 0.25)
	# Dome of packed mud with stick reinforcements.
	draw_circle(Vector2.ZERO, body_radius + 4.0, mud_dark)
	draw_circle(Vector2.ZERO, body_radius, mud)
	draw_circle(Vector2(0.0, -body_radius * 0.25), body_radius * 0.6, mud.lightened(0.1))
	for i in 7:
		var stick_angle := TAU * float(i) / 7.0 + 0.3
		var stick_out := Vector2(cos(stick_angle), sin(stick_angle))
		draw_line(stick_out * body_radius * 0.55, stick_out * (body_radius + 6.0), mud_dark.darkened(0.15), 2.5)
	# Entrance facing mid.
	var entrance := Vector2(-1.0 if team == 1 else 1.0, 0.0)
	draw_circle(entrance * body_radius * 0.62, body_radius * 0.3, Color(0.12, 0.08, 0.05))
	# Team banner.
	draw_rect(Rect2(Vector2(-2.0, -body_radius - 16.0), Vector2(4.0, 12.0)), mud_dark)
	draw_rect(Rect2(Vector2(2.0, -body_radius - 16.0), Vector2(10.0, 7.0)), accent)
	# Health bar.
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-body_radius, body_radius + 6.0), Vector2(body_radius * 2.0, 5.0)), Color(0.07, 0.07, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, body_radius + 6.0), Vector2(body_radius * 2.0 * ratio, 5.0)), accent)
