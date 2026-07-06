extends Resource
class_name DamageEvent

const DELIVERY_MELEE := 0
const DELIVERY_RANGED := 1
const DELIVERY_AREA := 2
const PLANE_GROUND := 0
const PLANE_AIR := 1

var amount := 0.0
var delivery := DELIVERY_MELEE
var plane := PLANE_GROUND
var source_actor: Node = null
var source_ability := ""
var hit_position := Vector2.ZERO
var hit_normal := Vector2.ZERO
var region := "hull"
var region_mult := 1.0

func setup(next_amount: float, next_delivery: int, next_plane: int, next_source_actor: Node = null, next_source_ability := "") -> void:
	amount = next_amount
	delivery = next_delivery
	plane = next_plane
	source_actor = next_source_actor
	source_ability = next_source_ability

func set_hit(next_position: Vector2, next_normal: Vector2, next_region := "hull", next_region_mult := 1.0) -> void:
	hit_position = next_position
	hit_normal = next_normal.normalized() if next_normal != Vector2.ZERO else Vector2.ZERO
	region = next_region
	region_mult = next_region_mult
