extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.time_scale = 1.0
	for id in ["swordsman","knifeman","katana"]:
		var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
		arena.blue_character_id = StringName(id)
		arena.red_character_id = &"ordinary"
		root.add_child(arena)
		arena.director.set_physics_process(false)
		var attacker := arena.fighters[0]
		var target := arena.fighters[1]
		for ability in attacker.get_children():
			if ability is SwordAbility and ability.is_enabled():assert(ability.try_hit(target))
		for frame in 20:await process_frame
		assert(Engine.time_scale == 1.0 and not paused,"Weapon hits must never slow global time.")
		assert(not arena.has_method("_start_impact_slowdown"),"Removed experiment must not remain in the arena.")
		arena.queue_free();await process_frame
	print("No global impact slowdown: PASS")
	quit()
