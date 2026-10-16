extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var speeds: Array[float] = []
	for category in [0,2,4]:
		var arena: BallArena = load("res://scenes/arena.tscn").instantiate()
		arena.randomize_spawns = false
		arena.blue_character_id = &"club"
		arena.red_character_id = &"swordsman"
		root.add_child(arena)
		arena.director.set_physics_process(false)
		var a: ArenaBall = arena.fighters[0]
		var b: ArenaBall = arena.fighters[1]
		a.freeze = true
		b.freeze = true
		a.position = Vector2(400,300)
		b.position = Vector2(650,300)
		b.weight_class = category
		var club: ClubAbility = a.get_node("Club")
		var sword: SwordAbility = b.get_node("Sword")
		club.rotation = 0
		sword.rotation = PI
		club.spin_direction = 1
		sword.spin_direction = 1
		club.cooldown_remaining = 2
		sword.cooldown_remaining = .7
		a.linear_velocity = Vector2.ZERO
		b.linear_velocity = Vector2(100,0) # Body is already receding, weapons still touch.
		var clashes: Array[int] = [0]
		arena.director.event_recorded.connect(func(event: Dictionary) -> void:
			if event["kind"] == "weapon_clash": clashes[0] += 1)
		arena.director._physics_process(0)
		var velocity := b.linear_velocity
		speeds.append(velocity.x)
		check(velocity.x > 100,"A weapon clash must kick a receding enemy away, even during cooldown.")
		check(a.current_health == 120 and b.current_health == 100 and club.current_damage == 20,"Weapon-only contact must not deal body damage or increase attack damage.")
		check(club.spin_direction == -1 and sword.spin_direction == -1,"Both weapons must still reverse on clash.")
		arena.director._physics_process(0)
		check(clashes[0] == 1 and b.linear_velocity.is_equal_approx(velocity),"Continuous overlap must not stack recoil impulses.")
		b.freeze = false
		for tick in 115:
			await physics_frame
			check(b.position.x >= 0 and b.position.y >= 0 and b.position.x <= 960 and b.position.y <= 600,"Recoil must not throw a body outside the arena.")
		check(b.impact_speed_bonus == 0 and b.impact_speed_loss == 0,"Recoil acceleration and braking must decay after the configured time.")
		arena.queue_free()
		await process_frame
	# A mirror match must use pre-impact velocities for both impulses.
	var mirror: BallArena = load("res://scenes/arena.tscn").instantiate()
	mirror.randomize_spawns = false
	mirror.blue_character_id = &"club"
	mirror.red_character_id = &"club"
	root.add_child(mirror)
	mirror.director.set_physics_process(false)
	for i in 2:
		var actor: ArenaBall = mirror.fighters[i]
		actor.freeze = true
		actor.position = Vector2(400+i*340,300)
		actor.linear_velocity = Vector2.ZERO
		var weapon: ClubAbility = actor.get_node("Club")
		weapon.rotation = 0 if i == 0 else PI
		weapon.spin_direction = 1
	mirror.director._physics_process(0)
	check(mirror.fighters[0].linear_velocity.x < 0 and mirror.fighters[1].linear_velocity.x > 0,"Both clubs must repel each other.")
	check(is_equal_approx(mirror.fighters[0].linear_velocity.length(),mirror.fighters[1].linear_velocity.length()),"Identical club recoil must not depend on callback order.")
	mirror.queue_free()
	await process_frame
	check(speeds[0] > speeds[1] and speeds[1] > speeds[2],"Lighter opponents must receive a stronger visible recoil than heavier opponents.")
	print("Club weapon clash speeds by weight: ",speeds,"; ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
