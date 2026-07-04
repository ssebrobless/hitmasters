extends SceneTree

const CreatureScript := preload("res://scripts/sim/creature.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const DamScript := preload("res://scripts/game/dam.gd")
const DucklingScript := preload("res://scripts/sim/pets/duckling.gd")

func _initialize() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog != null:
		catalog.load_catalog()

	# Kits instantiate for all six slice creatures.
	var kits_ok := true
	for creature_id in ["snapping_turtle", "chorus_frog", "mink", "beaver", "owl", "duck"]:
		var creature := CreatureScript.new()
		root.add_child(creature)
		creature.setup(null, 0, Vector2.ZERO, creature_id)
		if creature.kit == null:
			kits_ok = false
		creature.queue_free()

	# Airborne owl dodges ground melee, but not during its low window,
	# and never dodges ranged.
	var owl := CreatureScript.new()
	root.add_child(owl)
	owl.setup(null, 0, Vector2.ZERO, "owl")
	owl.state = CreatureStateScript.State.AIRBORNE
	var ground_melee := DamageEventScript.new()
	ground_melee.setup(50.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, null, "Bite")
	owl.take_damage_event(ground_melee)
	var dodged := owl.health == owl.max_health
	var ranged := DamageEventScript.new()
	ranged.setup(30.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, null, "Shot")
	owl.take_damage_event(ranged)
	var ranged_hit := owl.health < owl.max_health
	owl.heal(1000.0)
	owl.open_low_window(0.7)
	owl.take_damage_event(ground_melee)
	var low_window_hit := owl.health < owl.max_health

	# Spike rule: heavy ranged hit grounds a flying bird with lockout.
	owl.heal(1000.0)
	owl.state = CreatureStateScript.State.AIRBORNE
	owl.flight_grounded_timer = 0.0
	var spike := DamageEventScript.new()
	spike.setup(35.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, null, "Heavy Shot")
	owl.take_damage_event(spike)
	var spiked: bool = owl.state == CreatureStateScript.State.NORMAL and owl.flight_grounded_timer > 2.9
	owl.heal(1000.0)
	owl.state = CreatureStateScript.State.AIRBORNE
	owl.flight_grounded_timer = 0.0
	var light := DamageEventScript.new()
	light.setup(15.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, null, "Light Shot")
	owl.take_damage_event(light)
	var light_no_spike: bool = owl.state == CreatureStateScript.State.AIRBORNE

	# Stealth set/break.
	owl.begin_stealth(10.0, "Silent Flight")
	var stealth_on := owl.is_stealthed()
	owl.break_stealth()
	var stealth_off := not owl.is_stealthed()

	# Perch pauses flight drain.
	owl.state = CreatureStateScript.State.PERCHED
	var flight_before := owl.flight_time_remaining
	owl.tick_sim(1.0)
	var perch_pause: bool = absf(owl.flight_time_remaining - flight_before) < 0.01

	# Dam takes damage and reports rect.
	var dam := DamScript.new()
	root.add_child(dam)
	dam.setup(null, 0, Rect2(Vector2(-24, -8), Vector2(48, 16)), 200.0)
	dam.take_damage(50.0)
	var dam_ok: bool = dam.health == 150.0 and dam.rect.size.x == 48.0

	# Duckling lives and dies.
	var duckling := DucklingScript.new()
	root.add_child(duckling)
	duckling.setup(null, null, 0, Vector2.ZERO, 0, 80.0)
	duckling.take_damage(30.0)
	var duckling_ok: bool = duckling.is_alive() and duckling.health == 50.0

	var passed := kits_ok and dodged and ranged_hit and low_window_hit and stealth_on and stealth_off and perch_pause and dam_ok and duckling_ok and spiked and light_no_spike
	print("m3 kits=%s dodge=%s ranged_hit=%s low_window=%s stealth=%s/%s perch_pause=%s dam=%s duckling=%s spike=%s/%s" % [
		str(kits_ok), str(dodged), str(ranged_hit), str(low_window_hit), str(stealth_on), str(stealth_off), str(perch_pause), str(dam_ok), str(duckling_ok), str(spiked), str(light_no_spike)
	])
	quit(0 if passed else 1)
