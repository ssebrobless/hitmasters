extends Control

const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")
const MinimapBackdropScript := preload("res://scripts/ui/minimap_backdrop.gd")

const MAP_WIDTH := 232.0
const BOSS_CLAIM_DURATION_HINT := 5.0

var arena: Node = null
var redraw_accumulator: float = 0.0
var static_backdrop: Control = null
var view_team: int = 0  # local player's team; enemy pips are fog-gated to this team (BB-VIS-2)

func _ready() -> void:
	_ensure_static_backdrop()

func _process(delta: float) -> void:
	# 8 Hz is plenty for a minimap.
	redraw_accumulator += delta
	if redraw_accumulator >= 0.125:
		redraw_accumulator = 0.0
		queue_redraw()

func has_static_backdrop() -> bool:
	return static_backdrop != null and is_instance_valid(static_backdrop)

func _draw() -> void:
	if arena == null or not is_instance_valid(arena):
		return
	_ensure_static_backdrop()
	var world: Rect2 = arena.arena_rect
	if world.size.x <= 0.0:
		return
	var map_scale: float = MAP_WIDTH / world.size.x
	var map_size: Vector2 = world.size * map_scale
	if arena.player != null and is_instance_valid(arena.player) and ("team" in arena.player):
		view_team = int(arena.player.team)
	_draw_animal_zone_overlays(world, map_scale)
	_draw_food_overlays(world, map_scale)

	for hut: Node in arena.huts:
		if hut == null or not is_instance_valid(hut):
			continue
		var hut_point: Vector2 = (hut.global_position - world.position) * map_scale
		var hut_color: Color = VisualGrammar.team_color(hut.team)
		var hp_ratio: float = clampf(hut.health / hut.max_health, 0.0, 1.0) if hut.max_health > 0.0 else 0.0
		VisualGrammar.draw_minimap_symbol(self, hut_point, VisualGrammar.ICON_HUT, 5.0, hut_color.darkened(0.1) if hut.is_alive() else Color(0.18, 0.16, 0.13))
		draw_arc(hut_point, 5.6, -PI * 0.5, -PI * 0.5 + TAU * hp_ratio, 16, hut_color, 1.5)
		if not hut.is_alive():
			draw_line(hut_point + Vector2(-3.5, -3.5), hut_point + Vector2(3.5, 3.5), Color(0.95, 0.72, 0.45), 1.4)
			draw_line(hut_point + Vector2(-3.5, 3.5), hut_point + Vector2(3.5, -3.5), Color(0.95, 0.72, 0.45), 1.4)

	for core_team: int in arena.cores.keys():
		var core: Node = arena.cores[core_team]
		if core != null and is_instance_valid(core):
			var core_point: Vector2 = (core.global_position - world.position) * map_scale
			VisualGrammar.draw_minimap_symbol(self, core_point, VisualGrammar.ICON_CORE, 5.0, VisualGrammar.team_color(core.team))
			var hp_ratio: float = clampf(core.health / core.max_health, 0.0, 1.0) if core.max_health > 0.0 else 0.0
			draw_arc(core_point, 6.4, -PI * 0.5, -PI * 0.5 + TAU * hp_ratio, 18, VisualGrammar.team_color(core.team), 1.4)

	for entity: Node in arena.entities:
		if not _is_visible_entity(entity):
			continue
		if _squad_index(entity) >= 0:
			continue
		if _is_fog_gated_enemy(entity):
			_draw_fogged_enemy(entity, world, map_scale)
			continue
		var point: Vector2 = (entity.global_position - world.position) * map_scale
		_draw_entity_icon(entity, point)

	if arena.player != null and is_instance_valid(arena.player):
		var player_point: Vector2 = (arena.player.global_position - world.position) * map_scale
		if arena.has_method("get_squad_follow_radius") and String(arena.get("squad_command")) in ["follow", "aggro"]:
			var command_color := VisualGrammar.command_color(String(arena.get("squad_command")), 0.38)
			draw_arc(player_point, arena.get_squad_follow_radius() * map_scale, 0.0, TAU, 24, command_color, 1.0)
		if arena.get("player_squad") != null:
			for i: int in arena.player_squad.size():
				var member: Node = arena.player_squad[i]
				if not _is_visible_entity(member):
					continue
				var member_point: Vector2 = (member.global_position - world.position) * map_scale
				var active: bool = member == arena.player
				var member_color: Color = VisualGrammar.team_color(member.team)
				VisualGrammar.draw_minimap_symbol(self, member_point, VisualGrammar.ICON_PLAYER if active else VisualGrammar.ICON_ACTOR, 4.0 if active else 3.2, member_color, Color(1.0, 1.0, 1.0, 0.85 if active else 0.55))
				draw_string(ThemeDB.fallback_font, member_point + Vector2(4.2, 4.2), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color(1.0, 1.0, 1.0, 0.9))
		var viewport_world: Vector2 = get_viewport_rect().size / _camera_zoom()
		var camera_center: Vector2 = _camera_center()
		var view_rect := Rect2((camera_center - viewport_world * 0.5 - world.position) * map_scale, viewport_world * map_scale)
		draw_rect(view_rect.intersection(Rect2(Vector2.ZERO, map_size)), Color(1.0, 1.0, 1.0, 0.35), false, 1.0)

	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.5, 0.55, 0.45, 0.7), false, 1.5)

func _ensure_static_backdrop() -> void:
	if has_static_backdrop():
		return
	static_backdrop = MinimapBackdropScript.new()
	static_backdrop.name = "StaticBackdrop"
	static_backdrop.set("arena", arena)
	static_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_backdrop.show_behind_parent = true
	add_child(static_backdrop)

func _draw_animal_zone_overlays(world: Rect2, map_scale: float) -> void:
	if arena == null or arena.get("animal_zone_states") == null:
		return
	for zone: Dictionary in arena.get("animal_zone_states"):
		var center: Vector2 = (zone.get("center", Vector2.ZERO) - world.position) * map_scale
		var radius: Vector2 = zone.get("radius", Vector2.ZERO) * map_scale
		if radius.x <= 0.0 or radius.y <= 0.0:
			continue
		var active := bool(zone.get("active", false))
		var boss := bool(zone.get("boss", false))
		var contested := bool(zone.get("contested", false))
		var color := _minimap_zone_color(zone, active, boss, contested)
		var control_team := int(zone.get("control_team", -1))
		var zone_width := 1.6 if contested or control_team >= 0 else 1.2 if active else 0.8
		_draw_minimap_ellipse(center, radius, Color(color.r, color.g, color.b, 0.06 if active else 0.025), color, zone_width)
		if boss:
			_draw_minimap_ellipse(center, radius * 0.66, Color(0.0, 0.0, 0.0, 0.0), Color(color.r, color.g, color.b, color.a * 0.72), 0.9)
			_draw_boss_zone_marker(zone, center, radius, color)
		else:
			_draw_animal_zone_progress_marks(zone, center, radius, color)

func _draw_food_overlays(world: Rect2, map_scale: float) -> void:
	if arena == null or arena.get("food_sources") == null:
		return
	for food: Node in arena.get("food_sources"):
		if food == null or not is_instance_valid(food):
			continue
		var point: Vector2 = (food.global_position - world.position) * map_scale
		var kind: String = String(food.get("kind"))
		if kind == "plant":
			var plant_type: String = String(food.get("plant_type"))
			var color := VisualGrammar.harvestable_color("berry_leaf", 0.78)
			var radius: float = 1.4
			match plant_type:
				"tree":
					color = VisualGrammar.harvestable_color("tree_canopy", 0.84)
					radius = 1.8
				"berry":
					color = VisualGrammar.harvestable_color("berry_fruit", 0.82)
				"seed":
					color = VisualGrammar.harvestable_color("seed_marker", 0.78)
				"flower":
					color = VisualGrammar.harvestable_color("flower_petal", 0.82)
			draw_circle(point, radius + 0.8, VisualGrammar.shadow_color(0.72))
			draw_circle(point, radius, color)
		elif kind == "critter":
			draw_circle(point, 1.5, VisualGrammar.harvestable_color("critter_belly", 0.78))

func _minimap_zone_color(zone: Dictionary, active: bool, boss: bool, contested: bool) -> Color:
	if contested:
		return VisualGrammar.ecology_zone_color("contested", 0.78)
	if boss:
		return VisualGrammar.ecology_zone_color("boss_active", 0.76) if active else VisualGrammar.ecology_zone_color("boss_dormant", 0.42)
	var control_team := int(zone.get("control_team", -1))
	if control_team == 0:
		return VisualGrammar.ecology_zone_color("blue_control", 0.7)
	if control_team == 1:
		return VisualGrammar.ecology_zone_color("red_control", 0.7)
	if String(zone.get("side", "")) == "blue":
		return VisualGrammar.ecology_zone_color("blue_side", 0.62)
	return VisualGrammar.ecology_zone_color("red_side", 0.62)

static func animal_zone_minimap_state(zone: Dictionary) -> Dictionary:
	if bool(zone.get("boss", false)):
		var objective_state := String(zone.get("objective_state", "dormant"))
		var active := bool(zone.get("active", false))
		var claim_progress := float(zone.get("claim_progress", 0.0))
		var visible := active or objective_state in ["active", "claimable", "contesting", "claimed", "stolen"]
		var family := String(zone.get("boss_family", ""))
		return {
			"visible": visible,
			"objective_state": objective_state,
			"boss": true,
			"center_boss": bool(zone.get("center_boss", false)),
			"active": active,
			"family": family,
			"label": boss_family_minimap_code(family),
			"action": _boss_minimap_action(objective_state, active),
			"progress_mark_count": 0,
			"progress_mark_total": 0,
			"claim_progress": claim_progress,
			"claim_ratio": clampf(claim_progress / BOSS_CLAIM_DURATION_HINT, 0.0, 1.0),
			"contested": bool(zone.get("contested", false)),
			"control_team": int(zone.get("control_team", -1)),
			"claim_team": int(zone.get("claim_team", -1)),
			"claimed_team": int(zone.get("claimed_team", -1))
		}
	var active := bool(zone.get("active", false))
	var spawned_count := maxi(int(zone.get("spawned_count", 0)), int((zone.get("occupants", []) as Array).size()))
	var alive_count := int(zone.get("alive_count", spawned_count if active else 0))
	if spawned_count <= 0:
		spawned_count = alive_count
	return {
		"visible": active or spawned_count > 0,
		"progress_mark_count": clampi(alive_count, 0, spawned_count),
		"progress_mark_total": maxi(spawned_count, 0),
		"contested": bool(zone.get("contested", false)),
		"control_team": int(zone.get("control_team", -1))
	}

static func boss_family_minimap_code(family: String) -> String:
	match family:
		"champsosaurus":
			return "CH"
		"platyhystrix":
			return "PL"
		"mastodon":
			return "MA"
		"arthropleura":
			return "AR"
		"teratornis":
			return "TE"
	return "BOSS"

static func _boss_minimap_action(objective_state: String, active: bool) -> String:
	match objective_state:
		"active":
			return "fight"
		"claimable":
			return "claim"
		"contesting":
			return "contest"
		"claimed", "stolen":
			return "claimed"
	return "fight" if active else "wait"

func _draw_animal_zone_progress_marks(zone: Dictionary, center: Vector2, radius: Vector2, color: Color) -> void:
	var state := animal_zone_minimap_state(zone)
	if not bool(state.get("visible", false)):
		return
	var total := int(state.get("progress_mark_total", 0))
	var alive := int(state.get("progress_mark_count", 0))
	if total <= 0:
		return
	var count := mini(total, 8)
	var defeated_color := VisualGrammar.shadow_color(0.58)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var point := center + Vector2(lerpf(-radius.x * 0.5, radius.x * 0.5, t), radius.y * 0.54)
		var occupant_index := int(floor(float(i) * float(total) / float(count)))
		var mark_color := Color(color.r, color.g, color.b, 0.82) if occupant_index < alive else defeated_color
		draw_circle(point, 1.25, mark_color)

func _draw_boss_zone_marker(zone: Dictionary, center: Vector2, radius: Vector2, color: Color) -> void:
	var state := animal_zone_minimap_state(zone)
	if not bool(state.get("visible", false)):
		return
	var label := "CTR" if bool(state.get("center_boss", false)) else String(state.get("label", "BOSS"))
	var action := _boss_action_label(String(state.get("action", "wait")))
	var text := label if action.is_empty() else "%s %s" % [label, action]
	var label_width := 44.0 if bool(state.get("center_boss", false)) else 38.0
	var label_pos := center + Vector2(-label_width * 0.5, -4.0)
	draw_rect(Rect2(label_pos + Vector2(-1.5, -6.5), Vector2(label_width + 3.0, 9.0)), VisualGrammar.shadow_color(0.58), true)
	draw_string(ThemeDB.fallback_font, label_pos, text, HORIZONTAL_ALIGNMENT_CENTER, label_width, 8, Color(color.r, color.g, color.b, 0.96))
	var claim_ratio := float(state.get("claim_ratio", 0.0))
	if String(state.get("action", "")) in ["claim", "contest"] and claim_ratio > 0.0:
		var arc_radius := maxf(minf(radius.x, radius.y) * 0.38, 3.0)
		var arc_color := VisualGrammar.ecology_zone_color("contested", 0.9) if bool(state.get("contested", false)) else color
		draw_arc(center, arc_radius, -PI * 0.5, -PI * 0.5 + TAU * claim_ratio, 20, arc_color, 1.7)

func _boss_action_label(action: String) -> String:
	match action:
		"fight":
			return "FIGHT"
		"claim":
			return "CLAIM"
		"contest":
			return "HOLD"
	return ""

func _draw_minimap_ellipse(center: Vector2, radius: Vector2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps: int = 28
	for i: int in steps:
		var angle: float = TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	for i: int in steps:
		draw_line(points[i], points[(i + 1) % steps], outline, width)

# An enemy mobile unit (creature or minion) whose position must be fog-gated to view_team.
# Structures (huts/cores), neutral wildlife/objectives, and own units are NOT gated (#36).
func _is_fog_gated_enemy(entity: Node) -> bool:
	if arena == null or not arena.has_method("is_entity_visible_to_team"):
		return false
	if not ("team" in entity):
		return false
	var team := int(entity.get("team"))
	if team < 0 or team == view_team:
		return false
	if entity.has_method("is_scored_actor") and entity.is_scored_actor():
		return true
	return _script_name(entity) == "minion.gd"

func _draw_fogged_enemy(entity: Node, world: Rect2, map_scale: float) -> void:
	var state := String(arena.get_entity_info_state(entity, view_team))
	if state == "visible" or state == "revealed":
		_draw_entity_icon(entity, (entity.global_position - world.position) * map_scale)
		return
	# Out of direct sight: surface a coarse ghost / ripple from the last-known point only.
	var last_point: Vector2 = arena.get_last_known_point(view_team, entity)
	if last_point == Vector2.INF:
		return  # never seen: no marker (suspected/hidden reveal nothing)
	var point: Vector2 = (last_point - world.position) * map_scale
	var color: Color = VisualGrammar.team_color(_node_team(entity))
	if state == "last_known":
		VisualGrammar.draw_minimap_symbol(self, point, VisualGrammar.ICON_ACTOR, 3.2, VisualGrammar.with_alpha(color, 0.4), Color(1.0, 1.0, 1.0, 0.14))
	elif state == "heard":
		draw_arc(point, 3.4, 0.0, TAU, 18, VisualGrammar.with_alpha(color, 0.5), 1.0)

func _draw_entity_icon(entity: Node, point: Vector2) -> void:
	var team: int = _node_team(entity)
	var color: Color = VisualGrammar.team_color(team)
	var script_name: String = _script_name(entity)
	if script_name == "minion.gd":
		var direction: Vector2 = Vector2.RIGHT if team == 0 else Vector2.LEFT
		var radius: float = 3.4 if String(entity.get("kind")) == "tank" else 2.7
		VisualGrammar.draw_minimap_symbol(self, point, VisualGrammar.ICON_MINION, radius, color.darkened(0.05), Color(0.03, 0.035, 0.03, 0.85), direction)
		return
	if script_name == "dam.gd":
		VisualGrammar.draw_minimap_symbol(self, point, VisualGrammar.ICON_OBJECT, 3.4, Color(0.62, 0.45, 0.22), VisualGrammar.team_color(team, 0.65))
		return
	if entity.has_method("is_scored_actor") and entity.is_scored_actor():
		VisualGrammar.draw_minimap_symbol(self, point, VisualGrammar.ICON_ACTOR, 3.6, color, Color(1.0, 1.0, 1.0, 0.38))
		return
	VisualGrammar.draw_minimap_symbol(self, point, "circle", 1.8, VisualGrammar.with_alpha(color, 0.85), Color(0.03, 0.035, 0.03, 0.75))

func _camera_center() -> Vector2:
	var camera_node: Camera2D = arena.get("camera")
	if camera_node != null and is_instance_valid(camera_node):
		if camera_node.has_method("get_screen_center_position"):
			return camera_node.get_screen_center_position()
		return arena.player.global_position + camera_node.offset
	return arena.player.global_position

func _camera_zoom() -> Vector2:
	var camera_node: Camera2D = arena.get("camera")
	if camera_node != null and is_instance_valid(camera_node):
		return camera_node.zoom
	return arena.camera_zoom

func _is_visible_entity(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity.has_method("is_alive") and not entity.is_alive():
		return false
	return true

func _squad_index(entity: Node) -> int:
	if entity == null or arena.get("player_squad") == null:
		return -1
	for i: int in arena.player_squad.size():
		if arena.player_squad[i] == entity:
			return i
	return -1

func _node_team(node: Node) -> int:
	var value: Variant = node.get("team")
	return int(value) if value != null else 0

func _script_name(node: Node) -> String:
	var script: Script = node.get_script()
	if script == null:
		return ""
	return String(script.resource_path).get_file()
