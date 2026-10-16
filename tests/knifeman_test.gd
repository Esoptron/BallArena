extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.blue_character_id = &"knifeman"
	arena.red_character_id = &"ordinary"
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	var daggers := a.get_node("Knives") as DaggerAbility
	daggers.set_physics_process(false)
	a.freeze = true
	b.freeze = true
	check(is_equal_approx(a.diameter,49.0) and a.current_health == 90 and a.weight_class == 0 and is_equal_approx(a.mass,0.6), "Knife body must be light, diameter 49, with 90 HP.")
	check(not (a.get_node("Sword") as SwordAbility).is_enabled(), "Knife profile must not also activate sword.")
	a.position = Vector2(430,300)
	b.position = Vector2(500,300)
	daggers.rotation = 0.0
	var segments := daggers.current_weapon_segments()
	check(segments.size() == 2 and (segments[0][1] - a.global_position).normalized().dot((segments[1][1] - a.global_position).normalized()) < -0.999,"Daggers must be exactly opposite around the body.")
	check(daggers.intersects_target(b,0.0),"First dagger must hit a target on its side.")
	b.position = Vector2(360,300)
	check(daggers.intersects_target(b,0.0),"Opposite dagger must hit behind the character.")
	b.position = Vector2(430,230)
	check(not daggers.intersects_target(b,0.0),"Daggers must not damage empty space between their sides.")
	b.position = Vector2(500,300)
	daggers.spin_direction = 1
	var speed := daggers.spin_speed
	var hp := b.current_health
	var body_speed := a.movement_speed
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	blood.set_process(false)
	var effects := arena.get_node("CombatEffects") as ArenaCombatEffects
	effects.set_process(false)
	check(daggers.try_hit(b) and b.current_health == hp - daggers.base_damage,"Initial knife damage must match the configured base damage.")
	check(daggers.current_damage == mini(daggers.max_damage,daggers.base_damage+daggers.damage_gain) and daggers.spin_speed == minf(daggers.max_spin_speed,speed+daggers.spin_gain) and a.movement_speed == body_speed,"Knife hits must grow damage slightly and orbit strongly without growing body speed.")
	check(daggers.spin_direction == -1 and is_equal_approx(daggers.cooldown_remaining,1.0),"Successful hits must reverse and apply a shared one-second cooldown.")
	check(effects.slashes.size() == 1 and blood.splashes.size() == 3,"Knife hit must use shared slash and blood effects.")
	check(not daggers.try_hit(b),"Opposite dagger must share the same hit cooldown.")
	daggers.cooldown_remaining = 0.0
	daggers._contact_victim = null
	b.set_invulnerable(b,true)
	check(not daggers.try_hit(b) and daggers.spin_speed == minf(daggers.max_spin_speed,speed+daggers.spin_gain) and blood.splashes.size() == 3,"Blocked hits must not grow orbit speed or emit blood.")
	b.set_invulnerable(b,false)
	b.current_health = 10000
	for hit in 40:
		daggers.cooldown_remaining = 0.0
		daggers._contact_victim = null
		check(daggers.try_hit(b),"Knife cap fixture must keep hitting.")
	check(daggers.current_damage == daggers.max_damage and is_equal_approx(daggers.spin_speed,daggers.max_spin_speed),"Knife growth must stop at configured caps.")
	daggers.reset_progression()
	check(daggers.current_damage == daggers.base_damage and daggers.spin_speed == speed and daggers.successful_hits == 0,"Restart must reset knife damage and orbit speed.")
	daggers.rotation = -0.8
	daggers.spin_direction = 1
	daggers.cooldown_remaining = 0.5
	var hp_before := b.current_health
	daggers.combat_step(0.9 / daggers.spin_speed)
	arena.director._physics_process(0.0)
	check(daggers.spin_direction == -1 and b.current_health == hp_before,"Knife must physically reverse during cooldown without dealing damage.")
	daggers._body_contact_this_step = false
	daggers._clashed_this_step = false
	daggers._weapon_start_rotation = 0.0
	daggers._weapon_end_rotation = 0.1
	daggers.spin_direction = 1
	daggers.deflect_weapon(0.5)
	check(daggers.spin_direction == -1 and daggers.weapon_segments_at(1.0).size() == 2,"Shared weapon clash interface must deflect both daggers together.")
	daggers.reset_progression()
	daggers.rotation = 0.0
	daggers.spin_direction = 1
	daggers.set_physics_process(true)
	b.is_swordsman = true
	var sword := b.get_node("Sword") as SwordAbility
	sword.enabled = true
	sword.rotation = PI
	sword.spin_direction = 1
	b.position = Vector2(585,300)
	var a_hp := a.current_health
	var b_hp := b.current_health
	arena.director._physics_process(0.0)
	check(daggers.spin_direction == -1 and sword.spin_direction == -1,"Actual knife-versus-sword collision must reverse both weapons.")
	check(a.current_health == a_hp and b.current_health == b_hp,"Weapon clash must block the stale body contact at the same instant.")
	arena.queue_free()
	await process_frame
	print("Knifeman: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
