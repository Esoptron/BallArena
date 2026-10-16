extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1100,650)
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.randomize_spawns = false
	arena.blue_character_id = &"knifeman"
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var knife := arena.get_node("Balls/BlueBall") as ArenaBall
	var vampire := arena.get_node("Balls/RedBall") as ArenaBall
	knife.position = Vector2(480,300)
	vampire.position = Vector2(400,300)
	var camera := Camera2D.new()
	camera.position = Vector2(400,300)
	camera.zoom = Vector2.ONE*3
	root.add_child(camera)
	var fangs := vampire.get_node("Vampire") as VampireFangs
	var daggers := knife.get_node("Knives") as DaggerAbility
	daggers.capture_counter_chance = 1
	if not fangs.try_bite(knife): quit(1); return
	fangs._bite_tick()
	for body in [knife,vampire]:
		body.freeze = true
		body.set_physics_process(false)
	var effects := arena.get_node("CombatEffects") as ArenaCombatEffects
	effects.set_process(false)
	for slash in effects.counter_slashes: slash["age"] = 0.045
	effects.queue_redraw()
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PASS counter preview" if result == OK else "FAIL counter preview")
	quit(0 if result == OK else 1)
