extends SceneTree
## One genuine level attempt with carried HP/cards; does not assume victory.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var account := CampaignProgression.new_account()
	assert(CampaignRun.start(account,1,"swordsman",107927))
	var bouts: Array = []
	for battle in 10:
		assert(CampaignRun.begin(account))
		var run_state: Dictionary=account["active_run"]
		var entry := CampaignLevels.encounter(1,battle+1)
		var lineup: Array[Dictionary]=[CampaignProfiles.hero("swordsman",CampaignRun.profile_account(account),run_state["bonuses"])]
		for enemy in entry["enemies"]: lineup.append(CampaignCatalog.enemy(enemy["id"],enemy))
		var viewport := SubViewport.new(); viewport.world_2d=World2D.new(); viewport.size=Vector2i.ONE; root.add_child(viewport)
		var arena := preload("res://scenes/arena.tscn").instantiate() as BallArena
		arena.set_script(preload("res://scripts/campaign/arena.gd")); arena.set("lineup",lineup)
		arena.set("carried_hp",run_state["hp"]); arena.set("carried_peak",run_state["peak"]); arena.set("presentation",false)
		arena.spawn_seed=int(run_state["seed"]) ^ (battle+1)*104729; viewport.add_child(arena)
		while not arena.director.match_over and arena.director.time_seconds<90: await physics_frame
		var player := arena.fighters[0] as CampaignBall
		var won := player.current_health>0 and arena.director.match_over
		bouts.append({"battle":battle+1,"duration":arena.director.time_seconds,"won":won,"hp":CampaignUnits.unpack(player.current_health),"cards":run_state["bonuses"].duplicate(true)})
		assert(CampaignRun.settle(account,won,player.current_health,player.campaign_effective_max,entry["reward"]))
		viewport.free(); await process_frame
		if not won: break
		var offer: Array=account["active_run"]["offer"]
		var choice := 0
		for preferred in ["legend","vitality","heal","damage","spin"]:
			if offer.has(preferred): choice=offer.find(preferred); break
		assert(CampaignRun.choose(account,choice))
	var file := FileAccess.open("res://builds/campaign-work/level-smoke.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":107927,"hero":"swordsman","bouts":bouts,"coins":account["coins"],"xp":account["xp"]},"\t")); file.close()
	assert(not bouts.is_empty() and CampaignSave.validate(account).is_empty())
	print("campaign_level_smoke_test: PASS; actual carried-state attempt, battles=",bouts.size())
	quit(0)
