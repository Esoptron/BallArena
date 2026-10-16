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
	arena.red_character_id = &"ordinary"
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var a := arena.get_node("Balls/BlueBall") as ArenaBall
	var b := arena.get_node("Balls/RedBall") as ArenaBall
	a.freeze = true
	b.freeze = true
	a.position = Vector2(430,300)
	b.position = Vector2(530,300)
	var sword := a.get_node("Sword") as SwordAbility
	sword.set_physics_process(false)
	for mode in ["normal","cooldown","protected"]:
		sword._contact_victim = null
		sword._body_contact_this_step = false
		sword._clashed_this_step = false
		sword.rotation = -0.45
		sword.spin_direction = 1
		sword.slow_remaining = 0.0
		sword.cooldown_remaining = 0.6 if mode == "cooldown" else 0.0
		b.set_invulnerable(b,mode == "protected")
		var hp := b.current_health
		sword.combat_step(0.5 / sword.spin_speed)
		arena.director._physics_process(0.0)
		check(sword.spin_direction == -1,"Body contact must reverse in mode: " + mode)
		check((b.current_health < hp) == (mode == "normal"),"Only available, unblocked damage may change HP: " + mode)
		var angle := sword.rotation
		sword.combat_step(0.01)
		check(sword.rotation < angle and sword.spin_direction == -1,"Visible orbit must continue backwards after contact: " + mode)
	b.set_invulnerable(b,false)
	# An old queued clash must not undo a body's earlier reflection in the same step.
	var other := b.get_node("Sword") as SwordAbility
	b.is_swordsman = true
	other.enabled = true
	other.rotation = PI
	other._weapon_start_rotation = PI
	other._weapon_end_rotation = PI
	other._weapon_start_position = b.global_position
	sword._contact_victim = null
	sword._body_contact_this_step = false
	sword._clashed_this_step = false
	sword._orbit_contact(b,0.0,0.0)
	var before := sword.spin_direction
	arena.director._resolve_weapon_clash(sword,other,0.8,Vector2(500,300),"old-path")
	check(sword.spin_direction == before,"Stale clash must not undo body reflection.")
	arena.queue_free()
	await process_frame
	print("Sword body reflection: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
