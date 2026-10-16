extends SceneTree
var failures: Array[String] = []
var order: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.blue_character_id = &"knifeman"
	arena.randomize_spawns = false
	root.add_child(arena)
	var knife := arena.get_node("Balls/BlueBall") as ArenaBall
	var vampire := arena.get_node("Balls/RedBall") as ArenaBall
	var daggers := knife.get_node("Knives") as DaggerAbility
	var fangs := vampire.get_node("Vampire") as VampireFangs
	var director := arena.director
	director.set_physics_process(false)
	for ability in director.abilities: ability.set_physics_process(false)
	var metrics := CombatMetrics.new()
	var fighters: Array[ArenaBall] = [knife,vampire]
	metrics.attach(fighters,director)
	daggers.capture_counter_chance = 1.0
	for counter in 2:
		knife.position = Vector2(480,300)
		vampire.position = Vector2(400,300)
		knife.capture_immunity_remaining = 0
		fangs.cooldown_remaining = 0
		check(fangs.try_bite(knife),"Counter metric fixture must capture.")
		fangs._bite_tick()
		check(fangs.bite_target == null,"Counter must release its victim.")
		check(daggers.weapon_segments_at(0.0) == daggers.weapon_segments_at(1.0),"Relocation must clear the old swept weapon path.")
	var counted: Dictionary = metrics.participants[knife.actor_id]["abilities"]["daggers"]
	check(counted["starts"] == 2 and counted["successes"] == 2 and counted["completed"] == 2,"Each counter must count as its own completed successful cast.")
	check(metrics.participants[knife.actor_id]["hits"] == 2,"Each counter must count exactly one hit.")
	# Near-but-distinct fractions must resolve chronologically, regardless of initiative.
	director.priorities = {"blue":0.0,"red":1.0}
	director.submit(daggers,func() -> void: order.append("later"),0.400000001)
	director.submit(fangs,func() -> void: order.append("earlier"),0.4)
	director._physics_process(0.0)
	check(order == ["earlier","later"],"Actual contact times must outrank initiative even for very close fractions.")
	var effects := arena.get_node("CombatEffects") as ArenaCombatEffects
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	effects.set_process(false)
	blood.set_process(false)
	effects.start_drain(vampire,knife)
	effects.orbs.clear()
	effects.spray_rate = 0
	effects.orb_rate = 0
	blood.splashes.clear()
	effects.advance(1.0)
	check(effects.orbs.is_empty() and blood.splashes.is_empty(),"Zero cosmetic rates must safely disable emissions.")
	effects.spray_rate = 25
	effects.orb_rate = 25
	effects.advance(30.0)
	check(blood.splashes.size() <= 24 and effects.orbs.size() <= effects.max_orbs,"Long frames must have a bounded particle catch-up budget.")
	# A reusable bare body is valid even without an optional Sword node.
	var bare := ArenaBall.new()
	root.add_child(bare)
	bare.get_node("BerserkIndicator").call("_process",0.0)
	check(not bare.get_node("BerserkIndicator").visible,"Optional sword indicator must stay hidden on a bare ball.")
	bare.queue_free()
	arena.queue_free()
	await process_frame
	print("Review regressions: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
