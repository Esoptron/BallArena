extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.blue_character_id = &"katana"
	arena.red_character_id = &"ordinary"
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.freeze = true
	b.freeze = true
	var katana := a.get_node("Katana") as KatanaAbility
	katana.set_physics_process(false)
	check(is_equal_approx(a.diameter,63.0) and a.weight_class == 1 and is_equal_approx(a.mass,0.8),"Katana body must be 10% smaller and below average weight.")
	check(katana.definition.weapon_weight_class == 0 and katana.blade_length * a.diameter / 70.0 > CharacterCatalog.ability(&"sword").parameters["blade_length"],"Katana must be light and longer than the sword.")
	check(katana.spin_speed == 8.0 and katana.critical_chance == katana.critical_start_chance,"Katana must start with medium orbit and configured critical chance.")
	a.position = Vector2(420,300)
	b.position = Vector2(600,300)
	katana.rotation = 0.0
	check(katana.intersects_target(b,0.0),"Long katana must reach a target beyond sword range.")
	katana.critical_chance = 0.0
	var hp := b.current_health
	check(katana.try_hit(b) and b.current_health == hp - katana.base_damage,"Normal katana hit must apply low damage.")
	check(is_equal_approx(katana.critical_chance,katana.critical_chance_gain) and b.bleeding_stacks.is_empty(),"Every successful normal hit must add the configured chance gain.")
	check(b.katana_wound_stage == 0,"Normal hits must not create a critical wound.")
	check(not katana.try_hit(b),"Katana must share the normal one-second hit cooldown.")
	katana.cooldown_remaining = 0.0
	katana._contact_victim = null
	b.set_invulnerable(b,true)
	var chance := katana.critical_chance
	var random_state := katana.rng.state
	check(not katana.try_hit(b) and katana.critical_chance == chance and katana.rng.state == random_state,"Blocked damage must not roll or grow critical chance.")
	b.set_invulnerable(b,false)
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	blood.splashes.clear()
	blood.drops.clear()
	blood.rng.seed = 1234
	katana.critical_chance = 1.0
	for hit in 2:
		katana.cooldown_remaining = 0.0
		katana._contact_victim = null
		check(katana.try_hit(b) and katana.last_hit_critical,"Guaranteed critical fixture must succeed.")
	check(blood.splashes.size() == 6 and blood.drops.is_empty(),"Two criticals must emit three ballistic drops each, without bottom drips.")
	check(b.katana_wound_stage == 2,"Two criticals must deepen the wound to its second stage.")
	check(b.bleeding_stacks.size() == 2 and katana.critical_chance == 1.0,"Repeated criticals must stack and chance must stop at 100%.")
	hp = b.current_health
	b._advance_bleeding(0.99)
	check(b.current_health == hp,"Bleed damage must wait for a full second.")
	b._advance_bleeding(0.01)
	check(b.current_health == hp - 2,"Two bleeding stacks must each apply one damage per second.")
	check(blood.splashes.size() == 8 and blood.drops.is_empty(),"Each bleeding tick must emit from the wound instead of dripping below the body.")
	b._advance_bleeding(5.0)
	check(b.current_health == hp - 12 and b.bleeding_stacks.size() == 2,"Bleeding must continue past five seconds until battle ends.")
	b.set_invulnerable(b,true)
	hp = b.current_health
	b._advance_bleeding(1.0)
	check(b.current_health == hp and b.bleeding_stacks.size() == 2,"Protection must block ticks without removing lasting bleed.")
	b.set_invulnerable(b,false)
	# Each newly applied critical starts its own second rather than resetting old clocks.
	b.clear_bleeding()
	b.add_bleeding(a,1,1.0,&"katana")
	b._advance_bleeding(0.5)
	b.add_bleeding(a,1,1.0,&"katana")
	hp = b.current_health
	b._advance_bleeding(0.5)
	check(b.current_health == hp - 1,"New bleed must not reset the earlier stack clock.")
	b._advance_bleeding(0.5)
	check(b.current_health == hp - 2,"Later bleed must start ticking one second after its own application.")
	# Cosmetic random spray must leave the cut in every direction, without changing combat RNG.
	blood.splashes.clear()
	var combat_random_state := katana.rng.state
	b.emit_katana_wound_blood(32)
	var directions := [false,false,false,false]
	var segment: PackedVector2Array = b.get_node("KatanaWound").call("emission_segment")
	for spray in blood.splashes:
		var origin := blood.to_global(spray["position"])
		check(origin.distance_to(Geometry2D.get_closest_point_to_segment(origin,segment[0],segment[1])) < 0.01,"Blood must originate on the cut.")
		var velocity: Vector2 = spray["velocity"]
		if velocity.x < -20.0: directions[0] = true
		if velocity.x > 20.0: directions[1] = true
		if velocity.y < -20.0: directions[2] = true
		if velocity.y > 20.0: directions[3] = true
	check(directions.all(func(value: bool) -> bool: return value),"Wound spray must include left, right, up and down directions.")
	check(katana.rng.state == combat_random_state,"Cosmetic spray must not change critical outcomes.")
	# Seeded rolls must use 10 percent, not 10 or a cosmetic random generator.
	b.clear_bleeding()
	b.current_health = 100000
	for hit in 4:
		katana.critical_chance = 1.0
		katana.resolve_hit_damage(b)
	check(b.katana_wound_stage == 4 and b.bleeding_stacks.size() == 4,"Wound must stop at four stages while later criticals keep adding bleed.")
	var crits := 0
	for seed_value in 1000:
		katana.critical_chance = 0.10
		katana.rng.seed = seed_value
		katana.resolve_hit_damage(b)
		if katana.last_hit_critical:
			crits += 1
		b.clear_bleeding()
	check(crits >= 60 and crits <= 140,"Seeded starting rolls must approximate a ten-percent chance.")
	print("Initial criticals over 1000 seeded rolls: ",crits)
	katana.reset_progression()
	check(katana.critical_chance == katana.critical_start_chance and katana.current_damage == katana.base_damage,"New fight must reset critical growth.")
	b.add_bleeding(a,1,1.0,&"katana")
	check(b.bleeding_stacks.size() == 1,"End-of-duel fixture must have an active bleeding effect.")
	a.take_damage(10000,b,&"test")
	check(arena.director.match_over and b.bleeding_stacks.is_empty(),"All bleeding must end immediately when a duel ends.")
	hp = b.current_health
	b._advance_bleeding(10.0)
	check(b.current_health == hp,"Winner must not keep bleeding after the result.")
	arena.queue_free()
	await process_frame
	print("Katana critical and lasting bleed: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
