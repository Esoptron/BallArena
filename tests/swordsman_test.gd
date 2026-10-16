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
	var arena := ARENA.instantiate() as BallArena
	arena.randomize_spawns = false
	root.add_child(arena)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var sword := blue.get_node("Sword") as SwordAbility
	var fangs := red.get_node("Vampire") as VampireFangs
	# Baseline orbit and cooldown checks are isolated from the separately tested proc.
	sword.berserk_chance = 0.0
	sword.set_physics_process(false)
	fangs.set_physics_process(false)
	check(blue.is_swordsman and not blue.is_vampire and red.is_vampire,
		"Default battle must be swordsman versus vampire.")
	var speed := blue.movement_speed
	var hp := red.current_health
	var initial_spin := sword.spin_direction
	check(sword.try_hit(red) and red.current_health == hp - sword.base_damage,
		"Sword must apply its configured initial damage.")
	check(sword.current_damage == sword.base_damage + sword.damage_gain
		and is_equal_approx(blue.movement_speed, speed + sword.speed_gain),
		"Successful sword hits must grow damage and body speed.")
	check(sword.spin_direction == -initial_spin, "Every successful hit must reverse orbit direction.")
	check(not sword.try_hit(red), "One continuous contact must not deal repeated damage every physics tick.")
	sword._contact_victim = null
	check(not sword.try_hit(red), "One-second cooldown must prevent another hit.")
	sword.cooldown_remaining = 0.0
	check(sword.slow_remaining > 0.0 and sword.try_hit(red), "Reduced rotation speed must allow hits after cooldown.")
	sword.slow_remaining = 0.0; sword.cooldown_remaining = 0.0; sword._contact_victim = null
	red.set_invulnerable(red, true)
	var blocked_spin := sword.spin_direction
	var damage := sword.current_damage
	var hits := sword.successful_hits
	check(not sword.try_hit(red) and sword.successful_hits == hits and sword.current_damage == damage and sword.spin_direction == blocked_spin,
		"Blocked hits must not grow damage or speed.")
	red.set_invulnerable(red, false)
	blue.paralyze(0.5)
	check(not sword.try_hit(red), "Paralyzed swordsman must not swing at a feeding vampire.")
	blue.paralysis_remaining = 0.0
	blue.release_motion(blue, Vector2.RIGHT)
	red.position = blue.position + Vector2(100,0)
	check(sword.intersects_target(red,0.0) and not sword.intersects_target(red,PI),
		"Only the blade segment may hit; the opposite side must remain exposed.")
	red.position = blue.position + Vector2(300,0)
	var orbit_start := sword.rotation
	sword.slow_remaining = 0.0; sword.cooldown_remaining = 0.0; sword._contact_victim = null
	sword.combat_step(0.1)
	check(absf(sword.rotation-orbit_start-sword.spin_direction*sword.spin_speed*0.1) < 0.0001,
		"Blade must orbit at its configured angular speed without aiming at the opponent.")
	check(not sword.intersects_target(red,0.0), "Sword must not damage distant opponents.")
	check(sword.get_child_count() == 0, "Sword must stay non-solid and not block body collisions.")
	red.current_health = 10000
	for hit in maxi(30, sword.max_damage - sword.base_damage + 2):
		sword.slow_remaining = 0.0; sword.cooldown_remaining = 0.0; sword._contact_victim = null
		var before_spin := sword.spin_direction
		check(sword.try_hit(red), "Cap fixture must keep applying valid hits.")
		check(sword.spin_direction == -before_spin, "Each successive hit must reverse orbit direction again.")
	check(sword.current_damage == sword.max_damage and blue.movement_speed <= sword.max_speed,
		"Damage and speed growth must stop at the configured caps.")
	sword.reset_progression(arena.ball_speed)
	check(sword.successful_hits == 0 and sword.current_damage == sword.base_damage
		and is_equal_approx(blue.movement_speed, speed), "Restart must clear all sword progression.")
	# Exercise swept contact and reflection through the real director, not just try_hit.
	blue.freeze = true; red.freeze = true
	blue.position = Vector2(430,300); red.position = Vector2(530,300)
	red.current_health = 100
	sword.rotation = -0.45
	sword.spin_direction = 1
	sword.slow_remaining = 0.0; sword.cooldown_remaining = 0.0; sword._contact_victim = null
	sword.combat_step(0.5/sword.spin_speed)
	arena.director._physics_process(0.0)
	check(sword.successful_hits == 1 and red.current_health == 100-sword.base_damage
		and sword.spin_direction == -1,
		"Swept blade contact must deal damage and reverse orbit direction.")
	var reflected_angle := sword.rotation
	sword.combat_step(0.01)
	check(is_equal_approx(sword.rotation, reflected_angle - sword.spin_speed * 0.01 / 3.0) and sword.successful_hits == 1,
		"Orbit must continue at one third speed after a hit.")
	sword.slow_remaining = 0.0; sword.cooldown_remaining = 0.0; sword._contact_victim = null
	sword.combat_step(0.01)
	check(sword.rotation < reflected_angle, "Orbit must resume backwards after cooldown.")
	arena.queue_free()
	await process_frame
	var starts: Array[Vector2] = []
	for seed_value in 32:
		var sample := ARENA.instantiate() as BallArena
		sample.spawn_seed = seed_value+9000
		root.add_child(sample)
		var a := sample.get_node("Balls/BlueBall") as ArenaBall
		var b := sample.get_node("Balls/RedBall") as ArenaBall
		starts.append(a.position)
		for ball in [a,b]:
			check(ball.position.x >= 35 and ball.position.x <= 925
				and ball.position.y >= 35 and ball.position.y <= 565,
				"Random spawns must stay within walls.")
		check(a.position.distance_to(b.position) >= 154,
			"Random characters must not spawn overlapping or in attack range.")
		sample.queue_free()
		await process_frame
	check(starts[0].distance_to(starts[1]) > 1.0, "Different seeds must produce different starts.")
	var replay := ARENA.instantiate() as BallArena
	replay.spawn_seed = 9000
	replay.blue_character = 1
	replay.red_character = 2
	root.add_child(replay)
	check((replay.get_node("Balls/BlueBall") as ArenaBall).position.is_equal_approx(starts[0]),
		"Seeded starts must be reproducible when swapping character colors.")
	check((replay.get_node("Balls/RedBall") as ArenaBall).is_swordsman
		and (replay.get_node("Balls/BlueBall") as ArenaBall).is_vampire,
		"Both sword and vampire abilities must work for either character color.")
	replay.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: sword damage/speed growth, cooldown, protection/paralysis, orbital blade reach and hit reversal, non-solid weapon and random safe starts")
		quit(0)
	else:
		quit(1)
