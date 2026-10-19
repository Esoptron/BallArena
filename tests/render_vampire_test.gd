extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
var destination: String
var capture_viewport: SubViewport


func _initialize() -> void:
	destination = OS.get_cmdline_user_args()[0]
	capture.call_deferred()


func frames(count: int) -> void:
	for frame in count:
		await process_frame


func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := capture_viewport.get_texture().get_image().save_png(destination.path_join(name))
	if result != OK:
		push_error("Could not save rendered frame: %s" % result)
		quit(1)


func capture() -> void:
	# Always render offscreen: a hidden/occluded test window must not suspend
	# frame_post_draw while the longer sequence waits between captures.
	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(1280, 900)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var main := MAIN.instantiate() as Node2D
	(main.get_node("Arena") as BallArena).blue_character = 0
	(main.get_node("Arena") as BallArena).randomize_spawns = false
	capture_viewport.add_child(main)
	var blue := main.get_node("Arena/Balls/BlueBall") as ArenaBall
	var red := main.get_node("Arena/Balls/RedBall") as ArenaBall
	await frames(6)
	await save_frame("vampire-aura.png")
	await save_detail(main, red.global_position, "vampire-details-aura.png")
	await save_detail(main, blue.global_position, "ordinary-ball-details.png")
	var blue_fangs := blue.get_node("Vampire") as VampireFangs
	var red_fangs := red.get_node("Vampire") as VampireFangs
	blue.position = Vector2(430, 300)
	red.position = Vector2(520, 300)
	blue.reset_physics_interpolation()
	red.reset_physics_interpolation()
	if not red_fangs.try_bite(blue):
		push_error("Red bite did not start.")
		quit(1)
		return
	await frames(36)
	await save_frame("vampire-protected-bite.png")
	await save_detail(main, (red.global_position + blue.global_position) * 0.5,
		"vampire-details-bite.png")
	if not red.is_invulnerable() or not red.freeze or not blue.freeze:
		push_error("The attacker must stay protected while driving helpless victim motion.")
		quit(1)
		return
	await frames(150)
	if red.is_invulnerable() or blue.bite_marks.size() != 2:
		push_error("Release must remove protection and leave bite wounds.")
		quit(1)
		return
	await save_frame("vampire-blood.png")
	await save_detail(main, red.global_position, "vampire-details-stained.png")
	await frames(115)
	await save_frame("vampire-wounds.png")
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
	red.current_health = 100
	red.set("_visual_time", 0.0)
	red.position = Vector2(480, 300)
	blue.position = red.position + Vector2(0, 250)
	blue.set_physics_process(false)
	red_fangs.has_bitten = true
	red_fangs.aim_at_opponent()
	await save_detail(main, red.global_position + Vector2(0, 9), "approved-reference-in-game.png", 8.0)
	print("PASS: rendered aura, first-bite blood, and 70/50 low-health pulse from the canonical Desktop project")
	quit(0)


func save_detail(main: Node2D, focus: Vector2, file_name: String, magnification: float = 4.0) -> void:
	var camera := main.get_node("Camera2D") as Camera2D
	var previous_zoom := camera.zoom
	var previous_position := camera.global_position
	camera.zoom = Vector2.ONE * magnification
	camera.global_position = focus
	await frames(2)
	await save_frame(file_name)
	camera.zoom = previous_zoom
	camera.global_position = previous_position
	await frames(2)