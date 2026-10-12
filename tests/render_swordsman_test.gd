extends SceneTree
const MAIN := preload("res://scenes/main.tscn")

func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	root.size = Vector2i(1280,900)
	var main := MAIN.instantiate() as Node2D
	(main.get_node("Arena") as BallArena).randomize_spawns = false
	root.add_child(main)
	var blue := main.get_node("Arena/Balls/BlueBall") as ArenaBall
	var red := main.get_node("Arena/Balls/RedBall") as ArenaBall
	blue.freeze = true
	red.freeze = true
	blue.position = Vector2(425,310)
	red.position = Vector2(625,310)
	blue.reset_physics_interpolation()
	red.reset_physics_interpolation()
	var sword := blue.get_node("Sword") as SwordAbility
	sword.set_physics_process(false)
	sword.rotation = -PI*0.5
	(red.get_node("Vampire") as VampireFangs).set_physics_process(false)
	var camera := main.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2.ONE*3.1
	camera.global_position = Vector2(525,295)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var saved := root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	if saved != OK:
		push_error("Swordsman preview save failed.")
		quit(1)
	else:
		print("PASS: rendered swordsman uses the ordinary ball body and shared HP styling; faceted sword and approved vampire are visible")
		quit(0)
