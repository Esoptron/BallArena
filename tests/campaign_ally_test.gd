extends SceneTree
func _initialize() -> void: call_deferred("run")
func arena_for(a: Dictionary) -> BallArena:
	var state: Dictionary=a["active_run"]
	var snapshot := CampaignRun.profile_account(a)
	var arena := preload("res://scenes/arena.tscn").instantiate() as BallArena
	arena.set_script(preload("res://scripts/campaign/arena.gd"))
	var lineup: Array[Dictionary]=[CampaignProfiles.hero(state["hero"],snapshot,state["bonuses"]),CampaignProfiles.hero(state["ally"]["hero"],snapshot),CampaignCatalog.enemy("fencer")]
	arena.set("lineup",lineup); arena.set("party_size",2); arena.set("presentation",false)
	arena.set("carried_hp",state["hp"]); arena.set("carried_peak",state["peak"])
	arena.set("ally_hp",state["ally"]["hp"]); arena.set("ally_peak",state["ally"]["peak"])
	root.add_child(arena); arena.director.set_physics_process(false)
	for actor in arena.fighters: actor.freeze=true
	return arena
func run() -> void:
	var a := CampaignProgression.new_account()
	assert(not CampaignProgression.select_ally(a,"swordsman"))
	a["crystals"]=999; assert(CampaignProgression.buy_ally(a,"crystals"))
	assert(a["crystals"]==0 and not CampaignProgression.buy_ally(a,"coins"))
	assert(not CampaignProgression.select_ally(a,"vampire"))
	CampaignProgression.add_character_cards(a,"vampire",2)
	assert(CampaignProgression.select_ally(a,"vampire"))
	assert(CampaignRun.start(a,1,"swordsman",9961) and CampaignRun.begin(a))
	assert(not CampaignProgression.select_ally(a,""))
	var arena := arena_for(a)
	assert(arena.fighters.size()==3 and arena.fighters[0].team_id==arena.fighters[1].team_id)
	assert(not arena.director.are_enemies(arena.fighters[0],arena.fighters[1]))
	var ally_health: int=arena.fighters[1].current_health
	assert(arena.fighters[1].take_damage(1000,arena.fighters[0])==0 and arena.fighters[1].current_health==ally_health)
	arena.fighters[0].take_damage(arena.fighters[0].current_health,arena.fighters[2],&"test")
	assert(not arena.director.match_over)
	arena.fighters[2].take_damage(arena.fighters[2].current_health,arena.fighters[1],&"test")
	assert(arena.director.match_over)
	assert(CampaignRun.settle(a,true,0,20000,{},arena.call("ally_result")))
	assert(a["active_run"]["hp"]==0 and a["active_run"]["ally"]["hp"]>0)
	CampaignCards.apply(a["active_run"],CampaignRun.profile_account(a),"vitality")
	assert(a["active_run"]["hp"]==0) # No card can revive a fallen party member.
	assert(CampaignRun.choose(a,0)); arena.free(); await process_frame
	var path := "res://builds/campaign-work/ally-%d.json"%Time.get_ticks_usec()
	assert(CampaignSave.write(a,path)==OK)
	a=CampaignSave.load_account(path)["account"]
	assert(a["active_run"]["hp"]==0 and a["active_run"]["ally"]["hp"]>0)
	assert(CampaignRun.begin(a)); arena=arena_for(a)
	assert(not arena.fighters[0].visible and arena.fighters[0].collision_layer==0 and arena.fighters[0].collision_mask==0)
	assert(arena.fighters[2].opponent==arena.fighters[1])
	arena.fighters[1].take_damage(arena.fighters[1].current_health,arena.fighters[2],&"test")
	assert(arena.director.match_over)
	assert(CampaignRun.settle(a,false,0,20000,{},arena.call("ally_result")))
	assert(a["active_run"].is_empty() and not a["last_result"]["won"])
	assert(a["coins"]==5 and a["xp"]==4 and CampaignEconomy.completions(a,1)==0)
	arena.free(); await process_frame; await process_frame
	# Same-type copies are independent slots, with independent HP and identities.
	assert(CampaignProgression.select_ally(a,"swordsman"))
	assert(CampaignRun.start(a,1,"swordsman",9962) and CampaignRun.begin(a))
	assert(CampaignRun.settle(a,true,10000,20000,{}, {"hp":0,"peak":20000}))
	assert(a["active_run"]["hp"]==11000 and a["active_run"]["ally"]["hp"]==0)
	assert(CampaignRun.choose(a,0)); assert(CampaignRun.begin(a))
	assert(not CampaignRun.settle(a,true,10000,20000,{}, {"hp":100,"peak":20000}))
	assert(CampaignRun.settle(a,false,0,20000,{}))
	var old := CampaignProgression.new_account(); old["schema"]=3; old.erase("selected_ally")
	old["completions"]={"1":7}; old["boss_wins"]=[1]
	var migrated := CampaignSave.migrate(old)
	assert(migrated["schema"]==4 and CampaignEconomy.completions(migrated,1)==7)
	assert(migrated["selected_ally"].is_empty())
	print("campaign_ally_test: PASS"); quit(0)
