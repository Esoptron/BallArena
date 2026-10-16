extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,900)
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	var arena := main.get_node("Arena") as BallArena
	arena.blue_character_id = &"swordsman"
	arena.red_character_id = &"swordsman"
	arena.randomize_spawns = false
	root.add_child(main)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	a.freeze = true
	b.freeze = true
	a.position = Vector2(390,300)
	b.position = Vector2(570,300)
	a.get_node("Sword").rotation = 0.0
	b.get_node("Sword").rotation = PI
	var effects := arena.get_node("CombatEffects") as ArenaCombatEffects
	effects.set_process(false)
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	blood.set_process(false)
	var camera := main.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2.ONE * 3.0
	camera.global_position = Vector2(480,300)
	for frame in 8:
		await process_frame
	arena.director._physics_process(0.0)
	effects.advance(0.045)
	blood.spawn_hit_blood(b.global_position + Vector2(20,0))
	blood.advance(0.1)
	for position in [Vector2(30,590),Vector2(955,270),Vector2(200,5)]:
		blood._surface_splash(position,Vector2.UP,4.2)
	blood.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_user_args().is_empty():
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PASS: sparks, glossy blood and surface splashes rendered")
	main.queue_free()
	await process_frame
	quit(0)
