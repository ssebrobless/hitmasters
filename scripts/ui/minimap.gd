extends Control

const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

const MAP_WIDTH := 232.0

var arena: Node = null
var redraw_accumulator := 0.0

func _process(delta: float) -> void:
	# 8 Hz is plenty for a minimap.
	redraw_accumulator += delta
	if redraw_accumulator >= 0.125:
		redraw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	if arena == null or not is_instance_valid(arena):
		return
	var world: Rect2 = arena.arena_rect
	if world.size.x <= 0.0:
		return
	var map_scale := MAP_WIDTH / world.size.x
	var map_size := world.size * map_scale
	draw_rect(Rect2(Vector2.ZERO, map_size).grow(3.0), Color(0.03, 0.04, 0.03, 0.9))
	for layer in arena.terrain_map.zone_layers:
		var zone := String(layer["zone"])
		for rect: Rect2 in layer["rects"]:
			var mini := Rect2((rect.position - world.position) * map_scale, rect.size * map_scale)
			draw_rect(mini, VisualGrammar.terrain_color(zone, 1.0, true))

	for hut in arena.huts:
		if hut == null or not is_instance_valid(hut):
			continue
		var hut_point: Vector2 = (hut.global_position - world.position) * map_scale
		var hut_color: Color = VisualGrammar.team_color(hut.team)
		var hp_ratio := clampf(hut.health / hut.max_health, 0.0, 1.0) if hut.max_health > 0.0 else 0.0
		VisualGrammar.draw_minimap_symbol(self, hut_point, VisualGrammar.ICON_HUT, 5.0, hut_color.darkened(0.1) if hut.is_alive() else Color(0.18, 0.16, 0.13))
		draw_arc(hut_point, 5.6, -PI * 0.5, -PI * 0.5 + TAU * hp_ratio, 16, hut_color, 1.5)
		if not hut.is_alive():
			draw_line(hut_point + Vector2(-3.5, -3.5), hut_point + Vector2(3.5, 3.5), Color(0.95, 0.72, 0.45), 1.4)
			draw_line(hut_point + Vector2(-3.5, 3.5), hut_point + Vector2(3.5, -3.5), Color(0.95, 0.72, 0.45), 1.4)

	for core_team in arena.cores.keys():
		var core = arena.cores[core_team]
		if core != null and is_instance_valid(core):
			var core_point: Vector2 = (core.global_position - world.position) * map_scale
			VisualGrammar.draw_minimap_symbol(self, core_point, VisualGrammar.ICON_CORE, 5.0, VisualGrammar.team_color(core.team))
			var hp_ratio := clampf(core.health / core.max_health, 0.0, 1.0) if core.max_health > 0.0 else 0.0
			draw_arc(core_point, 6.4, -PI * 0.5, -PI * 0.5 + TAU * hp_ratio, 18, VisualGrammar.team_color(core.team), 1.4)

	for entity in arena.entities:
		if not _is_visible_entity(entity):
			continue
		if _squad_index(entity) >= 0:
			continue
		var point: Vector2 = (entity.global_position - world.position) * map_scale
		_draw_entity_icon(entity, point)

	if arena.player != null and is_instance_valid(arena.player):
		var player_point: Vector2 = (arena.player.global_position - world.position) * map_scale
		if arena.has_method("get_squad_follow_radius") and String(arena.get("squad_command")) in ["follow", "aggro"]:
			var command_color := VisualGrammar.command_color(String(arena.get("squad_command")), 0.38)
			draw_arc(player_point, arena.get_squad_follow_radius() * map_scale, 0.0, TAU, 24, command_color, 1.0)
		if arena.get("player_squad") != null:
			for i in arena.player_squad.size():
				var member = arena.player_squad[i]
				if not _is_visible_entity(member):
					continue
				var member_point: Vector2 = (member.global_position - world.position) * map_scale
				var active: bool = member == arena.player
				var member_color := VisualGrammar.team_color(member.team)
				VisualGrammar.draw_minimap_symbol(self, member_point, VisualGrammar.ICON_PLAYER if active else VisualGrammar.ICON_ACTOR, 4.0 if active else 3.2, member_color, Color(1.0, 1.0, 1.0, 0.85 if active else 0.55))
				draw_string(ThemeDB.fallback_font, member_point + Vector2(4.2, 4.2), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color(1.0, 1.0, 1.0, 0.9))
		var viewport_world: Vector2 = get_viewport_rect().size / _camera_zoom()
		var camera_center := _camera_center()
		var view_rect := Rect2((camera_center - viewport_world * 0.5 - world.position) * map_scale, viewport_world * map_scale)
		draw_rect(view_rect.intersection(Rect2(Vector2.ZERO, map_size)), Color(1.0, 1.0, 1.0, 0.35), false, 1.0)

	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.5, 0.55, 0.45, 0.7), false, 1.5)

func _draw_entity_icon(entity: Node, point: Vector2) -> void:
	var team := _node_team(entity)
	var color := VisualGrammar.team_color(team)
	var script_name := _script_name(entity)
	if script_name == "minion.gd":
		var direction := Vector2.RIGHT if team == 0 else Vector2.LEFT
		var radius := 3.4 if String(entity.get("kind")) == "tank" else 2.7
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
	var camera_node = arena.get("camera")
	if camera_node != null and is_instance_valid(camera_node):
		if camera_node.has_method("get_screen_center_position"):
			return camera_node.get_screen_center_position()
		return arena.player.global_position + camera_node.offset
	return arena.player.global_position

func _camera_zoom() -> Vector2:
	var camera_node = arena.get("camera")
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
	for i in arena.player_squad.size():
		if arena.player_squad[i] == entity:
			return i
	return -1

func _node_team(node: Node) -> int:
	var value = node.get("team")
	return int(value) if value != null else 0

func _script_name(node: Node) -> String:
	var script = node.get_script()
	if script == null:
		return ""
	return String(script.resource_path).get_file()
