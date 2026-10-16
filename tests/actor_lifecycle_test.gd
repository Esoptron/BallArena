extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func run() -> void:
	var ball := load("res://scenes/ball.tscn").instantiate() as ArenaBall
	ball.is_vampire = false
	root.add_child(ball)
	ball.set_physics_process(false)
	var first := Node.new()
	var second := Node.new()
	root.add_child(first)
	root.add_child(second)
	for source in [first, second]:
		ball.hold_motion(source)
		ball.set_invulnerable(source, true)
		ball.paralyze(3.0, source)
	root.remove_child(first)
	check(ball.is_immobilized() and ball.is_invulnerable(), "Removing one source must retain all effects of the other source.")
	first.free()
	second.free()
	check(not ball.is_immobilized() and not ball.is_invulnerable() and not ball.freeze,
		"Removing the last source must release motion, paralysis and protection.")
	var detached := Node.new()
	ball.hold_motion(detached)
	ball.set_invulnerable(detached, true)
	detached.free()
	ball._physics_process(0.0)
	check(not ball.is_immobilized() and not ball.is_invulnerable(), "Freeing a source never added to a tree must not leave permanent locks.")
	var retained := Node.new()
	root.add_child(retained)
	ball.hold_motion(retained)
	ball.set_invulnerable(retained, true)
	ball.paralyze(3.0, retained)
	root.remove_child(ball)
	root.add_child(ball)
	check(ball.is_invulnerable() and ball.is_immobilized(), "Reparenting must retain a live source's effects.")
	retained.free()
	check(not ball.is_invulnerable() and not ball.is_immobilized(), "Reparenting must restore tracking and release a later freed source.")
	var expires_while_detached := Node.new()
	root.add_child(expires_while_detached)
	ball.set_invulnerable(expires_while_detached, true)
	root.remove_child(ball)
	expires_while_detached.free()
	root.add_child(ball)
	check(not ball.is_invulnerable(), "Reentering must release effects whose source expired while detached.")
	ball.paralyze(0.0)
	check(not ball.freeze, "A zero-duration paralysis must not freeze a live actor indefinitely.")
	ball.current_health = 0
	check(ball.take_damage(10) == 0 and ball.current_health == 0, "Repeated damage of a dead actor is a no-op.")
	ball.current_health = -1
	check(ball.take_damage(10) == 0 and ball.current_health == -1, "Damage must never return negative damage or resurrect an invalid dead state.")
	ball.queue_free()
	await process_frame
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.randomize_spawns = false
	arena.blue_character_id = &"swordsman"
	arena.red_character_id = &"vampire"
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var victim := arena.fighters[0]
	var attacker := arena.fighters[1]
	var bite := attacker.get_node("Vampire") as VampireFangs
	check(bite.try_bite(victim), "Bite fixture must start.")
	bite.reset_runtime()
	check(not victim.is_immobilized() and not attacker.is_feeding and not attacker.is_invulnerable(),
		"Resetting an active bite must release all source-owned effects.")
	victim.capture_immunity_remaining = 0.0
	check(bite.try_bite(victim), "Bite must start again after explicit reset.")
	CharacterCatalog.apply(attacker, CharacterCatalog.character(&"ordinary"), 70.0)
	check(not victim.is_immobilized() and not attacker.is_feeding and not attacker.is_invulnerable() and bite.bite_target == null,
		"Changing profiles during a bite must release the old victim and attacker.")
	CharacterCatalog.apply(attacker, CharacterCatalog.character(&"vampire"), 70.0)
	victim.capture_immunity_remaining = 0.0
	bite = attacker.get_node("Vampire")
	check(bite.try_bite(victim), "Final bite fixture must start.")
	victim.free()
	bite.combat_step(0.01)
	check(not attacker.is_invulnerable() and not attacker.is_feeding and bite.bite_target == null,
		"A freed bite target must not crash or leave the attacker locked.")
	arena.queue_free()
	await process_frame
	print("Actor source lifecycle, profile transitions and interrupted bites: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
