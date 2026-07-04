extends Resource
class_name DamageEvent

const DELIVERY_MELEE := 0
const DELIVERY_RANGED := 1
const PLANE_GROUND := 0
const PLANE_AIR := 1

var amount := 0.0
var delivery := DELIVERY_MELEE
var plane := PLANE_GROUND
var source_actor: Node = null
var source_ability := ""

func setup(next_amount: float, next_delivery: int, next_plane: int, next_source_actor: Node = null, next_source_ability := "") -> void:
	amount = next_amount
	delivery = next_delivery
	plane = next_plane
	source_actor = next_source_actor
	source_ability = next_source_ability
