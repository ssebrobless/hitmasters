extends RefCounted

const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

const ICON_PLAYER := "player"
const ICON_ACTOR := "actor"
const ICON_MINION := "minion"
const ICON_HUT := "hut"
const ICON_CORE := "core"
const ICON_OBJECT := "object"

const BOG_LAND_DARK := Color(0.16, 0.19, 0.11)
const BOG_LAND := Color(0.22, 0.26, 0.15)
const BOG_MOSS := Color(0.33, 0.38, 0.21)
const BOG_MUD_DARK := Color(0.19, 0.14, 0.09)
const BOG_MUD := Color(0.33, 0.24, 0.14)
const BOG_REED := Color(0.42, 0.44, 0.24)
const WATER_DEEP := Color(0.07, 0.17, 0.22)
const WATER_SHALLOW := Color(0.16, 0.30, 0.28)
const WATER_FOAM := Color(0.62, 0.70, 0.62, 0.7)
const SHADOW := Color(0.04, 0.05, 0.03, 0.35)

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

static func telegraph_color(kind: String, alpha := 1.0, friendly := true) -> Color:
	match kind:
		"windup":
			return Color(1.0, 0.78, 0.22, alpha)
		"swing":
			return Color(1.0, 0.93, 0.55, alpha)
		"damage":
			return Color(1.0, 0.96, 0.82, alpha)
		"heavy_damage":
			return Color(1.0, 0.62, 0.28, alpha)
		"heal":
			return Color(0.32, 1.0, 0.48, alpha)
		"dash":
			return Color(0.65, 0.95, 1.0, alpha)
		"aura":
			return Color(0.35, 1.0, 0.55, alpha) if friendly else Color(0.82, 0.45, 1.0, alpha)
		"danger":
			return Color(1.0, 0.28, 0.18, alpha)
		_:
			return Color(1.0, 1.0, 1.0, alpha)

static func terrain_color(zone: String, alpha := 1.0, miniature := false) -> Color:
	var color := BOG_LAND if miniature else BOG_LAND_DARK
	match zone:
		TerrainMapScript.HABITAT_BLUE:
			color = Color(0.19, 0.28, 0.27) if miniature else Color(0.18, 0.22, 0.14)
		TerrainMapScript.HABITAT_RED:
			color = Color(0.28, 0.22, 0.16) if miniature else Color(0.19, 0.16, 0.11)
		TerrainMapScript.WATER:
			color = WATER_SHALLOW if miniature else WATER_DEEP
		TerrainMapScript.SHALLOW:
			color = Color(0.22, 0.34, 0.31) if miniature else WATER_SHALLOW
		TerrainMapScript.COVER:
			color = Color(0.12, 0.22, 0.12) if miniature else Color(0.08, 0.15, 0.08)
	color.a = alpha
	return color

static func environment_palette() -> Dictionary:
	return {
		"land_dark": BOG_LAND_DARK,
		"land": BOG_LAND,
		"moss": BOG_MOSS,
		"mud_dark": BOG_MUD_DARK,
		"mud": BOG_MUD,
		"reed": BOG_REED,
		"water_deep": WATER_DEEP,
		"water_shallow": WATER_SHALLOW,
		"water_foam": WATER_FOAM,
		"shadow": SHADOW
	}

static func shadow_color(alpha := SHADOW.a) -> Color:
	var output := SHADOW
	output.a = alpha
	return output

static func harvestable_color(part: String, alpha := 1.0) -> Color:
	var color := BOG_MOSS
	match part:
		"marker_fill":
			color = BOG_LAND_DARK.darkened(0.28)
		"berry_marker":
			color = BOG_MOSS.lightened(0.08)
		"tree_marker", "pip":
			color = Color(0.68, 0.54, 0.24)
		"seed_marker":
			color = BOG_MUD.lightened(0.16)
		"flower_marker", "flower_petal":
			color = Color(0.58, 0.40, 0.54)
		"berry_stem", "flower_stem":
			color = BOG_MOSS.darkened(0.08)
		"berry_leaf", "seed_sprout":
			color = BOG_MOSS.lightened(0.1)
		"berry_fruit":
			color = Color(0.56, 0.18, 0.22)
		"tree_trunk", "seed_soil", "critter_shell":
			color = BOG_MUD
		"tree_canopy":
			color = BOG_MOSS.darkened(0.1)
		"tree_fruit", "flower_center", "critter_belly":
			color = BOG_REED.lightened(0.14)
		"pip_empty":
			color = BOG_MUD_DARK.darkened(0.18)
	color.a = alpha
	return color

static func family_color(family: String, alpha := 1.0) -> Color:
	var color := BOG_REED
	match family:
		"amphibian":
			color = BOG_MOSS.lightened(0.12)
		"reptile":
			color = BOG_MOSS.darkened(0.08)
		"bird":
			color = Color(0.44, 0.50, 0.58)
		"mammal":
			color = BOG_MUD
		"crawly":
			color = BOG_MUD.lightened(0.1)
	color.a = alpha
	return color

static func habitat_accent_color(team: int, alpha := 1.0) -> Color:
	var color := Color(0.20, 0.31, 0.34) if team == 0 else Color(0.36, 0.25, 0.18)
	color.a = alpha
	return color

static func ecology_zone_color(kind: String, alpha := 1.0) -> Color:
	var color := BOG_REED
	match kind:
		"boss_active":
			color = Color(0.58, 0.43, 0.22)
		"boss_dormant":
			color = Color(0.52, 0.46, 0.38)
		"blue_control":
			color = Color(0.24, 0.38, 0.42)
		"red_control":
			color = Color(0.42, 0.28, 0.22)
		"blue_side":
			color = BOG_MOSS.lightened(0.06)
		"red_side":
			color = Color(0.58, 0.62, 0.34)
		"contested":
			color = Color(0.58, 0.52, 0.28)
		"water_outline":
			color = WATER_FOAM
		"water_fill":
			color = WATER_SHALLOW
	color.a = alpha
	return color

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
