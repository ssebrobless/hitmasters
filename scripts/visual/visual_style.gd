extends RefCounted

static func team_color(team: int) -> Color:
	return Color(0.25, 0.65, 1.0) if team == 0 else Color(1.0, 0.28, 0.25)

static func creature_color(creature_id: String) -> Color:
	var creature_hash: int = abs(hash(creature_id))
	var hue := float(creature_hash % 360) / 360.0
	return Color.from_hsv(hue, 0.58, 0.92)

static func draw_pixel_hero(canvas: CanvasItem, creature_id: String, team: int, pixel_size := 5.0, alpha := 1.0) -> void:
	draw_pixel_creature(canvas, creature_id, team, pixel_size, alpha)

static func draw_pixel_creature(canvas: CanvasItem, creature_id: String, team: int, pixel_size := 5.0, alpha := 1.0) -> void:
	var team_col := _with_alpha(team_color(team), alpha)
	var main_col := _with_alpha(creature_color(creature_id), alpha)
	var dark_col := _with_alpha(Color(0.03, 0.035, 0.045), alpha)
	var bright_col := _with_alpha(main_col.lightened(0.28), alpha)
	_draw_cells(canvas, _outline_cells(creature_id), pixel_size, dark_col)
	_draw_cells(canvas, _body_cells(creature_id), pixel_size, main_col)
	_draw_cells(canvas, _highlight_cells(creature_id), pixel_size, bright_col)
	_draw_cells(canvas, [Vector2i(2, 3), Vector2i(5, 3)], pixel_size, team_col)

static func draw_pixel_minion(canvas: CanvasItem, team: int, pixel_size := 4.0, alpha := 1.0) -> void:
	var team_col := _with_alpha(team_color(team), alpha)
	var dark_col := _with_alpha(Color(0.04, 0.045, 0.05), alpha)
	var body_cells := [
		Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(2, 4), Vector2i(3, 4)
	]
	var outline_cells := [
		Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(0, 2), Vector2i(5, 2),
		Vector2i(0, 3), Vector2i(5, 3),
		Vector2i(1, 5), Vector2i(4, 5)
	]
	_draw_cells(canvas, outline_cells, pixel_size, dark_col, Vector2(3.0, 3.0))
	_draw_cells(canvas, body_cells, pixel_size, team_col, Vector2(3.0, 3.0))
	_draw_cells(canvas, [Vector2i(4, 1), Vector2i(5, 1)], pixel_size, _with_alpha(Color(0.85, 0.9, 0.95), alpha), Vector2(3.0, 3.0))

static func draw_pixel_core(canvas: CanvasItem, team: int, pixel_size := 8.0, alpha := 1.0) -> void:
	var team_col := _with_alpha(team_color(team), alpha)
	var dark_col := _with_alpha(Color(0.04, 0.045, 0.055), alpha)
	var core_col := _with_alpha(team_col.darkened(0.12), alpha)
	var glow_col := _with_alpha(team_col.lightened(0.3), alpha)
	for y in range(12):
		for x in range(12):
			if x == 0 or x == 11 or y == 0 or y == 11:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, dark_col, Vector2(6.0, 6.0))
			elif x in [2, 3, 8, 9] or y in [2, 3, 8, 9]:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, core_col, Vector2(6.0, 6.0))
			elif x >= 4 and x <= 7 and y >= 4 and y <= 7:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, glow_col, Vector2(6.0, 6.0))

static func draw_pixel_projectile(canvas: CanvasItem, color: Color, radius: float) -> void:
	var dark_col := Color(0.04, 0.04, 0.045, color.a)
	var size := maxf(radius * 1.3, 7.0)
	canvas.draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)), dark_col)
	canvas.draw_rect(Rect2(Vector2(-size * 0.5 + 2.0, -size * 0.5 + 2.0), Vector2(size - 4.0, size - 4.0)), color)
	canvas.draw_rect(Rect2(Vector2(0.0, -size * 0.5 + 2.0), Vector2(size * 0.8, size - 4.0)), color.lightened(0.25))

static func _outline_cells(creature_id: String) -> Array:
	if creature_id.contains("frog") or creature_id.contains("turtle"):
		return _rect_cells(1, 1, 6, 5) + [Vector2i(0, 3), Vector2i(7, 3)]
	if creature_id.contains("mink"):
		return _rect_cells(1, 2, 7, 3) + [Vector2i(0, 3), Vector2i(8, 3), Vector2i(2, 1)]
	return _rect_cells(1, 1, 6, 6)

static func _body_cells(creature_id: String) -> Array:
	if creature_id.contains("mink"):
		return _rect_cells(2, 2, 5, 3) + [Vector2i(7, 3)]
	return _rect_cells(2, 2, 4, 3) + [Vector2i(1, 3), Vector2i(6, 3)]

static func _highlight_cells(creature_id: String) -> Array:
	if creature_id.contains("turtle"):
		return [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]
	if creature_id.contains("frog"):
		return [Vector2i(5, 1), Vector2i(6, 1), Vector2i(6, 2)]
	return [Vector2i(6, 2), Vector2i(7, 3)]

static func _rect_cells(x: int, y: int, width: int, height: int) -> Array:
	var cells: Array = []
	for cy in range(y, y + height):
		for cx in range(x, x + width):
			cells.append(Vector2i(cx, cy))
	return cells

static func _draw_cells(canvas: CanvasItem, cells: Array, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	for cell in cells:
		_draw_cell(canvas, cell, pixel_size, color, origin)

static func _draw_cell(canvas: CanvasItem, cell: Vector2i, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	var position := Vector2((float(cell.x) - origin.x) * pixel_size, (float(cell.y) - origin.y) * pixel_size)
	canvas.draw_rect(Rect2(position, Vector2(pixel_size, pixel_size)), color)

static func _with_alpha(color: Color, alpha: float) -> Color:
	var output := color
	output.a *= alpha
	return output
