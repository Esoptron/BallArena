extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1000,650)
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var victim := arena.get_node("Balls/BlueBall") as ArenaBall
	var vampire := arena.get_node("Balls/RedBall") as ArenaBall
	victim.position = Vector2(660,300)
	vampire.position = Vector2(400,300)
	vampire.current_health = 20
	var fangs := vampire.get_node("Vampire") as VampireFangs
	fangs.cooldown_remaining = 8
	vampire.take_damage(1,victim)
	fangs._update_hunt(3.001)
	fangs._clock = 0.3
	fangs.set_process(false)
	fangs.aim_at_opponent()
	fangs.queue_redraw()
	var camera := Camera2D.new()
	camera.position = Vector2(470,300)
	camera.zoom = Vector2.ONE*2.8
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	root.add_child(camera)
	for body in [victim,vampire]:
		body.freeze = true
		body.set_physics_process(false)
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var saved := root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PASS hunting wind preview" if saved == OK else "FAIL preview")
	quit(0 if saved == OK else 1)
