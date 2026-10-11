extends SceneTree

const ARENA := preload("res://scenes/arena.tscn")
var failures: Array[String] = []
var tick_damage: Array[int] = []
var tick_healing: Array[int] = []


func _initialize() -> void:
	run_checks.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)


func run_checks() -> void:
	await test_bite_schedule()
	await test_simultaneous_bites()
	await test_visuals_and_health()
	await test_live_low_health()
	test_blood()
	await process_frame
	if failures.is_empty():
		print("PASS: 10 unit damage/heal ticks over 3s; paralysis/recovery; aim; non-solid fangs; 70-50 pulse; downward blood/squash/fade/cap")
		quit(0)
	else:
		quit(1)


func ticks(count: int) -> void:
	for frame in count:
		await physics_frame


func new_arena() -> BallArena:
	var arena := ARENA.instantiate() as BallArena
	root.add_child(arena)
	return arena


func remove_arena(arena: BallArena) -> void:
	arena.queue_free()
	await process_frame


func on_bite_tick(_victim: ArenaBall, damage: int, healing: int) -> void:
	tick_damage.append(damage)
	tick_healing.append(healing)


func test_bite_schedule() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var fangs := blue.get_node("Vampire") as VampireFangs
	blue.opponent = null
	red.opponent = null
	red.is_vampire = false
	blue.freeze = true
	blue.current_health = 50
	fangs.bite_tick.connect(on_bite_tick)
	var pinned_position := red.position
	check(fangs.try_bite(red), "First bite should start.")
	check(not fangs.try_bite(red), "A bite must not stack/restart itself.")
	check(fangs.has_bitten and red.is_paralyzed() and red.freeze,
		"Bite should replace aura and immediately paralyze the victim.")
	check(red.current_health == 100 and blue.current_health == 50,
		"Bite must not apply all damage/healing instantly.")
	await ticks(77)
	check(red.current_health == 99 and blue.current_health == 51,
		"First 0.3-second tick should deal and heal exactly one unit.")
	await ticks(620)
	check(red.is_paralyzed() and red.position.distance_to(pinned_position) < 0.01,
		"Victim must stay fixed throughout the 3-second bite.")
	check(tick_damage.size() == 9, "Nine ticks should have completed before 3 seconds.")
	await ticks(50)
	check(red.current_health == 90 and blue.current_health == 60,
		"One completed bite should total exactly 10 damage and 10 healing.")
	check(tick_damage.size() == 10 and tick_healing.size() == 10,
		"Damage and healing must consist of exactly ten ticks.")
	for amount in tick_damage:
		check(amount == 1, "Each damage tick must be one unit.")
	for amount in tick_healing:
		check(amount == 1, "Each healing tick must be one unit.")
	check(not red.is_paralyzed() and not red.freeze, "Paralysis should end at three seconds.")
	check(absf(red.linear_velocity.length() - red.movement_speed) < 0.05,
		"Victim should recover its original movement speed.")
	check(not fangs.try_bite(red), "Recovery period should prevent an immediate new bite.")
	await ticks(250)
	check(fangs.try_bite(red), "Bite should become available after recovery.")
	await remove_arena(arena)


func test_simultaneous_bites() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.position = Vector2(430, 300)
	red.position = Vector2(520, 300)
	blue.reset_physics_interpolation()
	red.reset_physics_interpolation()
	await ticks(10)
	var blue_fangs := blue.get_node("Vampire") as VampireFangs
	var red_fangs := red.get_node("Vampire") as VampireFangs
	check(blue_fangs.has_bitten and red_fangs.has_bitten,
		"Two vampires must be able to land a simultaneous bite without node-order bias.")
	check(blue.is_paralyzed() and red.is_paralyzed(), "Both simultaneous victims should be paralyzed.")
	await ticks(780)
	check(not blue.is_paralyzed() and not red.is_paralyzed(),
		"Both vampires should resume movement after their simultaneous bites.")
	check(blue_fangs.ticks_remaining == 0 and red_fangs.ticks_remaining == 0,
		"Both bite schedules should finish without stacking.")
	await remove_arena(arena)


func test_visuals_and_health() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var fangs := blue.get_node("Vampire") as VampireFangs
	blue.freeze = true
	red.freeze = true
	red.position = blue.position + Vector2(50, 180)
	fangs.aim_at_opponent()
	var aim := Vector2.UP.rotated(fangs.global_rotation)
	var expected := (red.global_position - blue.global_position).normalized()
	check(aim.dot(expected) > 0.9999, "Fangs must point towards the opponent.")
	check(fangs.get_class() == "Node2D" and fangs.get_child_count() == 0,
		"Fangs must be visual only, with no solid collision shapes.")
	var shape := (blue.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	blue.current_health = 29
	blue.set("_visual_time", 0.0)
	check(is_equal_approx(blue.visual_diameter(), 70.0), "Low-health pulse must reach 70.")
	blue.set("_visual_time", 0.5 / blue.pulse_frequency)
	check(is_equal_approx(blue.visual_diameter(), 50.0), "Low-health pulse must reach 50.")
	blue.call("_sync_pulse_shape")
	check(is_equal_approx(shape.radius, 25.0), "Collider must follow the 50-unit pulse diameter.")
	blue.current_health = 30
	blue.call("_sync_pulse_shape")
	check(is_equal_approx(shape.radius, 35.0), "Collider must restore its 70-unit diameter after healing.")
	check(not blue.has_low_health() and is_equal_approx(blue.visual_diameter(), 70.0),
		"Exactly 30 percent health must not pulse.")
	blue.current_health = 99
	check(blue.heal(10) == 1 and blue.current_health == 100, "Healing must respect maximum HP.")
	check(blue.take_damage(150) == 100 and blue.current_health == 0,
		"Health must not become negative.")
	check(blue.heal(10) == 0 and blue.current_health == 0, "A defeated vampire must not revive itself.")
	await remove_arena(arena)


func test_blood() -> void:
	var blood := ArenaBlood.new()
	root.add_child(blood)
	blood.set_process(false)
	blood.spawn_drop(Vector2(123, 100))
	var previous_y: float = blood.drops[0]["position"].y
	for step in 10:
		blood.advance(0.05)
		var p: Vector2 = blood.drops[0]["position"]
		check(is_equal_approx(p.x, 123.0) and p.y > previous_y,
			"Blood must move vertically down, with no inherited horizontal/rotational velocity.")
		previous_y = p.y
	blood.advance(2.0)
	check(blood.drops[0]["landed"], "Blood should hit the bottom floor.")
	check(blood.drops[0]["position"].y <= blood.floor_y,
		"Blood should not pass through the floor.")
	blood.advance(0.13)
	check(blood.drops[0]["age"] > 0.12, "Landed blood should progress into its flattened/fading state.")
	blood.advance(blood.stain_lifetime)
	check(blood.drops.is_empty(), "Blood stains must disappear after their lifetime.")
	for index in blood.max_drops + 20:
		blood.spawn_drop(Vector2(123, 100))
	check(blood.drops.size() == blood.max_drops, "Continuous dripping must have a bounded particle count.")
	blood.queue_free()


func test_live_low_health() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.current_health = 20
	red.current_health = 25
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	var worst_penetration: float = 0.0
	for step in Engine.physics_ticks_per_second * 60:
		await physics_frame
		for ball in [blue, red]:
			var collision: CollisionShape2D = ball.get_node("CollisionShape2D")
			var radius: float = (collision.shape as CircleShape2D).radius
			check(radius >= 24.999 and radius <= 35.001, "Pulsating collider exceeded its 50-70 size range.")
			check(ball.current_health >= 0 and ball.current_health <= ball.max_health,
				"Live combat exceeded health bounds.")
			if ball.is_paralyzed():
				check(ball.freeze, "Live paralysis failed to hold a victim.")
			elif ball.current_health > 0:
				check(absf(ball.linear_velocity.length() - ball.movement_speed) < 0.05,
					"Moving vampire lost its configured speed.")
			var p: Vector2 = ball.position
			var penetration := maxf(maxf(radius - p.x, radius - p.y),
				maxf(p.x + radius - arena.arena_size.x, p.y + radius - arena.arena_size.y))
			worst_penetration = maxf(worst_penetration, penetration)
			check(penetration < 4.0, "Pulsation/paralysis allowed deep wall penetration.")
		check(blood.drops.size() <= blood.max_drops, "Live dripping exceeded its particle limit.")
	print("60s live low-health combat: max wall penetration=%.3f, active drops=%d"
		% [worst_penetration, blood.drops.size()])
	await remove_arena(arena)
