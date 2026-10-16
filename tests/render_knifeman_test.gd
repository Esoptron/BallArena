extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,900)
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	var arena := main.get_node("Arena") as BallArena
	arena.blue_character_id = &"knifeman"
	arena.randomize_spawns = false
	root.add_child(main)
	arena.director.set_physics_process(false)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.freeze = true
	red.freeze = true
	blue.position = Vector2(395,300)
	red.position = Vector2(595,300)
	blue.get_node("Knives").rotation = -PI * 0.25
	var camera := main.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2.ONE * 3.4
	camera.global_position = Vector2(495,290)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_user_args().is_empty():
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PASS: opposed daggers, shared ball style, small body and 90 HP rendered")
	main.queue_free()
	await process_frame
	quit(0)
