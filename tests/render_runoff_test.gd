extends SceneTree

const BALL := preload("res://scenes/ball.tscn")


func _initialize() -> void:
	capture.call_deferred()


func frames(count: int) -> void:
	for frame in count:
		await process_frame


func capture() -> void:
	root.size = Vector2i(1600, 900)
	RenderingServer.set_default_clear_color(Color(0.055, 0.07, 0.10))
	var camera := Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position = Vector2(240, 130)
	camera.zoom = Vector2.ONE * 3.0
	root.add_child(camera)
	var args := OS.get_cmdline_user_args()
	var fade_mode := args.size() > 1 and args[1] == "fade"
	var ages := [0.0, 1.0, 2.0, 3.0, 4.0, 4.9]
	for index in ages.size():
		var ball := BALL.instantiate() as ArenaBall
		ball.is_vampire = false
		ball.position = Vector2(40 + index * 80, 120)
		root.add_child(ball)
		ball.freeze = true
		ball.set_physics_process(false)
		var blood := ArenaBlood.new()
		blood.floor_y = 270
		root.add_child(blood)
		blood.set_process(false)
		ball.blood_effects = blood
		ball.apply_bite_marks(ball.global_position + Vector2(-100, 20), 34.0)
		var runoff := ball.get_node("BloodRunoff")
		runoff.set_process(false)
		var arrival: float = runoff.get("first_arrival")
		var stages := [0.0, arrival * 0.45, arrival + 0.15, arrival + 0.43, arrival + 0.66, arrival + 0.82]
		var age: float = ages[index] if fade_mode else stages[index]
		if fade_mode:
			ball.blood_effects = null
			ball.call("_advance_bite_marks", age)
		runoff.call("advance", age)
		if index == ages.size() - 1:
			blood.advance(0.10)
	await frames(4)
	await RenderingServer.frame_post_draw
	var target := OS.get_cmdline_user_args()[0]
	var result := root.get_texture().get_image().save_png(target)
	if result != OK:
		push_error("Runoff render save failed.")
		quit(1)
	else:
		print("PASS: six actual Godot frames from wounds through connected drop and detachment")
		quit(0)
