extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var speeds: Array[float] = []
	for category in 5:
		var arena: BallArena = load("res://scenes/arena.tscn").instantiate()
		arena.randomize_spawns = false
		arena.blue_character_id = &"club"
		arena.red_character_id = &"ordinary"
		root.add_child(arena)
		arena.director.set_physics_process(false)
		var a: ArenaBall = arena.fighters[0]
		var b: ArenaBall = arena.fighters[1]
		a.freeze = true
		b.freeze = true
		a.position = Vector2(400,300)
		b.position = Vector2(550,300)
		a.linear_velocity = Vector2.ZERO
		b.linear_velocity = Vector2(-320,0)
		b.weight_class = category
		b.current_health = 1000
		var club: ClubAbility = a.get_node("Club")
		club.rotation = 0
		var effects: ArenaCombatEffects = arena.get_node("CombatEffects")
		check(club.try_hit(b),"Ready club strike must hit.")
		speeds.append(b.linear_velocity.length())
		if category <= 2:
			check(b.linear_velocity.x > 0 and b.linear_velocity.length() >= b.adjusted_movement_speed()*2.19,"Light-to-medium victims must launch quickly away, even when approaching the club.")
			check(b.impact_speed_bonus > 0,"Fast knockback must survive the next physics integration as a temporary speed bonus.")
		else:
			check(b.linear_velocity.length() <= b.adjusted_movement_speed()+.01 and b.impact_speed_bonus == 0,"Above-average and heavy bodies must not receive a fast launch.")
		check(b.current_health == 980 and club.current_damage == 25,"Launch must keep damage and growth at 20/+5.")
		check(effects.shockwaves.size() == 1,"One body strike must create one impact wave.")
		if effects.shockwaves.size() == 1:
			var point: Vector2 = effects.shockwaves[0]["position"]
			check(is_equal_approx(point.distance_to(b.global_position),b.visual_diameter()*.5),"Body wave must originate at the struck surface.")
		effects.spawn_shockwave(effects.shockwaves[0]["position"],Vector2.LEFT)
		check(effects.shockwaves.size() == 1,"Coincident impacts must share one visual wave.")
		check(not club.try_hit(b) and effects.shockwaves.size() == 1,"Cooldown must prevent repeat damage and extra hit effects.")
		b.freeze = false
		for tick in 125:
			await physics_frame
			check(b.position.x >= 0 and b.position.x <= 960 and b.position.y >= 0 and b.position.y <= 600,"Fast launch must remain inside the arena.")
		check(b.impact_speed_bonus == 0 and b.impact_speed_loss == 0,"Launch and braking must expire smoothly.")
		check(effects.shockwaves.is_empty(),"Shockwaves must expire and clear themselves.")
		for i in 40: effects.spawn_shockwave(Vector2(i*20,150),Vector2.RIGHT)
		check(effects.shockwaves.size() == 24,"Impact effects must have a fixed population limit.")
		effects.advance(.5)
		check(effects.shockwaves.is_empty(),"The entire wave batch must clear after its lifetime.")
		arena.queue_free()
		await process_frame
	check(speeds[0] > speeds[1] and speeds[1] > speeds[2],"Light, below-average and medium launch speeds must differ by weight.")
	print("Club body impact speeds by weight: ",speeds,"; waves, heavy exclusions, cleanup and bounds: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
