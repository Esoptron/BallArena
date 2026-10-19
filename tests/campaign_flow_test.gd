extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var totals := [[140,75],[220,115],[310,160],[420,215],[550,280]]
	assert(CampaignLevels.all().size()==5)
	for level in 5:
		var coins := 0; var xp := 0
		assert(CampaignLevels.all()[level]["battles"].size()==10)
		for battle in 10:
			var entry := CampaignLevels.encounter(level+1,battle+1)
			assert(entry["boss"]==(battle==9))
			assert(entry["enemies"].size()>=1 and entry["enemies"].size()<=2)
			for enemy in entry["enemies"]: assert(CampaignCatalog.enemy(enemy["id"],enemy)["definition"]!=null)
			coins+=int(entry["reward"]["coins"]); xp+=int(entry["reward"]["xp"])
		assert(coins==totals[level][0] and xp==totals[level][1])
	var layer := CanvasLayer.new(); root.add_child(layer)
	var controller := preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/flow-%d.json"%Time.get_ticks_usec()
	layer.add_child(controller)
	for page in ["barracks","shop","levels"]:
		controller.show_page(page)
		await process_frame
	for hero in CampaignProgression.playable_ids(): controller._select(hero)
	controller.account["selected_hero"]="swordsman"
	controller._start(1)
	await physics_frame; await physics_frame
	assert(controller.page=="battle" and controller.battle_arena.fighters.size()==2)
	var arena := controller.battle_arena
	for frame in 240: await physics_frame
	assert(arena.director.time_seconds>1)
	var enemy := arena.fighters[1]
	enemy.take_damage(enemy.current_health,arena.fighters[0],&"test")
	await create_timer(1.3).timeout
	assert(controller.page=="reward" and controller.account["active_run"]["offer"].size()==3)
	controller._choose(0)
	await physics_frame
	assert(controller.page=="battle" and controller.account["active_run"]["battle"]==2)
	controller._clear_battle()
	layer.free(); await process_frame; await process_frame
	print("campaign_flow_test: PASS"); quit(0)
