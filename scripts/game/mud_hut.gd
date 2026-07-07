extends Node2D

# Mud hut: lane structure. Spawns lane minion waves (driven by the arena) and
# maintains a 5-minion defender squad (1 tanky, 2 melee, 2 pebble-throwers)
# that respawns 5 s after death. Does not attack. Registered as an arena
# entity so it can be damaged.

signal hut_destroyed(hut)

const MinionScript := preload("res://scripts/game/minion.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

const DEFENDER_RESPAWN_SEC := 5.0
const DEFENDER_KINDS := ["tank", "melee", "melee", "pebble", "pebble"]

var arena: Node = null
var team := 0
var lane_index := 0
var max_health := 800.0
var health := 800.0
var body_radius := 30.0
var last_damage_source_team := -1
var last_damage_source_actor: Node = null
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

func get_team_accent_color(alpha := 1.0) -> Color:
	return VisualGrammar.team_color(team, alpha)

func uses_event_driven_redraw() -> bool:
	return true

func get_visual_damage_state() -> String:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	if ratio <= 0.0:
		return "destroyed"
	if ratio < 0.34:
		return "critical"
	if ratio < 0.67:
		return "damaged"
	return "intact"

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	if health <= 0.0:
		return
	var previous_health := health
	health = maxf(health - amount, 0.0)
	var actual_damage := previous_health - health
	if actual_damage > 0.0:
		last_damage_source_team = _source_team
		last_damage_source_actor = _source_actor
		if arena != null and arena.has_method("record_hut_damage"):
			arena.record_hut_damage(_source_team, actual_damage, _source_actor)
	queue_redraw()
	if health <= 0.0:
		_destroyed()

func take_damage_event(event: Resource) -> void:
	take_damage(event.amount, -1, event.source_actor)

func _destroyed() -> void:
	# Orphaned defenders join the push down this hut's lane instead of
	# idling at the rubble forever.
	for defender in defenders:
		if defender != null and is_instance_valid(defender):
			defender.leash_hut = null
			defender.kind = "lane"
			defender.march_target = Vector2(-global_position.x, global_position.y)
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

# Static drawing: redraws happen on damage/team events only (perf
# constitution, decision #31) — never per frame.
func _draw() -> void:
	var mud := VisualGrammar.BOG_MUD
	var mud_dark := VisualGrammar.BOG_MUD_DARK
	var state := get_visual_damage_state()
	var accent := get_team_accent_color()
	var shadow_offset := Vector2(body_radius * 0.2, body_radius * 0.28)
	draw_circle(shadow_offset, body_radius * 0.92, VisualGrammar.SHADOW)
	draw_circle(Vector2.ZERO, body_radius + 4.0, mud_dark)
	draw_circle(Vector2.ZERO, body_radius, mud)
	draw_arc(Vector2(body_radius * 0.08, body_radius * 0.05), body_radius * 0.9, -0.05, PI * 0.72, 18, mud_dark.darkened(0.18), 4.0)
	draw_arc(Vector2(-body_radius * 0.18, -body_radius * 0.18), body_radius * 0.7, PI * 1.05, PI * 1.82, 18, mud.lightened(0.18), 4.0)
	for i in 5:
		var arc_radius := body_radius * (0.35 + float(i) * 0.1)
		draw_arc(Vector2(0.0, body_radius * 0.05), arc_radius, PI * 1.05, PI * 1.92, 14, mud_dark.lightened(0.08), 1.2)
	for i in 6:
		var stick_angle := TAU * float(i) / 6.0 + 0.38
		var stick_out := Vector2(cos(stick_angle), sin(stick_angle))
		draw_line(stick_out * body_radius * 0.62, stick_out * (body_radius + 5.0), mud_dark.darkened(0.12), 2.2)
	_draw_damage_marks(state, mud_dark)
	# Entrance facing mid.
	var entrance := Vector2(-1.0 if team == 1 else 1.0, 0.0)
	var entrance_center := entrance * body_radius * 0.58 + Vector2(0.0, body_radius * 0.08)
	draw_circle(entrance_center, body_radius * 0.28, mud_dark.darkened(0.46))
	draw_rect(Rect2(entrance_center + Vector2(-body_radius * 0.28, -body_radius * 0.12), Vector2(body_radius * 0.56, body_radius * 0.12)), mud_dark.lightened(0.12))
	# Team banner.
	draw_rect(Rect2(Vector2(-2.0, -body_radius - 16.0), Vector2(4.0, 12.0)), mud_dark)
	draw_rect(Rect2(Vector2(2.0, -body_radius - 16.0), Vector2(10.0, 7.0)), accent)
	# Health bar.
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-body_radius, body_radius + 6.0), Vector2(body_radius * 2.0, 5.0)), Color(0.07, 0.07, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, body_radius + 6.0), Vector2(body_radius * 2.0 * ratio, 5.0)), accent)

func _draw_damage_marks(state: String, mud_dark: Color) -> void:
	if state == "intact":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(global_position.x), int(global_position.y)))
	var crack_count := 4 if state == "damaged" else 8
	for i in crack_count:
		var angle := rng.randf_range(PI * 0.15, PI * 1.85)
		var start := Vector2(cos(angle), sin(angle)) * rng.randf_range(body_radius * 0.25, body_radius * 0.72)
		var end := start + Vector2(cos(angle + rng.randf_range(-0.8, 0.8)), sin(angle + rng.randf_range(-0.8, 0.8))) * rng.randf_range(5.0, 11.0)
		draw_line(start, end, mud_dark.darkened(0.38), 1.6)
	if state == "critical":
		for i in 4:
			var clod_angle := TAU * float(i) / 4.0 + 0.45
			var clod := Vector2(cos(clod_angle), sin(clod_angle)) * body_radius * rng.randf_range(0.7, 0.98)
			draw_circle(clod, rng.randf_range(3.0, 5.0), mud_dark.darkened(0.18))
