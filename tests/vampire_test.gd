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
	await test_default_matchup()
	await test_bite_schedule()
	await test_protected_bite()
	await test_shared_statuses_and_wounds()
	await test_tooth_immersion()
	await test_carried_direction()
	await test_bite_body_pulse()
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


func test_default_matchup() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var blue_fangs := blue.get_node("Vampire") as VampireFangs
	var red_fangs := red.get_node("Vampire") as VampireFangs
	check(not blue.is_vampire and red.is_vampire,
		"Default match must use a normal blue ball and a red vampire.")
	blue.current_health = 20
	blue.set("_visual_time", 0.5 / blue.pulse_frequency)
	blue.call("_sync_pulse_shape")
	var shape := (blue.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	check(is_equal_approx(blue.visual_diameter(), 70.0) and is_equal_approx(shape.radius, 35.0),
		"A normal blue ball must not use the vampire low-health pulse.")
	check(not blue_fangs.try_bite(red), "Normal blue ball must not start vampire attacks.")
	red.current_health = 50
	await ticks(600)
	check(red_fangs.has_bitten and not blue_fangs.has_bitten,
		"Default gameplay must produce only the red vampire's bite.")
	check(blue.is_paralyzed() and blue.current_health < 20 and red.current_health > 50,
		"Red vampire must paralyze/damage blue and heal itself in default gameplay.")
	check(not blue_fangs.visible and red_fangs.visible,
		"Only red vampire fangs and effects must be visible in the default scene.")
	await remove_arena(arena)


func test_bite_schedule() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var fangs := blue.get_node("Vampire") as VampireFangs
	blue.opponent = null
	red.opponent = null
	blue.is_vampire = true
	red.is_vampire = false
	blue.freeze = true
	blue.current_health = 50
	fangs.bite_tick.connect(on_bite_tick)
	check(fangs.try_bite(red), "First bite should start.")
	var pinned_position := red.position
	var attacker_position := blue.position
	check(not fangs.try_bite(red), "A bite must not stack/restart itself.")
	check(fangs.has_bitten and red.is_paralyzed() and red.freeze,
		"Bite should replace aura and immediately paralyze the victim.")
	check(blue.freeze and blue.is_invulnerable(), "Attacker must be stopped and invulnerable during its bite.")
	check(blue.take_damage(7) == 0 and blue.current_health == 50,
		"Invulnerability must block actual damage.")
	check(red.body_color().v < red.ball_color.v * 0.6,
		"Paralyzed victim must be visibly darker.")
	check(red.current_health == 100 and blue.current_health == 50,
		"Bite must not apply all damage/healing instantly.")
	await ticks(77)
	check(red.current_health == 99 and blue.current_health == 51,
		"First 0.3-second tick should deal and heal exactly one unit.")
	await ticks(620)
	check(red.is_paralyzed() and red.position.distance_to(pinned_position) > 100.0,
		"Helpless victim must continue moving rather than remain pinned.")
	check(absf((fangs.get("_carry_velocity") as Vector2).length() - blue.movement_speed / 3.0) < 0.05,
		"Victim must move at exactly one third of the attacker's configured speed.")
	check(blue.position.distance_to(attacker_position) < 0.01 and blue.freeze,
		"Attacker must remain fixed for the entire bite.")
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
	check(not blue.is_invulnerable() and not blue.freeze, "Attacker protection and hold must end with the bite.")
	var separation := (red.position - blue.position).normalized()
	check(blue.linear_velocity.normalized().dot(separation) < -0.99
		and red.linear_velocity.normalized().dot(separation) > 0.99,
		"After a bite both balls must depart away from each other.")
	check(red.bite_marks.size() == 2 and red.bite_marks_remaining > 2.8
		and red.wound_bleeding_remaining > 1.8, "Completed bite must leave timed wounds and bleeding.")
	check(is_equal_approx(red.bite_marks[0].distance_to(red.bite_marks[1]), fangs.fang_spacing()),
		"Bite marks must match long fang tip spacing.")
	check(red.body_color().is_equal_approx(red.ball_color), "Victim color must restore after paralysis.")
	check(not fangs.try_bite(red), "Recovery period should prevent an immediate new bite.")
	await ticks(250)
	check(fangs.try_bite(red), "Bite should become available after recovery.")
	await remove_arena(arena)


func test_protected_bite() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.is_vampire = true
	blue.position = Vector2(430, 300)
	red.position = Vector2(520, 300)
	blue.reset_physics_interpolation()
	red.reset_physics_interpolation()
	await ticks(10)
	var blue_fangs := blue.get_node("Vampire") as VampireFangs
	var red_fangs := red.get_node("Vampire") as VampireFangs
	check(blue_fangs.has_bitten != red_fangs.has_bitten,
		"An invulnerable attacker must prevent a reciprocal bite.")
	var attacker := blue if blue_fangs.has_bitten else red
	var victim := red if blue_fangs.has_bitten else blue
	check(attacker.is_invulnerable() and attacker.freeze and victim.is_paralyzed() and victim.freeze,
		"Both balls must stop, with protection only on the attacker.")
	check(blue.current_health == 100 and red.current_health == 100,
		"Opening a protected bite must not deal instant damage.")
	await ticks(780)
	check(not blue.is_immobilized() and not red.is_immobilized()
		and not attacker.is_invulnerable(), "Bite must clean up movement and protection states.")
	check(victim.current_health == 90 and attacker.current_health == 100,
		"Protected vampire must deal ten damage without receiving reciprocal damage.")
	await remove_arena(arena)


func test_shared_statuses_and_wounds() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.set_physics_process(false)
	red.set_physics_process(false)
	var source_a := Node.new()
	var source_b := Node.new()
	root.add_child(source_a)
	root.add_child(source_b)
	blue.set_invulnerable(source_a, true)
	blue.set_invulnerable(source_b, true)
	blue.set_invulnerable(source_a, false)
	check(blue.is_invulnerable() and blue.take_damage(5) == 0,
		"One ability must not remove another ability's protection.")
	blue.set_invulnerable(source_b, false)
	check(blue.take_damage(5) == 5, "Damage must resume after all protection sources end.")
	blue.hold_motion(source_a)
	blue.hold_motion(source_b)
	blue.release_motion(source_a, Vector2.LEFT)
	check(blue.freeze, "One ability must not release another ability's movement hold.")
	blue.release_motion(source_b, Vector2.RIGHT)
	check(not blue.freeze and blue.linear_velocity.x > 0, "Last movement hold must release correctly.")
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	blood.set_process(false)
	blood.drops.clear()
	blue.apply_bite_marks(red.global_position, 41.3)
	check(is_equal_approx(blue.bite_marks[0].distance_to(blue.bite_marks[1]), 41.3),
		"Wounds must retain the requested fang spacing.")
	blue.call("_advance_bite_marks", 1.9)
	check(blood.drops.size() == 8 and blue.bite_marks.size() == 2,
		"Wound bleeding must emit sparse pairs while marks remain.")
	blue.call("_advance_bite_marks", 0.2)
	check(blood.drops.size() == 10 and blue.wound_bleeding_remaining == 0.0,
		"Wound bleeding must stop at two seconds.")
	for drop in blood.drops:
		check(is_equal_approx(drop["radius"], 4.2), "New blood drops must be 1.5 times the old radius.")
	blue.call("_advance_bite_marks", 0.91)
	check(blue.bite_marks.is_empty() and blood.drops.size() == 10,
		"Marks must disappear after three seconds without additional bleeding.")
	source_a.queue_free()
	source_b.queue_free()
	await remove_arena(arena)


func test_visuals_and_health() -> void:
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var fangs := blue.get_node("Vampire") as VampireFangs
	blue.is_vampire = true
	blue.freeze = true
	red.freeze = true
	red.position = blue.position + Vector2(50, 180)
	fangs.aim_at_opponent()
	var aim := Vector2.UP.rotated(fangs.global_rotation)
	var expected := (red.global_position - blue.global_position).normalized()
	check(aim.dot(expected) > 0.9999, "Fangs must point towards the opponent.")
	check(fangs.get_class() == "Node2D" and fangs.find_children("*", "CollisionShape2D", true, false).is_empty(),
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
	blue.is_vampire = true
	blue.current_health = 20
	red.current_health = 25
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	var worst_penetration: float = 0.0
	for step in Engine.physics_ticks_per_second * 60:
		await physics_frame
		for ball in [blue, red]:
			var collision: CollisionShape2D = ball.get_node("CollisionShape2D")
			var radius: float = (collision.shape as CircleShape2D).radius
			check(radius >= 23.749 and radius <= 35.001, "Collider exceeded the low-health and 5-percent bite pulse bounds.")
			check(ball.current_health >= 0 and ball.current_health <= ball.max_health,
				"Live combat exceeded health bounds.")
			if ball.is_immobilized():
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


func test_tooth_immersion() -> void:
	for direction in [Vector2.RIGHT, Vector2(0.7, 0.7).normalized(), Vector2.UP]:
		var arena := new_arena()
		var blue := arena.get_node("Balls/BlueBall") as ArenaBall
		var red := arena.get_node("Balls/RedBall") as ArenaBall
		blue.opponent = null
		red.opponent = null
		blue.position = Vector2(500, 300)
		red.position = blue.position - direction * 95.0
		var fangs := red.get_node("Vampire") as VampireFangs
		check(fangs.try_bite(blue), "Immersion fixture must start a bite.")
		var spacing := red.position.distance_to(blue.position)
		var radius := red.visual_diameter() * 0.5
		var side := fangs.fang_spacing() * 0.5
		var front_surface := spacing - sqrt(35.0 * 35.0 - side * side)
		var exposed_length := fangs.fang_tip_depth() - sqrt(radius * radius - side * side)
		var hidden_fraction := (fangs.fang_tip_depth() - front_surface) / exposed_length
		check(absf(hidden_fraction - 1.0 / 3.0) < 0.01,
			"Opening bite must immerse one third of the long fangs.")
		check(spacing >= 70.0, "Circular bodies must remain separate during immersion.")
		check(red.z_index + fangs.z_index < blue.z_index
			and red.z_index + fangs.z_index > arena.z_index,
			"Fangs must render above the floor but behind the victim body.")
		await remove_arena(arena)
	var arena := new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.opponent = null
	red.opponent = null
	red.position = Vector2(36, 36)
	blue.position = Vector2(86, 36)
	var fangs := red.get_node("Vampire") as VampireFangs
	check(fangs.try_bite(blue), "Wall-adjacent immersion must start.")
	for ball in [red, blue]:
		check(ball.position.x >= 35.0 and ball.position.y >= 35.0,
			"Immersion must not push either body outside the arena.")
	await remove_arena(arena)


func test_bite_body_pulse() -> void:
	var arena := new_arena()
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	red.opponent = null
	blue.opponent = null
	var fangs := red.get_node("Vampire") as VampireFangs
	check(fangs.try_bite(blue), "Pulse fixture must start a bite.")
	var fixed_fang_size := fangs.fang_diameter()
	var art := red.get_node("ApprovedVampireArt")
	red.bite_pulse_elapsed = 0.0
	art.call("_process", 0.0)
	var body := art.get_node("BodyAndFur") as Sprite2D
	var teeth := art.get_node("Teeth") as Sprite2D
	var full_body_scale := body.scale.x
	var fixed_tooth_scale := teeth.scale.x
	red.bite_pulse_elapsed = 0.5 / red.bite_pulse_frequency
	red.call("_sync_pulse_shape")
	art.call("_process", 0.0)
	check(is_equal_approx(red.visual_diameter(), 66.5),
		"Feeding body must pulse between 70 and 66.5: five percent.")
	check(is_equal_approx(body.scale.x / full_body_scale, 0.95)
		and is_equal_approx(teeth.scale.x, fixed_tooth_scale)
		and is_equal_approx(fangs.fang_diameter(), fixed_fang_size),
		"Only the body sprite may pulse; tooth sprite and bite geometry must stay fixed.")
	check(is_equal_approx(((red.get_node("CollisionShape2D") as CollisionShape2D).shape
		as CircleShape2D).radius, 33.25), "Collider must follow the subtle body pulse.")
	await remove_arena(arena)


func test_carried_direction() -> void:
	for speed in [180.0, 320.0, 600.0]:
		var arena := new_arena()
		var red := arena.get_node("Balls/RedBall") as ArenaBall
		var blue := arena.get_node("Balls/BlueBall") as ArenaBall
		red.opponent = null
		blue.opponent = null
		red.position = Vector2(420, 250)
		blue.position = Vector2(515, 250)
		red.movement_speed = speed
		# Incoming vampire moves down, while the victim is to its right.
		red.linear_velocity = Vector2.DOWN * speed
		var fangs := red.get_node("Vampire") as VampireFangs
		check(fangs.try_bite(blue), "Carried-motion fixture must start.")
		var start := blue.position
		var attacker_start := red.position
		await ticks(60)
		var elapsed: float = fangs.get("_bite_elapsed")
		var displacement := blue.position - start
		check(absf(displacement.x) < 0.01 and displacement.y > 0.0,
			"Victim must inherit the vampire's incoming direction, not aim toward it.")
		check(absf(displacement.length() / elapsed - speed / 3.0) < 0.05,
			"Measured victim displacement must match one-third speed for different vampire speeds.")
		check(red.position.distance_to(attacker_start) < 0.01,
			"Attacker must remain stationary while its incoming motion is carried by the victim.")
		# Put the victim close to the lower wall to exercise a reflected trajectory.
		blue.position.y = arena.arena_size.y - 42.0
		blue.reset_physics_interpolation()
		await ticks(60)
		check(blue.position.y <= arena.arena_size.y - 35.0 + 0.1
			and (fangs.get("_carry_velocity") as Vector2).y < 0.0,
			"Carried victim must bounce at the arena wall.")
		start = blue.position
		var before_elapsed: float = fangs.get("_bite_elapsed")
		await ticks(60)
		elapsed = float(fangs.get("_bite_elapsed")) - before_elapsed
		check(absf(blue.position.distance_to(start) / elapsed - speed / 3.0) < 0.05,
			"Measured speed must remain one third after wall reflection.")
		await remove_arena(arena)
