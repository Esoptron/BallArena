extends SceneTree
const ARENA := preload("res://scenes/arena.tscn")
const WEIGHTS := preload("res://scripts/combat/weight_classes.gd")
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func ticks(count: int) -> void:
	for tick in count:
		await physics_frame
func new_arena() -> BallArena:
	var arena := ARENA.instantiate() as BallArena
	arena.blue_character = 0
	arena.red_character = 0
	arena.randomize_spawns = false
	root.add_child(arena)
	return arena
func place(ball: ArenaBall, point: Vector2, direction: Vector2, category: int) -> void:
	ball.position = point
	ball.initial_direction = direction
	ball.weight_class = category
	ball.mass = WEIGHTS.factor(category)
	ball.start_motion()
func remove(arena: BallArena) -> void:
	arena.queue_free()
	await process_frame
func body_case(category_a: int, category_b: int, glance: bool) -> Dictionary:
	var arena := new_arena()
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	place(a,Vector2(400,300) if not glance else Vector2(420,280),Vector2.RIGHT if not glance else Vector2(1,0.25),category_a)
	place(b,Vector2(560,300) if not glance else Vector2(550,300),Vector2.LEFT if not glance else Vector2(-1,0.1),category_b)
	a.gain_wall_boost()
	b.gain_wall_boost()
	a.linear_velocity = a.initial_direction.normalized() * a.effective_movement_speed()
	b.linear_velocity = b.initial_direction.normalized() * b.effective_movement_speed()
	var events: Array[Dictionary] = []
	arena.director.event_recorded.connect(func(event: Dictionary) -> void:
		if event["kind"] == "collision_slowdown":
			events.append(event))
	for tick in 120:
		await physics_frame
		if not events.is_empty():
			break
	check(events.size() == 1, "Actual body collision must resolve one speed event.")
	var result: Dictionary = events[0] if not events.is_empty() else {}
	result["a_weight"] = category_a
	if not glance and category_a == category_b:
		check(a.linear_velocity.x < 0.0 and b.linear_velocity.x > 0.0, "Speed cancellation must preserve opposite physical bounce directions.")
		check(a.wall_speed_bonus < 0.001 and b.wall_speed_bonus < 0.001,"Equal-weight head-on collision must cancel both boosts.")
		await ticks(3)
		check(absf(a.linear_velocity.length() - a.movement_speed) < 0.01 and absf(b.linear_velocity.length() - b.movement_speed) < 0.01, "Head-on collision must return real physics speed to each base speed.")
	await remove(arena)
	return result
func run() -> void:
	var previous := INF
	for category in 5:
		var arena := new_arena()
		var a := arena.get_node("Balls/BlueBall") as ArenaBall
		var b := arena.get_node("Balls/RedBall") as ArenaBall
		b.freeze = true
		b.collision_layer = 0
		place(a,Vector2(919,220),Vector2.RIGHT,category)
		await ticks(14)
		check(a.linear_velocity.x < 0.0 and a.wall_speed_bonus > 0.0,"Real wall reflection must accelerate every weight category.")
		a.collision_mask = 0 # Isolate decay from subsequent wall refills.
		a.collision_layer = 0
		var bonus := a.wall_speed_bonus
		check(bonus < previous,"Lighter classes must receive strictly larger wall boosts.")
		previous = bonus
		await ticks(35)
		check(a.wall_speed_bonus < bonus and a.wall_speed_bonus > 0.0,"Boost must decrease smoothly during flight.")
		await ticks(ceili(a.boost_decay_seconds * Engine.physics_ticks_per_second) + 10)
		check(a.wall_speed_bonus < 0.001,"Boost must expire after its configured decay time.")
		await remove(arena)
	var equal := await body_case(2,2,false)
	check(not equal.is_empty() and equal.get("strength",0.0) > 0.999,"Head-on incidence must be measured as full cancellation.")
	var glancing := await body_case(2,2,true)
	check(not glancing.is_empty() and glancing.get("strength",1.0) < 0.99 and glancing.get("bonus",0.0) > 0.0,"Glancing collisions must retain part of the boost.")
	var mixed := await body_case(0,4,false)
	if not mixed.is_empty():
		var actor_is_light: bool = mixed["actor_id"] == "blue"
		var light_loss: float = mixed["loss"] if actor_is_light else mixed["other_loss"]
		var heavy_loss: float = mixed["other_loss"] if actor_is_light else mixed["loss"]
		check(heavy_loss < light_loss,"Heavier character must lose a smaller fraction of its boost.")
	var arena := new_arena()
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	a.weight_class = 2
	a.gain_wall_boost()
	a.gain_wall_boost()
	check(is_equal_approx(a.wall_speed_bonus,a.movement_speed * 0.30),"Repeated/corner contacts must not stack the wall boost.")
	a.receive_weapon_impact(Vector2.DOWN,2,100.0)
	check(is_equal_approx(a.linear_velocity.length(),a.effective_movement_speed()),"Weapon deflection must retain the current speed boost.")
	await remove(arena)
	print("Wall speed system: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
