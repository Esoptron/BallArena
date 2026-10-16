extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 480)
	var group := Node2D.new()
	root.add_child(group)
	for stage in range(1, 5):
		var fighter := load("res://scenes/ball.tscn").instantiate() as ArenaBall
		fighter.is_vampire = false
		fighter.is_swordsman = false
		fighter.ball_color = Color(1.0, 0.13, 0.18)
		fighter.position = Vector2(160 + (stage - 1) * 320, 230)
		fighter.scale = Vector2.ONE * 3.0
		group.add_child(fighter)
		fighter.freeze = true
		fighter.set_physics_process(false)
		fighter.get_node("HealthDisplay").hide()
		for hit in stage:
			fighter.deepen_katana_wound()
		var label := Label.new()
		label.text = str(stage)
		label.position = Vector2(fighter.position.x - 15, 370)
		label.add_theme_font_size_override("font_size", 28)
		group.add_child(label)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	if not OS.get_cmdline_user_args().is_empty():
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("PASS: four critical wound stages rendered")
	group.queue_free()
	await process_frame
	quit(0)
