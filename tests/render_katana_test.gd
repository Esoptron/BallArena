extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,900)
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	var arena := main.get_node("Arena") as BallArena
	arena.blue_character_id = &"katana"
	arena.randomize_spawns = false
	root.add_child(main)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	a.freeze = true
	b.freeze = true
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.position = Vector2(380,330)
	b.position = Vector2(620,330)
	var katana := a.get_node("Katana") as KatanaAbility
	katana.rotation = -PI * 0.25
	var camera := main.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2.ONE * 2.7
	camera.global_position = Vector2(500,305)
	# Preview the reusable stack indicator and critical notice, without modifying HP.
	b.add_bleeding(a,1,1.0,&"katana")
	b.deepen_katana_wound()
	b.add_bleeding(a,1,1.0,&"katana")
	arena.get_node("CombatEffects").spawn_notice(b.global_position,"КРОВЬ",Color(1.0,0.74,0.36))
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_user_args().is_empty():
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PASS: long curved light katana and bleeding indicator rendered")
	main.queue_free()
	await process_frame
	quit(0)
