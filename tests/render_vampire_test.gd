extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
var destination: String


func _initialize() -> void:
	destination = OS.get_cmdline_user_args()[0]
	capture.call_deferred()


func frames(count: int) -> void:
	for frame in count:
		await process_frame


func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(destination.path_join(name))
	if result != OK:
		push_error("Could not save rendered frame: %s" % result)
		quit(1)


func capture() -> void:
	root.size = Vector2i(1280, 900)
	var main := MAIN.instantiate() as Node2D
	root.add_child(main)
	var blue := main.get_node("Arena/Balls/BlueBall") as ArenaBall
	var red := main.get_node("Arena/Balls/RedBall") as ArenaBall
	await frames(6)
	await save_frame("vampire-aura.png")
	await frames(142)
	var blue_fangs := blue.get_node("Vampire") as VampireFangs
	var red_fangs := red.get_node("Vampire") as VampireFangs
	if blue_fangs.has_bitten or not red_fangs.has_bitten:
		push_error("The default gameplay must produce a red bite without a blue bite.")
		quit(1)
		return
	await save_frame("vampire-blood.png")
	blue_fangs.call("_finish_bite")
	red_fangs.call("_finish_bite")
	blue_fangs.cooldown_remaining = 1000.0
	red_fangs.cooldown_remaining = 1000.0
	red.current_health = 20
	blue.freeze = true
	red.freeze = true
	blue.position = Vector2(350, 270)
	red.position = Vector2(640, 360)
	blue.reset_physics_interpolation()
	red.reset_physics_interpolation()
	red.set_process(false)
	red.set_physics_process(false)
	red.set("_visual_time", 0.0)
	red.queue_redraw()
	await frames(2)
	await save_frame("vampire-low-health-70.png")
	red.set("_visual_time", 0.5 / red.pulse_frequency)
	red.queue_redraw()
	await frames(2)
	await save_frame("vampire-low-health-50.png")
	print("PASS: rendered aura, first-bite blood, and 70/50 low-health pulse from the canonical Desktop project")
	quit(0)
