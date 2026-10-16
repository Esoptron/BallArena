extends SceneTree
var failures: Array[String] = []
var arena: BallArena
var knife: ArenaBall
var vampire: ArenaBall
var daggers: DaggerAbility
var fangs: VampireFangs
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func begin(health: int = 100) -> void:
	if fangs.bite_target != null: fangs.interrupt_bite(knife)
	knife.current_health = 90
	vampire.current_health = health
	knife.capture_immunity_remaining = 0
	vampire.attack_recovery_remaining = 0
	fangs.cooldown_remaining = 0
	knife.position = Vector2(480,300)
	vampire.position = Vector2(400,300)
	check(fangs.try_bite(knife),"Fixture must start a capture.")
func run() -> void:
	arena = load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.randomize_spawns = false
	arena.blue_character_id = &"knifeman"
	arena.red_character_id = &"vampire"
	root.add_child(arena)
	arena.director.set_physics_process(false)
	knife = arena.get_node("Balls/BlueBall")
	vampire = arena.get_node("Balls/RedBall")
	daggers = knife.get_node("Knives")
	fangs = vampire.get_node("Vampire")
	check(is_equal_approx(daggers.capture_counter_chance,float(CharacterCatalog.ability(&"daggers").parameters["capture_counter_chance"])),"Counter chance must come from the current central profile.")
	begin(150)
	daggers.capture_counter_chance = 0
	fangs._bite_tick()
	check(knife.current_health == 89 and fangs.bite_target == knife,"Ordinary tick must still apply exactly one damage.")
	daggers.capture_counter_chance = 1
	daggers.cooldown_remaining = 1
	var front := (knife.global_position-vampire.global_position).normalized()
	fangs._bite_tick()
	# Second tick heals one HP: twenty percent of 151 rounds upward to 31.
	check(vampire.current_health == 120,"Counter must deal twenty percent of current HP after tick healing, including HP above 100.")
	check(knife.current_health == 88 and fangs.bite_target == null and fangs.ticks_remaining == 0,"Counter must terminate the capture immediately.")
	check(not knife.is_immobilized() and not vampire.is_immobilized() and not vampire.is_invulnerable(),"Counter must release both bodies and bite protection.")
	check((knife.global_position-vampire.global_position).normalized().dot(front) < -0.999,"Knife must emerge behind the vampire.")
	check(fangs.cooldown_remaining == fangs.recovery_time and daggers.cooldown_remaining == daggers.hit_cooldown,"Interrupted bite and counter must use normal recovery.")
	check(knife.transport_velocity == Vector2.ZERO and vampire.transport_velocity == Vector2.ZERO,"Capture transport must be cleared.")
	check(arena.get_node("CombatEffects").drains.is_empty() and arena.get_node("CombatEffects").counter_slashes.size() == 1,"Counter must replace drain with one red slash.")
	var hp := vampire.current_health
	fangs._bite_tick()
	check(vampire.current_health == hp and knife.current_health == 88,"Queued ticks must not continue damage or healing after interruption.")
	begin()
	daggers.capture_counter_chance = 0
	for tick in 14: fangs._bite_tick()
	daggers.capture_counter_chance = 1
	fangs._bite_tick()
	check(vampire.current_health == 88 and knife.current_health == 75,"The fifteenth damage tick must also have a counter opportunity.")
	begin()
	knife.set_invulnerable(knife,true)
	var state := daggers.rng.state
	fangs._bite_tick()
	check(daggers.rng.state == state and fangs.bite_target == knife,"Blocked damage must not roll a counter.")
	knife.set_invulnerable(knife,false)
	# Wall and corner placement preserves full body radii and behind-facing geometry.
	for point in [Vector2(39,39),Vector2(921,39),Vector2(921,561),Vector2(39,561)]:
		vampire.position = point
		daggers._place_behind(vampire,Vector2(1,1).normalized())
		for body in [knife,vampire]:
			var r: float = body.diameter*0.5
			check(body.position.x >= r and body.position.y >= r and body.position.x <= 960-r and body.position.y <= 600-r,"Counter pair must remain inside arena corners.")
		check(knife.position.distance_to(vampire.position) >= (knife.diameter+vampire.diameter)*0.5,"Counter must not overlap body collision circles.")
	# Exercise actual release and moving physics at every corner, not only static placement.
	daggers.capture_counter_chance = 1.0
	for corner in [Vector2(40,40),Vector2(920,40),Vector2(920,560),Vector2(40,560)]:
		for index in 8:
			begin()
			var heading := Vector2.from_angle(index*TAU/8.0)
			vampire.position = corner
			knife.position = corner+heading*60.0
			fangs._bite_tick()
			for frame in 90:
				await physics_frame
				for body in [knife,vampire]:
					var radius: float = body.visual_diameter()*0.5
					check(body.position.x >= radius-0.5 and body.position.y >= radius-0.5 and body.position.x <= 960-radius+0.5 and body.position.y <= 600-radius+0.5,"Moving counter release outside wall: %s %s at corner %s heading %s" % [body.name,body.position,corner,index])
	# Independent seeded trials: every damaging tick rolls, and capture ends at first proc.
	var successes := 0
	var late := 0
	daggers.capture_counter_chance = 0.035
	for sample in 1000:
		begin()
		daggers.rng.seed = sample+81000
		for tick in 15:
			fangs._bite_tick()
			if fangs.bite_target == null:
				if vampire.current_health < 100:
					successes += 1
					if tick > 0: late += 1
				break
	check(successes >= 350 and successes <= 470 and late > 300,"Per-tick rolls must match about 41 percent over a complete fifteen-tick bite, including later ticks.")
	print("COUNTER TRIALS: ",successes," / 1000 captures; later-tick counters: ",late)
	print("PASS knife capture counter" if failures.is_empty() else "FAIL knife capture counter: "+str(failures))
	quit(0 if failures.is_empty() else 1)



