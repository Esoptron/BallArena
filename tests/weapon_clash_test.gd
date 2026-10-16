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
	arena.blue_character_id = &"swordsman"
	arena.red_character_id = &"swordsman"
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.freeze = true
	red.freeze = true
	blue.position = Vector2(430,300)
	red.position = Vector2(610,300)
	var a := blue.get_node("Sword") as SwordAbility
	var b := red.get_node("Sword") as SwordAbility
	a.rotation = 0.0
	b.rotation = PI
	a.spin_direction = 1
	b.spin_direction = 1
	var effects := arena.get_node("CombatEffects") as ArenaCombatEffects
	effects.set_process(false)
	arena.director._physics_process(0.0)
	check(a.spin_direction == -1 and b.spin_direction == -1, "Both weapons must reverse on blade contact.")
	check(effects.sparks.size() == 12, "One clash must produce one spark burst.")
	check(blue.current_health == blue.starting_health and red.current_health == red.starting_health, "Clash without body contact must not cause damage.")
	check(a.cooldown_remaining == 0.0 and b.cooldown_remaining == 0.0, "Clash must not consume attack cooldown or progression.")
	arena.director._physics_process(0.0)
	check(a.spin_direction == -1 and effects.sparks.size() == 12, "Continuous contact must not reverse again every frame.")
	b.rotation = PI * 0.5
	arena.director._physics_process(0.0)
	b.rotation = PI
	arena.director._physics_process(0.0)
	check(a.spin_direction == 1 and b.spin_direction == 1 and effects.sparks.size() == 24, "Weapons must rearm after separating.")
	arena.director._clash_pairs.clear()
	a.rotation = -0.16
	b.rotation = PI
	a.spin_direction = 1
	b.spin_speed = 0.0
	arena.director._physics_process(0.32 / a.spin_speed)
	check(a.spin_direction == -1 and effects.sparks.size() == 36, "Swept contact must detect blades crossing between frames.")
	check(not (red.get_node("Vampire") as VampireFangs).can_clash(), "Fangs must opt out of weapon clashes.")
	effects.advance(0.5)
	check(effects.sparks.is_empty(), "Spark bursts must expire.")
	var blood := arena.get_node("BloodEffects") as ArenaBlood
	blood.set_process(false)
	blood.splashes.clear()
	a._contact_victim = null
	a.cooldown_remaining = 0.0
	check(a.try_hit(red), "Hit blood fixture must apply real damage.")
	check(blood.splashes.size() == 3, "A successful weapon hit must spawn exactly three drops.")
	for drop in blood.splashes:
		check(is_equal_approx(drop["radius"],4.2), "Weapon blood must match post-bite drop size.")
	a._contact_victim = null
	a.cooldown_remaining = 0.0
	red.set_invulnerable(red,true)
	check(not a.try_hit(red) and blood.splashes.size() == 3, "Blocked hits must not emit blood.")
	red.set_invulnerable(red,false)
	for boundary in [{"p":Vector2(5,300),"v":Vector2.LEFT*100}, {"p":Vector2(955,300),"v":Vector2.RIGHT*100}, {"p":Vector2(400,5),"v":Vector2.UP*100}, {"p":Vector2(400,595),"v":Vector2.DOWN*100}]:
		blood.splashes.clear()
		blood.impact_drops.clear()
		blood.surface_marks.clear()
		blood.spawn_spray(boundary["p"],boundary["v"],4.2)
		blood.advance(0.05)
		check(blood.splashes.is_empty() and blood.impact_drops.size() == 5 and blood.surface_marks.size() == 1, "Each wall impact must create a bounded secondary splash and stain.")
	blood.advance(2.0)
	check(blood.impact_drops.is_empty() and not blood.surface_marks.is_empty(), "Secondary droplets must expire while surface pools remain.")
	blood.drops.clear()
	blood.spawn_drop(Vector2(400,595),4.2)
	blood.advance(0.1)
	check(blood.impact_drops.size() == 5, "Large post-bite drips must splash on landing too.")
	arena.queue_free()
	await process_frame
	print("Weapon clash and surface blood: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
