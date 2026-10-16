extends SceneTree
var failures: Array[String] = []
var corrections := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
		push_error(message)
func inside(body: ArenaBall, arena: BallArena, tolerance: float = 1.0) -> bool:
	# Accept the same single-step contact penetration as prototype_test; no escape.
	tolerance = maxf(tolerance,body.effective_movement_speed()/Engine.physics_ticks_per_second+0.2)
	var p := arena.to_local(body.global_position)
	var r := body.diameter * 0.5
	return p.x >= r-tolerance and p.y >= r-tolerance and p.x <= arena.arena_size.x-r+tolerance and p.y <= arena.arena_size.y-r+tolerance
func run() -> void:
	var arena: BallArena = load("res://scenes/arena.tscn").instantiate()
	arena.spawn_seed = 91243
	for i in 10:
		arena.battle_roster.append({"character":"swordsman", "team":"blue"})
		arena.battle_roster.append({"character":"vampire", "team":"red"})
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var vampire: ArenaBall = arena.fighters[1]
	var target: ArenaBall = arena.fighters[0]
	var fangs: VampireFangs = vampire.get_node("Vampire")
	for body in arena.fighters:
		body.current_health = 10000
		body.movement_speed = 500
		for ability in body.combat_components:
			if ability is VampireFangs: ability.health_speed_per_hp = 0
	# Recover a live body even after relocation grace has expired, on every edge/corner.
	# Mimics the invalid solver state reported in crowded battles, without relying
	# on nondeterministic contact iteration to produce the exact escape sequence.
	for point in [Vector2(-45,300),Vector2(1005,300),Vector2(480,-45),Vector2(480,645),Vector2(-45,-45),Vector2(1005,645)]:
		vampire.global_position = point
		vampire.linear_velocity = (point-arena.arena_size*.5).normalized()*500
		PhysicsServer2D.body_set_state(vampire.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,vampire.global_transform)
		for tick in 6: await physics_frame
		check(inside(vampire,arena),"A living vampire must recover inside every wall/corner without a temporary guard.")
		corrections += 1
	# Exercise all four bite directions with other living bodies crowding the release.
	for normal in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		vampire.global_position = arena.arena_size*.5 + normal*Vector2(435,255)
		target.global_position = vampire.global_position-normal*85
		vampire.linear_velocity = normal*500
		target.capture_immunity_remaining = 0
		vampire.attack_recovery_remaining = 0
		fangs.cooldown_remaining = 0
		check(fangs.try_bite(target),"Crowded edge fixture must begin a bite.")
		for tick in 30:
			fangs._advance_carried_motion(1.0/Engine.physics_ticks_per_second)
			await physics_frame
			check(inside(vampire,arena) and inside(target,arena),"Both carried bodies must remain inside the arena.")
		fangs.interrupt_bite(target)
		for tick in 120:
			await physics_frame
			for body in arena.fighters:
				check(inside(body,arena),"Crowded bodies must remain contained after a bite release.")
	# Natural twenty-fighter battle, including simultaneous independent bites.
	arena.director.set_physics_process(true)
	for tick in 1200:
		await physics_frame
		for body in arena.fighters:
			if body.current_health > 0:
				check(inside(body,arena),"Twenty-fighter combat must never leave a live hero outside.")
	arena.queue_free()
	await process_frame
	print("Permanent arena containment, ",corrections," injected escapes, crowded bite releases and 20 fighters: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
