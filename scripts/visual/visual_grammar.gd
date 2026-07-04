extends RefCounted

const ICON_PLAYER := "player"
const ICON_ACTOR := "actor"
const ICON_MINION := "minion"
const ICON_HUT := "hut"
const ICON_CORE := "core"
const ICON_OBJECT := "object"

static func team_color(team: int, alpha := 1.0) -> Color:
	var color := Color(0.25, 0.65, 1.0) if team == 0 else Color(1.0, 0.28, 0.25)
	color.a = alpha
	return color

static func command_color(command: String, alpha := 1.0) -> Color:
	match command:
		"follow":
			return Color(0.45, 0.8, 1.0, alpha)
		"aggro":
			return Color(1.0, 0.66, 0.22, alpha)
		"farm":
			return Color(0.38, 0.9, 0.48, alpha)
		_:
			return Color(1.0, 1.0, 1.0, alpha)

static func with_alpha(color: Color, alpha: float) -> Color:
	var output := color
	output.a *= alpha
	return output

static func draw_minimap_symbol(canvas: CanvasItem, center: Vector2, symbol: String, radius: float, color: Color, outline := Color(0.03, 0.035, 0.035, 0.95), facing := Vector2.RIGHT) -> void:
	if symbol == ICON_PLAYER:
		canvas.draw_circle(center, radius + 1.8, outline)
		canvas.draw_circle(center, radius, color)
		canvas.draw_arc(center, radius + 2.8, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.85), 1.2)
		return
	if symbol == "circle":
		canvas.draw_circle(center, radius + 1.2, outline)
		canvas.draw_circle(center, radius, color)
		return

	var outline_points := _offset_points(_symbol_points(symbol, radius + 1.5, facing), center)
	if outline_points.size() >= 3 and outline.a > 0.0:
		canvas.draw_colored_polygon(outline_points, outline)
	var points := _offset_points(_symbol_points(symbol, radius, facing), center)
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)

static func _symbol_points(symbol: String, radius: float, facing: Vector2) -> PackedVector2Array:
	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	match symbol:
		ICON_MINION:
			return PackedVector2Array([
				forward * radius,
				-forward * radius * 0.75 + side * radius * 0.68,
				-forward * radius * 0.75 - side * radius * 0.68
			])
		ICON_HUT:
			return PackedVector2Array([
				Vector2(0.0, -radius),
				Vector2(radius, -radius * 0.18),
				Vector2(radius * 0.72, radius),
				Vector2(-radius * 0.72, radius),
				Vector2(-radius, -radius * 0.18)
			])
		ICON_CORE:
			return PackedVector2Array([
				Vector2(0.0, -radius),
				Vector2(radius * 0.62, -radius * 0.62),
				Vector2(radius, 0.0),
				Vector2(radius * 0.62, radius * 0.62),
				Vector2(0.0, radius),
				Vector2(-radius * 0.62, radius * 0.62),
				Vector2(-radius, 0.0),
				Vector2(-radius * 0.62, -radius * 0.62)
			])
		ICON_OBJECT:
			return PackedVector2Array([
				Vector2(-radius * 0.72, -radius),
				Vector2(radius * 0.72, -radius),
				Vector2(radius * 0.72, radius),
				Vector2(-radius * 0.72, radius)
			])
		_:
			return PackedVector2Array([
				Vector2(0.0, -radius),
				Vector2(radius, 0.0),
				Vector2(0.0, radius),
				Vector2(-radius, 0.0)
			])

static func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:
		shifted.append(point + offset)
	return shifted
