extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var arena:=load("res://scenes/arena.tscn").instantiate() as BallArena
	root.add_child(arena);arena.director.set_physics_process(false)
	for fighter in arena.fighters:fighter.freeze=true
	var blood:=arena.get_node("BloodEffects") as ArenaBlood
	blood.set_process(false)
	for index in 100:blood.spawn_spray(Vector2(200+index,250),Vector2(30,100),4.2)
	blood.advance(.01)
	assert(blood._particle_layer.multimesh.visible_instance_count==100,"Every live drop must be retained in the batch.")
	for frame in 3:await process_frame
	if DisplayServer.get_name() != "headless":
		assert(blood._particle_layer.multimesh.get_instance_transform_2d(0).origin.is_equal_approx(blood.splashes[0]["position"]),"Batch transforms must match particle physics.")
	blood.splashes.clear();blood.advance(0)
	assert(blood._particle_layer.multimesh.visible_instance_count==0,"An empty particle batch must disappear.")
	var effects:=arena.get_node("CombatEffects") as ArenaCombatEffects
	effects.set_process(false);effects.spawn_sparks(Vector2(400,300));effects.advance(.01)
	assert(effects._spark_layer.multimesh.visible_instance_count==effects.sparks.size(),"Sparks must keep their population.")
	effects.advance(1)
	assert(effects._spark_layer.multimesh.visible_instance_count==0,"Expired sparks must clear the batch.")
	var id:=effects.start_drain(arena.fighters[0],arena.fighters[1]);effects.advance(.1)
	assert(effects._orb_layer.multimesh.visible_instance_count>0,"Drain spheres must remain visible in their batch.")
	effects.stop_drain(id);effects.advance(0)
	assert(effects._orb_layer.multimesh.visible_instance_count==0,"Stopping drain must clear its sphere batch.")
	arena.queue_free();await process_frame
	print("Particle instancing, transforms, lifetimes and drain cleanup: PASS")
	quit()
