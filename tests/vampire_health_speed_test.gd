extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for frame in count: await physics_frame
func run() -> void:
	root.size = Vector2i(1280,900)
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	var arena := main.get_node("Arena") as BallArena
	arena.blue_character_id = &"ordinary"
	arena.red_character_id = &"vampire"
	arena.randomize_spawns = false
	root.add_child(main)
	arena.director.set_physics_process(false)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var fangs := red.get_node("Vampire") as VampireFangs
	for pair in [[100,1.0],[150,0.75],[50,1.25],[1,1.495],[1000,0.25]]:
		red.current_health = pair[0]
		red.position = Vector2(650,300)
		red.wall_speed_bonus = 0.0
		red.linear_velocity = Vector2.RIGHT * 320.0
		blue.position = Vector2(250,300)
		blue.current_health = pair[0]
		blue.wall_speed_bonus = 0.0
		await frames(6)
		check(absf(red.actual_movement_speed() - 320.0 * pair[1]) < 0.05,"Actual vampire travel must match HP=%s ratio." % pair[0])
		check(absf(blue.actual_movement_speed() - 320.0) < 0.05,"Other characters must retain speed independently of HP.")
		check(red.movement_speed == 320.0,"Health curve must not compound or rewrite base speed.")
	red.current_health = 50
	red.heal(100)
	await frames(6)
	check(absf(red.actual_movement_speed() - 240.0) < 0.05,"Real healing to 150 HP must slow movement.")
	red.take_damage(100,blue)
	await frames(6)
	check(absf(red.actual_movement_speed() - 400.0) < 0.05,"Real damage to 50 HP must accelerate movement.")
	red.wall_boost_scale = 1.0
	red.boost_decay_seconds = 3.0
	red.gain_wall_boost()
	check(is_equal_approx(red.wall_speed_bonus,80.0),"Above-average wall boost must use health-adjusted base speed.")
	await frames(6)
	check(red.actual_movement_speed() > 400.0,"Wall bonus must coexist with health speed.")
	red.wall_speed_bonus = 0.0
	red.position = Vector2(420,250)
	blue.position = Vector2(530,250)
	red.linear_velocity = Vector2.DOWN * 400.0
	blue.current_health = 100
	red.opponent = null
	blue.opponent = null
	check(fangs.try_bite(blue),"Health-speed capture fixture must start.")
	var attachment := blue.position - red.position
	var start := red.position
	check(absf(red.actual_movement_speed() - 400.0/3.0) < 0.05 and is_equal_approx(red.actual_movement_speed(),blue.actual_movement_speed()),"Corner speed API must report attached pair transport rather than zero.")
	arena.director.set_physics_process(true)
	await frames(150)
	check(red.position.distance_to(start) > 50 and (blue.position-red.position).distance_to(attachment) < 0.05,"Attached actors must move together with no separation.")
	check(absf(red.actual_movement_speed() - red.adjusted_movement_speed()/3.0) < 0.05,"Feeding movement must update as healing changes HP.")
	check(red.current_health > 50 and red.actual_movement_speed() < 400.0/3.0,"Feeding healing must gradually reduce pair speed.")
	await frames(585)
	check(fangs.bite_target == null and blue.current_health == 100-fangs.bite_units and red.current_health == 50+fangs.heal_units,"Three-second bite damage, healing and release must remain intact.")
	check(red.transport_velocity.is_zero_approx() and blue.transport_velocity.is_zero_approx(),"Release must clear transport speed for both actors.")
	check(absf(red.actual_movement_speed() - red.effective_movement_speed()) < 0.05,"Released vampire must use its health-adjusted travel speed.")
	arena.director.set_physics_process(false)
	red.current_health = 150
	red.position = Vector2(660,300)
	blue.position = Vector2(290,300)
	red.wall_speed_bonus = 0.0
	blue.wall_speed_bonus = 0.0
	await frames(6)
	main.progression.refresh()
	check(main.progression.speed_labels[0].text == "320" and main.progression.speed_labels[1].text == "240","Corner must show blue and red numeric speeds with no captions or units.")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	red.take_damage(10000,blue)
	check(red.actual_movement_speed() == 0.0,"Dead vampire must not move despite low-HP boost.")
	main.progression.refresh()
	check(main.progression.speed_labels[1].text == "0","Corner must show zero for dead actors.")
	main.queue_free()
	await process_frame
	print("Vampire HP curve, actual corner speeds and carried motion: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
