extends SceneTree

const ARENA := preload("res://scenes/arena.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func run() -> void:
	var blood := ArenaBlood.new()
	root.add_child(blood)
	blood.set_process(false)
	blood.spawn_spray(Vector2(300, 150), Vector2(80, -140), 1.2)
	blood.advance(0.1)
	check(blood.splashes.size() == 1, "Airborne spray must not disappear before impact.")
	check(blood.splashes[0]["position"].x > 300.0, "Spray must have independent horizontal motion.")
	blood.spawn_spray(Vector2(959, 300), Vector2(100, 0), 1.0)
	blood.advance(0.02)
	check(blood.splashes.size() == 1, "Spray must disappear on side-wall impact.")
	blood.spawn_spray(Vector2(300, 599), Vector2(0, 100), 1.0)
	blood.advance(0.02)
	check(blood.splashes.size() == 1, "Spray must disappear on floor impact.")
	blood.spawn_spray(Vector2(300, 2), Vector2(0, -100), 1.0)
	blood.advance(0.02)
	check(blood.splashes.size() == 1, "Spray must disappear on ceiling impact.")
	blood.splashes.clear()
	blood.max_splashes = 4
	for index in 4:
		check(blood.spawn_spray(Vector2(100 + index, 100), Vector2.ZERO),
			"Spray capacity must accept its first particles.")
	check(not blood.spawn_spray(Vector2(600, 100), Vector2.ZERO)
		and blood.splashes.size() == 4 and blood.splashes[0]["position"].x == 100,
		"Capacity must reject new spray without removing airborne particles.")
	blood.queue_free()
	var arena := ARENA.instantiate() as BallArena
	root.add_child(arena)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.opponent = null
	red.opponent = null
	var effects := arena.get_node("CombatEffects") as ArenaCombatEffects
	var arena_blood := arena.get_node("BloodEffects") as ArenaBlood
	effects.set_process(false)
	arena_blood.set_process(false)
	effects.number_layer.set_process(false)
	effects.rng.seed = 42
	effects.advance(0.2)
	check(arena_blood.splashes.is_empty(), "No attack may mean no new spray.")
	var fangs := red.get_node("Vampire") as VampireFangs
	check(fangs.try_bite(blue), "VFX fixture must start a real bite.")
	fangs.set_physics_process(false)
	effects.advance(0.16)
	check(effects.drains.size() == 1 and arena_blood.splashes.size() == 3,
		"Active bite must create a drain link and three larger blood sprays at the reduced rate.")
	check(not effects.orbs.is_empty() and effects.orbs.size() <= effects.max_orbs,
		"Drain must create a bounded set of green spheres.")
	effects.advance(0.24)
	check(arena_blood.splashes.size() == 9, "Reduced spray rate must remain consistent across several batches.")
	var spread := {}
	for spray in arena_blood.splashes:
		var velocity: Vector2 = spray["velocity"]
		spread[int(floor(velocity.angle() * 2.0))] = true
		check(float(spray["radius"]) >= 1.70 and float(spray["radius"]) <= 3.30, "Spray radius must be twice the previous 0.85-1.65 range.")
	check(spread.size() > 2, "Blood spray must fly in multiple directions.")
	var orb: Dictionary = effects.orbs[0]
	orb["age"] = 0.0
	var origin := effects.orb_position(orb)
	orb["age"] = orb["duration"]
	check(effects.orb_position(orb).distance_to(red.global_position) < 0.01
		and origin.distance_to(blue.global_position) <= blue.visual_diameter() * 0.5,
		"Health spheres must travel from inside the victim's body to the vampire.")
	orb["age"] = 0.0
	red.current_health = 90
	check(blue.take_damage(4) == 4 and red.heal(4) == 4,
		"Health change fixture must apply actual damage and healing.")
	var numbers: Array = effects.number_layer.get("numbers")
	check(numbers.size() == 2 and numbers[0]["text"] == "-4" and numbers[1]["text"] == "+4",
		"Real damage and healing must create signed colored combat numbers.")
	var original_y: float = numbers[0]["position"].y
	effects.number_layer.call("advance", 0.4)
	numbers = effects.number_layer.get("numbers")
	check(numbers[0]["position"].y < original_y, "Combat numbers must move upward.")
	red.current_health = 100
	check(red.heal(5) == 5 and red.current_health == 105
		and (effects.number_layer.get("numbers") as Array).size() == 3,
		"Healing above reference HP must apply and create a real healing number.")
	effects.number_layer.call("advance", 1.2)
	check((effects.number_layer.get("numbers") as Array).is_empty(),
		"Combat numbers must expire after their fade.")
	var old_spray := arena_blood.splashes.size()
	fangs.call("_finish_bite")
	effects.advance(0.5)
	check(effects.drains.is_empty() and effects.orbs.is_empty()
		and arena_blood.splashes.size() == old_spray,
		"Attack end must remove the drain and stop new spray without deleting flying blood.")
	check(blue.has_node("HealthDisplay") and red.has_node("HealthDisplay"),
		"Every character must have a centered HP display.")
	var temporary := ArenaBall.new()
	root.add_child(temporary)
	effects.start_drain(red, temporary)
	temporary.free()
	effects.advance(0.1)
	check(effects.drains.is_empty(), "Generic drain must clean up if a future character is removed.")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: airborne spray persists until boundaries; multi-direction spread; no emission outside bite; bounded particles; victim-to-vampire spheres; HP and real floating damage/heal numbers")
		quit(0)
	else:
		quit(1)
