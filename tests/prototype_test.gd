extends SceneTree
## Run: godot --headless --path . --fixed-fps 240 --script tests/prototype_test.gd

const ARENA_SCENE := preload("res://scenes/arena.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _ball_contacts: int = 0
var _wall_contacts: int = 0
var _max_speed_error: float = 0.0
var _max_penetration: float = 0.0
var _scenario: String = "default"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_default_simulation()
	await _test_wall_reflections()
	await _test_head_on_collision()
	await _test_glancing_collision()
	await _test_parameters(Vector2(1280, 720), 72.0, 600.0)
	await _test_parameters(Vector2(480, 300), 12.0, 1800.0)
	await _test_layouts()
	print("Contacts: balls=%d, walls=%d; max speed error=%.5f; max penetration=%.3f"
		% [_ball_contacts, _wall_contacts, _max_speed_error, _max_penetration])
	if _failures.is_empty():
		print("PASS: motion, wall/corner/ball collisions, speed, parameters, viewport layout")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _new_arena(size: Vector2 = Vector2(960, 600),
		diameter: float = 70.0, speed: float = 320.0) -> BallArena:
	var arena := ARENA_SCENE.instantiate() as BallArena
	arena.arena_size = size
	arena.ball_diameter = diameter
	arena.ball_speed = speed
	root.add_child(arena)
	for ball: ArenaBall in arena.get_node("Balls").get_children():
		ball.body_entered.connect(_on_contact)
	return arena


func _on_contact(body: Node) -> void:
	if body is ArenaBall:
		_ball_contacts += 1
	elif body is StaticBody2D:
		_wall_contacts += 1


func _check(condition: bool, message: String) -> void:
	var detail := _scenario + ": " + message
	if not condition and not _failures.has(detail):
		_failures.append(detail)
		print("FAIL: ", detail)


func _simulate(arena: BallArena, ticks: int) -> void:
	var balls := arena.get_node("Balls").get_children()
	for tick in ticks:
		await physics_frame
		for ball: ArenaBall in balls:
			if ball.freeze:
				continue
			var radius := ball.diameter * 0.5
			# Godot's contact solver allows penetration within one simulation step.
			var step_distance := ball.movement_speed / Engine.physics_ticks_per_second
			var speed_error := absf(ball.linear_velocity.length() - ball.movement_speed)
			_max_speed_error = maxf(_max_speed_error, speed_error)
			_check(speed_error < 0.05, "Speed must stay at its configured value.")
			var p := ball.position
			var penetration := maxf(maxf(radius - p.x, radius - p.y),
				maxf(p.x + radius - arena.arena_size.x,
				p.y + radius - arena.arena_size.y))
			_max_penetration = maxf(_max_penetration, penetration)
			_check(penetration < maxf(2.0, step_distance + 0.1),
				"A ball escaped or deeply penetrated a wall.")
		if not (balls[0] as ArenaBall).freeze and not (balls[1] as ArenaBall).freeze:
			var separation: float = balls[0].position.distance_to(balls[1].position)
			var relative_step := arena.ball_speed * 2.0 / Engine.physics_ticks_per_second
			var tolerance := maxf(2.0, minf(arena.ball_diameter * 0.25, relative_step + 0.1))
			_check(separation >= arena.ball_diameter - tolerance,
				"Balls deeply overlapped or passed through each other.")


func _remove_arena(arena: BallArena) -> void:
	arena.queue_free()
	await process_frame


func _place(ball: ArenaBall, p: Vector2, direction: Vector2) -> void:
	ball.position = p
	ball.initial_direction = direction
	ball.start_motion()


func _test_default_simulation() -> void:
	var arena := _new_arena()
	_check(arena.get_node("Balls").get_child_count() == 2, "Exactly two balls required.")
	_check(arena.get_node("Walls").get_child_count() == 4, "Exactly four walls required.")
	# One minute of simulated time exercises repeated ball/wall contacts.
	await _simulate(arena, Engine.physics_ticks_per_second * 60)
	_check(_ball_contacts > 0, "The default trajectories never collided.")
	_check(_wall_contacts > 10, "The default balls never bounced around the arena.")
	await _remove_arena(arena)


func _test_wall_reflections() -> void:
	_scenario = "walls"
	for side: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var arena := _new_arena()
		var blue := arena.get_node("Balls/BlueBall") as ArenaBall
		var red := arena.get_node("Balls/RedBall") as ArenaBall
		red.freeze = true
		red.position = Vector2(480, 400)
		var direction := side
		var p := Vector2(480, 300)
		var inset := blue.diameter * 0.5 + 10.0
		if side == Vector2.RIGHT:
			p = Vector2(arena.arena_size.x - inset, 220)
			direction = Vector2(1, 0.35)
		elif side == Vector2.LEFT:
			p = Vector2(inset, 220)
			direction = Vector2(-1, 0.35)
		elif side == Vector2.UP:
			p = Vector2(320, inset)
			direction = Vector2(0.35, -1)
		else:
			p = Vector2(320, arena.arena_size.y - inset)
			direction = Vector2(0.35, 1)
		_place(blue, p, direction)
		await _simulate(arena, 30)
		var expected := direction.normalized().bounce(side)
		_check(blue.linear_velocity.normalized().distance_to(expected) < 0.005,
			"Wall reflection must preserve the tangent and reverse the normal component.")
		await _remove_arena(arena)
	var arena := _new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	(arena.get_node("Balls/RedBall") as ArenaBall).freeze = true
	_place(blue, arena.arena_size - Vector2.ONE * (blue.diameter * 0.5 + 2.0),
		Vector2(1, 1))
	await _simulate(arena, 30)
	_check(blue.linear_velocity.x < 0.0 and blue.linear_velocity.y < 0.0,
		"A corner hit must reflect both velocity components.")
	await _remove_arena(arena)


func _test_head_on_collision() -> void:
	_scenario = "head-on"
	var arena := _new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	_place(blue, Vector2(400, 300), Vector2.RIGHT)
	_place(red, Vector2(560, 300), Vector2.LEFT)
	await _simulate(arena, 70)
	_check(blue.linear_velocity.x < 0.0 and red.linear_velocity.x > 0.0,
		"Equal-mass head-on collision must exchange velocities.")
	_check(absf(blue.linear_velocity.y) < 0.01 and absf(red.linear_velocity.y) < 0.01,
		"Head-on collision introduced an unexpected tangential velocity.")
	await _remove_arena(arena)


func _test_glancing_collision() -> void:
	_scenario = "glancing"
	var arena := _new_arena()
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	_place(blue, Vector2(420, 280), Vector2(1, 0.25))
	_place(red, Vector2(550, 300), Vector2(-1, 0.1))
	var contacts_before := _ball_contacts
	await _simulate(arena, 120)
	_check(_ball_contacts > contacts_before, "Glancing balls did not collide.")
	_check(blue.linear_velocity.y < 0.0 and red.linear_velocity.y > 0.0,
		"Glancing collision should deflect balls away from each other.")
	await _remove_arena(arena)


func _test_parameters(size: Vector2, diameter: float, speed: float) -> void:
	_scenario = "parameters %s / diameter %s / speed %s" % [size, diameter, speed]
	var arena := _new_arena(size, diameter, speed)
	for ball: ArenaBall in arena.get_node("Balls").get_children():
		var collision := ball.get_node("CollisionShape2D") as CollisionShape2D
		_check(is_equal_approx((collision.shape as CircleShape2D).radius, diameter * 0.5),
			"Diameter parameter did not update the collision shape.")
	await _simulate(arena, 2400)
	await _remove_arena(arena)


func _test_layouts() -> void:
	_scenario = "layout"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 900)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var main := MAIN_SCENE.instantiate() as Node2D
	viewport.add_child(main)
	var arena := main.get_node("Arena") as BallArena
	var camera := main.get_node("Camera2D") as Camera2D
	for size in [Vector2i(1280, 900), Vector2i(720, 1280), Vector2i(1920, 1080),
			Vector2i(640, 360), Vector2i(2560, 1600)]:
		viewport.size = size
		await process_frame
		camera.force_update_scroll()
		var padding: Vector2 = main.get("screen_padding")
		var required := arena.arena_size + padding * 2.0
		var expected_zoom := minf(1.0, minf(size.x / required.x, size.y / required.y))
		_check(camera.zoom.is_equal_approx(Vector2.ONE * expected_zoom),
			"Viewport did not fit the arena uniformly with UI padding.")
		_check(arena.scale == Vector2.ONE and arena.arena_size == Vector2(960, 600),
			"Resizing the screen changed the physical arena.")
		var transform := viewport.get_canvas_transform() * arena.global_transform
		var top_left := transform * Vector2.ZERO
		var bottom_right := transform * arena.arena_size
		var minimum := padding * expected_zoom
		_check(top_left.x >= minimum.x - 1.0 and top_left.y >= minimum.y - 1.0
			and bottom_right.x <= size.x - minimum.x + 1.0
			and bottom_right.y <= size.y - minimum.y + 1.0,
			"Arena or reserved UI padding was cropped.")
	viewport.queue_free()
	await process_frame
