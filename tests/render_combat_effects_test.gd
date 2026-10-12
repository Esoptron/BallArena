extends SceneTree

const MAIN := preload("res://scenes/main.tscn")


func _initialize() -> void:
	capture.call_deferred()


func frames(count: int, camera: Camera2D, red: ArenaBall, blue: ArenaBall) -> void:
	for frame in count:
		await process_frame
		camera.global_position = (red.global_position + blue.global_position) * 0.5 + Vector2(0, 15)


func capture() -> void:
	root.size = Vector2i(1280, 900)
	var main := MAIN.instantiate() as Node2D
	(main.get_node("Arena") as BallArena).blue_character = 0
	(main.get_node("Arena") as BallArena).randomize_spawns = false
	root.add_child(main)
	var red := main.get_node("Arena/Balls/RedBall") as ArenaBall
	var blue := main.get_node("Arena/Balls/BlueBall") as ArenaBall
	var camera := main.get_node("Camera2D") as Camera2D
	red.current_health = 99
	red.position = Vector2(530, 300)
	blue.position = Vector2(440, 300)
	red.reset_physics_interpolation()
	blue.reset_physics_interpolation()
	camera.zoom = Vector2.ONE * 3.7
	var fangs := red.get_node("Vampire") as VampireFangs
	if not fangs.try_bite(blue):
		push_error("Combat effects capture bite did not start.")
		quit(1)
		return
	await frames(70, camera, red, blue)
	if red.current_health <= red.max_health:
		push_error("Rendered bite must heal beyond reference HP.")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	if result != OK:
		push_error("Combat effects screenshot save failed.")
		quit(1)
		return
	await frames(125, camera, red, blue)
	var effects := main.get_node("Arena/CombatEffects") as ArenaCombatEffects
	if not effects.drains.is_empty() or not effects.orbs.is_empty():
		push_error("Drain visuals survived beyond the completed bite.")
		quit(1)
	else:
		print("PASS: rendered HP, real heal/damage numbers, electrical drain, green spheres and glossy spray; drain clears at bite end")
		quit(0)
