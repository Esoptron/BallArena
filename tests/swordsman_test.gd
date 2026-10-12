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
	sword.set_physics_process(false)
	fangs.set_physics_process(false)
	check(blue.is_swordsman and not blue.is_vampire and red.is_vampire,
		"Default battle must be swordsman versus vampire.")
	var speed := blue.movement_speed
	var hp := red.current_health
	check(sword.try_hit(red) and red.current_health == hp - sword.base_damage,
		"Sword must apply its configured initial damage.")
	check(sword.current_damage == sword.base_damage + sword.damage_gain
		and is_equal_approx(blue.movement_speed, speed + sword.speed_gain),
		"Successful sword hits must grow damage and body speed.")
	check(not sword.try_hit(red), "Sword cooldown must prevent damage every physics tick.")
	sword.cooldown_remaining = 0.0
	red.set_invulnerable(red, true)
	var damage := sword.current_damage
	var hits := sword.successful_hits
	check(not sword.try_hit(red) and sword.successful_hits == hits and sword.current_damage == damage,
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
	check(not sword.intersects_target(red,0.0), "Sword must not damage distant opponents.")
	check(sword.get_child_count() == 0, "Sword must stay non-solid and not block body collisions.")
	sword.reset_progression(arena.ball_speed)
	check(sword.successful_hits == 0 and sword.current_damage == sword.base_damage
		and is_equal_approx(blue.movement_speed, speed), "Restart must clear all sword progression.")
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
		print("PASS: sword damage/speed growth, cooldown, protection/paralysis, directional blade reach, non-solid weapon and random safe starts")
		quit(0)
	else:
		quit(1)
