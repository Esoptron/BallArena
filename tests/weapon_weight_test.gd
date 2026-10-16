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
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var sword_body := arena.get_node("Balls/BlueBall") as ArenaBall
	var vampire := arena.get_node("Balls/RedBall") as ArenaBall
	var sword := sword_body.get_node("Sword") as SwordAbility
	check(is_equal_approx(sword_body.diameter, 70.0) and is_equal_approx(vampire.diameter, 77.0), "Profiles must apply independent size multipliers.")
	check(is_equal_approx(sword_body.mass, 1.0) and is_equal_approx(vampire.mass, 1.3), "Profiles must feed real body collision masses.")
	check(sword.definition.weapon_weight_class == 2, "Sword must have medium weapon weight.")
	var light_angle := 0.0
	var heavy_angle := 0.0
	for category in [0, 4]:
		vampire.weight_class = category
		vampire.linear_velocity = Vector2.RIGHT * vampire.movement_speed
		vampire.receive_weapon_impact(Vector2.DOWN, 2, 240.0)
		check(is_equal_approx(vampire.linear_velocity.length(), vampire.movement_speed), "Impact must preserve configured movement speed.")
		if category == 0:
			light_angle = vampire.linear_velocity.angle()
		else:
			heavy_angle = vampire.linear_velocity.angle()
	check(light_angle > heavy_angle and heavy_angle > 0.0, "A heavy target must deflect less than a light target.")
	vampire.weight_class = 2
	vampire.linear_velocity = Vector2.RIGHT * vampire.movement_speed
	vampire.receive_weapon_impact(Vector2.DOWN, 0, 240.0)
	var light_weapon_angle := vampire.linear_velocity.angle()
	vampire.linear_velocity = Vector2.RIGHT * vampire.movement_speed
	vampire.receive_weapon_impact(Vector2.DOWN, 4, 240.0)
	check(vampire.linear_velocity.angle() > light_weapon_angle, "A heavy weapon must deflect more than a light weapon.")
	vampire.set_invulnerable(vampire, true)
	var velocity := vampire.linear_velocity
	check(is_zero_approx(vampire.receive_weapon_impact(Vector2.LEFT, 4, 240.0)) and vampire.linear_velocity == velocity, "Protection must block weapon impulses.")
	vampire.set_invulnerable(vampire, false)
	vampire.hold_motion(vampire)
	check(is_zero_approx(vampire.receive_weapon_impact(Vector2.LEFT, 4, 240.0)), "Captured bodies must not be displaced by weapon impacts.")
	vampire.release_motion(vampire, Vector2.RIGHT)
	vampire.weight_class = 3
	vampire.linear_velocity = Vector2.RIGHT * vampire.movement_speed
	sword_body.position = Vector2(400,300)
	vampire.position = Vector2(500,300)
	sword.rotation = 0.0
	var before := vampire.linear_velocity
	var original_spin := sword.spin_direction
	check(sword.try_hit(vampire) and vampire.linear_velocity.distance_to(before) > 1.0, "An actual sword hit must redirect the heavier vampire.")
	check(sword.spin_direction == -original_spin and is_equal_approx(sword.cooldown_remaining, 1.0) and is_equal_approx(sword.slow_remaining, 3.0), "Weight must preserve reversal, cooldown and slow rotation.")
	check(is_equal_approx(vampire.linear_velocity.length(), vampire.effective_movement_speed()), "Sword hit must preserve the victim health-adjusted speed.")
	await physics_frame
	await physics_frame
	check(vampire.linear_velocity.y > 0.0, "Physics integration must retain the changed trajectory.")
	arena.queue_free()
	await process_frame
	var equal_bounce := await body_collision(2)
	var heavy_bounce := await body_collision(3)
	print("Body trajectories: ", equal_bounce, " / ", heavy_bounce, " difference ", equal_bounce.distance_to(heavy_bounce))
	check(equal_bounce.distance_to(heavy_bounce) > 0.0001, "Actual body collisions must depend on target mass.")
	print("Weapon weight: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)


func body_collision(target_class: int) -> Vector2:
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.blue_character = 0
	arena.red_character = 0
	arena.randomize_spawns = false
	arena.character_overrides = {"ordinary": {"weight_class": 2}}
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	red.weight_class = target_class
	red.mass = preload("res://scripts/combat/weight_classes.gd").factor(target_class)
	blue.position = Vector2(420, 300)
	red.position = Vector2(520, 300)
	blue.initial_direction = Vector2.RIGHT
	red.initial_direction = Vector2(-1.0, 0.25)
	blue.start_motion()
	red.start_motion()
	for tick in 40:
		await physics_frame
	var result := blue.linear_velocity.normalized()
	check(result.x < 0.0, "Collision fixture must bounce the approaching body.")
	arena.queue_free()
	await process_frame
	return result
