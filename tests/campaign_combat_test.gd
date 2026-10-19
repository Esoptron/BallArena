extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var worlds: Array[SubViewport] = []
	var arenas: Array[BallArena] = []
	for id in CampaignCatalog.data():
		var viewport := SubViewport.new(); viewport.world_2d=World2D.new(); viewport.size=Vector2i(1,1); root.add_child(viewport); worlds.append(viewport)
		var arena := preload("res://scenes/arena.tscn").instantiate() as BallArena
		arena.set_script(preload("res://scripts/campaign/arena.gd"))
		arena.set("presentation",false)
		var lineup: Array[Dictionary] = [CampaignProfiles.hero("swordsman",CampaignProgression.new_account()),CampaignCatalog.enemy(id)]
		arena.set("lineup",lineup)
		arena.spawn_seed=98321; viewport.add_child(arena); arenas.append(arena)
		assert(arena.fighters.size()==2)
	for i in 1440: await physics_frame
	for arena in arenas:
		assert(arena.director.time_seconds>0)
		for actor in arena.fighters:
			if actor.current_health>0:
				var tolerance := maxf(2,actor.effective_movement_speed()/Engine.physics_ticks_per_second+0.5)
				var radius := actor.diameter*0.5
				assert(actor.position.x>=radius-tolerance and actor.position.x<=960-radius+tolerance)
				assert(actor.position.y>=radius-tolerance and actor.position.y<=600-radius+tolerance)
		assert(arena.get_node("ProjectileField").get("shots").size()<=96)
	var archon := arenas.back().fighters[1] as ArenaBall
	archon.take_damage(roundi(archon.max_health*0.6),arenas.back().fighters[0],&"test")
	assert(arenas.back().fighters.size()==3)
	archon.take_damage(100,arenas.back().fighters[0],&"test")
	assert(arenas.back().fighters.size()==3)
	for viewport in worlds: viewport.free()
	await process_frame; await process_frame
	print("campaign_combat_test: PASS"); quit(0)
