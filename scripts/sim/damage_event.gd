extends Resource
class_name DamageEvent

enum Delivery {
	MELEE,
	RANGED,
}

enum Plane {
	GROUND,
	AIR,
}

var amount := 0.0
var delivery := Delivery.MELEE
var plane := Plane.GROUND
var source_actor: Node = null
var source_ability := ""

func setup(next_amount: float, next_delivery: Delivery, next_plane: Plane, next_source_actor: Node = null, next_source_ability := "") -> void:
	amount = next_amount
	delivery = next_delivery
	plane = next_plane
	source_actor = next_source_actor
	source_ability = next_source_ability

