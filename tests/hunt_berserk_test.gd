extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for frame in count: await physics_frame
func run() -> void:
	root.size = Vector2i(1280,900)
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	var arena := main.get_node("Arena") as BallArena
	arena.randomize_spawns = false
	root.add_child(main)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	var sword := a.get_node("Sword") as SwordAbility
	var fangs := b.get_node("Vampire") as VampireFangs
	for fighter in [a,b]:
		fighter.freeze = true
		fighter.set_physics_process(false)
	a.position = Vector2(410,300)
	b.position = Vector2(500,300)
	b.current_health = 100000
	check(sword.berserk_chance == 0.05,"Sword profile must have a five-percent Berserk chance.")
	sword.berserk_chance = 1.0
	sword.rotation = 0.0
	var spin_before := sword.spin_direction
	check(sword.try_hit(b),"Berserk must trigger from a real damaging hit.")
	check(sword.berserk_remaining == 5.0 and sword.cooldown_remaining == 0.5,"Activating hit must start five seconds and immediately use the half-second cooldown.")
	check(sword.spin_direction == -spin_before,"Berserk must retain physical hit reflection.")
	check(sword.effective_spin_speed() == sword.spin_speed * 3.0 and sword.slow_remaining > 0.0,"Berserk must override normal post-hit slow rotation.")
	var notes: Array = arena.get_node("CombatEffects").number_layer.numbers
	check(notes.any(func(note: Dictionary) -> bool: return note["text"] == "БЕРСЕРК" and note.get("grizzly",false)),"Proc notice must display BERSERK with a grizzly icon.")
	Engine.time_scale = 1.0
	a.opponent = null
	var angle := sword.rotation
	sword.combat_step(0.1)
	check(absf(absf(sword.rotation-angle)-sword.spin_speed*3.0*0.1) < 0.0001,"Actual orbit must rotate at three times normal speed.")
	sword.berserk_remaining = 2.0
	sword.activate_berserk()
	check(sword.berserk_remaining == 5.0 and sword.effective_spin_speed() == sword.spin_speed*3.0,"Repeat proc must refresh duration without multiplying again.")
	a.hold_motion(a)
	sword.combat_step(5.001)
	check(sword.berserk_remaining == 0.0 and sword.effective_hit_cooldown() == sword.hit_cooldown,"Buff must expire after five game seconds even while captured.")
	a.release_motion(a,Vector2.RIGHT)
	sword.reset_progression()
	a.opponent = b
	b.set_invulnerable(b,true)
	var state := sword.rng.state
	check(not sword.try_hit(b) and sword.berserk_remaining == 0.0 and sword.rng.state == state,"Blocked hit must not roll or activate Berserk.")
	b.set_invulnerable(b,false)
	sword.berserk_chance = 0.05
	var procs := 0
	for sample in 1000:
		sword.berserk_remaining = 0.0
		sword.rng.seed = sample
		sword.on_successful_hit()
		if sword.berserk_remaining > 0.0: procs += 1
	check(procs >= 20 and procs <= 85,"Seeded sword rolls must approximate five percent.")
	print("Berserk procs over 1000 seeded rolls: ",procs)
	sword.reset_progression()
	check(sword.berserk_remaining == 0.0,"Fresh fight must clear Berserk.")
	# Disabled sword nodes on other heroes must not leak the proc into their weapons.
	for hero in ["katana","knifeman"]:
		var other := load("res://scenes/ball.tscn").instantiate() as ArenaBall
		root.add_child(other)
		CharacterCatalog.apply(other,CharacterCatalog.character(hero),70.0)
		for child in other.get_children():
			if child is SwordAbility and child.is_enabled():
				check(child.berserk_chance == 0.0 and child.berserk_remaining == 0.0,"Only swordsman must have the Berserk proc.")
		other.queue_free()
	# Live pursuit follows changing opponent positions, with the existing speed curve.
	a.current_health = 100
	b.current_health = 20
	a.position = Vector2(700,300)
	b.position = Vector2(220,300)
	a.linear_velocity = Vector2.ZERO
	a.freeze = true
	b.freeze = false
	b.set_physics_process(true)
	sword.enabled = false
	b.opponent = a
	arena.director.set_physics_process(true)
	await frames(6)
	check(not fangs.hunting,"Exactly twenty HP must not trigger the hunt.")
	var eyes := b.get_node("ApprovedVampireArt/HuntEyes") as Node2D
	eyes.call("_process",0.0)
	check(not eyes.visible,"Hunt eyes must be hidden before active pursuit.")
	arena.director.set_physics_process(false)
	b.take_damage(1,a)
	fangs.cooldown_remaining = 8.0
	fangs._update_hunt(2.999)
	check(not fangs.hunting and fangs.hunt_pending,"Hunt must wait three seconds after threshold-crossing damage.")
	fangs.cooldown_remaining = 0.0
	check(fangs.try_bite(a),"An ordinary bite must remain available before delayed hunt activation.")
	var remaining := fangs.hunt_delay_remaining
	fangs._update_hunt(3.0)
	check(not fangs.hunting and is_equal_approx(fangs.hunt_delay_remaining,remaining),"Pending hunt timer must pause throughout an early bite.")
	for tick in fangs.bite_units: fangs._bite_tick()
	check(fangs.bite_target == null and fangs.hunt_pending and fangs.hunt_delay_remaining == 3.0,"Completed early bite must restart a full three-second hunt delay.")
	check(fangs.cooldown_remaining == fangs.recovery_time,"Normal cooldown must remain active during the restarted delay.")
	a.capture_immunity_remaining = 0.0
	a.position = Vector2(700,300)
	b.position = Vector2(220,300)
	fangs._update_hunt(2.999)
	check(not fangs.hunting,"Hunt must not activate until the new full delay expires.")
	fangs._update_hunt(0.0011)
	check(fangs.hunting and fangs.cooldown_remaining == 0 and fangs.hunt_used,"Delayed hunt must clear recovery and consume its single activation.")
	eyes.call("_process",0.0)
	check(eyes.visible,"Red hunt eyes must appear when pursuit activates.")
	check(is_equal_approx(fangs.movement_speed_multiplier(),(1.0+(100-b.current_health)*0.005)*1.2),"Hunt must add twenty percent over existing health-dependent speed.")
	arena.director.set_physics_process(true)
	await frames(18)
	check(fangs.hunting and b.linear_velocity.normalized().dot((a.position-b.position).normalized()) > 0.999,"Activated hunt must steer toward its opponent.")
	a.position = Vector2(450,100)
	await frames(12)
	check(b.linear_velocity.normalized().dot((a.position-b.position).normalized()) > 0.999,"Hunt must track the opponent's new position.")
	b.heal(36)
	await frames(6)
	check(fangs.hunting,"Healing above threshold must not cancel an unfinished hunt.")
	arena.director.set_physics_process(false)
	b.freeze = true
	b.position = Vector2(420,300)
	a.position = Vector2(495,300)
	fangs.director = null
	fangs.set_physics_process(false)
	fangs.cooldown_remaining = 1.0
	fangs._contact_rearmed = false
	fangs.combat_step(0.01)
	check(fangs.bite_target == a and not fangs.hunting,"Hunt must bypass bite cooldown and finish on a successful bite.")
	eyes.call("_process",0.0)
	check(not eyes.visible,"Hunt eyes must disappear as soon as a bite starts.")
	fangs._finish_bite()
	a.capture_immunity_remaining = 0
	fangs.hunting = true
	fangs.cooldown_remaining = 0.0
	a.set_invulnerable(a,true)
	fangs.combat_step(0.01)
	check(fangs.bite_target == null,"Pursuit must respect target protection.")
	a.set_invulnerable(a,false)
	fangs.combat_step(0.01)
	check(fangs.bite_target == a and not fangs.hunting,"Continuous hunting contact must bite after cooldown and stop pursuit.")
	fangs._finish_bite()
	b.current_health = 25
	b.take_damage(11,a)
	fangs._update_hunt(3.1)
	check(not fangs.hunting and not fangs.hunt_pending,"A second threshold crossing must not activate another hunt.")
	a.current_health = 0
	fangs._update_hunt()
	check(not fangs.hunting and fangs.preferred_movement_direction().is_zero_approx(),"Hunt must stop when its target dies.")
	# Cosmetic preview of the notice and persistent icon in their actual render layers.
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		a.current_health = 100
		b.current_health = 14
		a.position = Vector2(380,330)
		b.position = Vector2(640,330)
		sword.enabled = true
		sword.rotation = -PI*0.5
		sword.activate_berserk()
		while arena.get_node("CombatEffects").number_layer.numbers.size() > 1:
			arena.get_node("CombatEffects").number_layer.numbers.pop_front()
		var camera := main.get_node("Camera2D") as Camera2D
		camera.zoom = Vector2.ONE*2.5
		camera.position = Vector2(500,270)
		for frame in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	main.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	print("Vampire pursuit and swordsman Berserk: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
