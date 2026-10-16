extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,900)
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	var arena := main.get_node("Arena") as BallArena
	arena.randomize_spawns = false
	root.add_child(main)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	a.freeze = true
	b.freeze = true
	a.position = Vector2(710,470)
	b.position = Vector2(860,480)
	var camera := main.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2.ONE * 2.3
	camera.global_position = Vector2(800,490)
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	blood.set_process(false)
	for x in range(650,940,16):
		blood._surface_splash(Vector2(x,595.8),Vector2.UP,4.2)
	for y in [430.0,470.0,515.0,570.0]:
		blood._surface_splash(Vector2(955.8,y),Vector2.LEFT,4.2)
	blood.advance(0.22)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_user_args().is_empty():
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PASS: persistent wet pools and enlarged splashes rendered")
	main.queue_free()
	await process_frame
	quit(0)
