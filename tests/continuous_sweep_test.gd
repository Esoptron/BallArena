extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var random := RandomNumberGenerator.new()
	random.seed=188722
	var scenarios:=0
	var expected_contacts:=0
	for hero in ["swordsman","knifeman","katana"]:
		var arena:=load("res://scenes/arena.tscn").instantiate() as BallArena
		arena.blue_character_id=StringName(hero)
		arena.red_character_id=StringName(hero)
		arena.randomize_spawns=false
		root.add_child(arena)
		var director:=arena.director
		director.set_physics_process(false)
		var a: SwordAbility
		var b: SwordAbility
		for child in arena.fighters[0].get_children():
			if child is SwordAbility and child.is_enabled():a=child
		for child in arena.fighters[1].get_children():
			if child is SwordAbility and child.is_enabled():b=child
		for fighter in arena.fighters:fighter.freeze=true;fighter.set_physics_process(false)
		for scenario in 75:
			arena.fighters[0].position=Vector2(400,300)
			arena.fighters[1].position=Vector2(400+random.randf_range(30,300),300+random.randf_range(-130,130))
			if scenario >= 45:
				var reach := 0.0
				for segment in a.current_weapon_segments():
					for point in segment:reach=maxf(reach,point.distance_to(a.fighter.global_position))
				b.fighter.position=Vector2(400+reach*1.6,300)
			for weapon in [a,b]:
				weapon.on_relocated()
				weapon._weapon_start_rotation=random.randf_range(-PI,PI)
				weapon._weapon_end_rotation=weapon._weapon_start_rotation+random.randf_range(-1.2,1.2)
				weapon._weapon_start_position=weapon.fighter.global_position+Vector2(random.randf_range(-8,8),random.randf_range(-8,8))
				weapon.rotation=weapon._weapon_end_rotation
				weapon._clashed_this_step=false
				weapon._body_contact_this_step=false
			if scenario >= 45:
				a._weapon_start_rotation=.4;a._weapon_end_rotation=-.4
				b._weapon_start_rotation=PI-.4;b._weapon_end_rotation=PI+.4
			var expected:=false
			for sample in 1025:
				if not director._weapon_contact(a,b,float(sample)/1024).is_empty():expected=true;break
			director.pending.clear();director._clash_pairs.clear()
			director._queue_weapon_clashes()
			if expected:
				expected_contacts+=1
				check(not director.pending.is_empty(),"Sweep must retain dense reference contact: %s / %d" % [hero,scenario])
			scenarios+=1
		arena.queue_free();await process_frame
	# A tiny target crossed only in the middle of the angular movement.
	var arena:=load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.blue_character_id=&"swordsman";arena.red_character_id=&"ordinary"
	root.add_child(arena);arena.director.set_physics_process(false)
	var fighter:=arena.fighters[0]
	var target:=arena.fighters[1]
	fighter.position=Vector2(400,300);target.position=fighter.position+Vector2.from_angle(.2)*100
	fighter.freeze=true;target.freeze=true
	target.configure(4,0)
	var sword:=fighter.get_node("Sword") as SwordAbility
	sword.rotation=0;sword.spin_direction=1;sword.spin_speed=8;sword.slow_remaining=0;sword._has_weapon_position=false
	check(not sword.intersects_target(target,0) and not sword.intersects_target(target,.4),"Reference target must be outside both endpoint poses.")
	sword.combat_step(.05)
	check(not arena.director.pending.is_empty(),"Body sweep must catch a target between endpoint poses.")
	check(Engine.time_scale == 1.0,"Sweeps must not affect game time.")
	arena.queue_free();await process_frame
	print("Continuous sweep: ",scenarios," scenarios, ",expected_contacts," reference contacts; ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
