extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var controller := preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/ally-flow-%d.json"%Time.get_ticks_usec()
	root.add_child(controller)
	controller.account["crystals"]=999; controller._buy_ally("crystals")
	assert(controller.account["features"]["ally_slot_owned"])
	CampaignProgression.add_character_cards(controller.account,"knifeman",2)
	controller._select("knifeman")
	assert(controller.account["selected_hero"]=="swordsman")
	controller._select_ally("knifeman"); assert(controller.account["selected_ally"]=="knifeman")
	controller._start(1)
	var arena := controller.battle_arena
	assert(arena.fighters.size()==3 and arena.get("party_size")==2)
	arena.director.set_physics_process(false)
	for actor in arena.fighters: actor.freeze=true
	assert(arena.fighters[1].character_id==&"knifeman")
	arena.fighters[0].take_damage(arena.fighters[0].current_health,arena.fighters[2],&"test")
	assert(not arena.director.match_over)
	arena.fighters[2].take_damage(arena.fighters[2].current_health,arena.fighters[1],&"test")
	await create_timer(1.3).timeout
	assert(controller.page=="reward" and controller.account["active_run"]["hp"]==0)
	assert(CampaignSave.load_account(controller.save_path)["account"]["active_run"]["hp"]==0)
	controller._choose(0); arena=controller.battle_arena
	assert(controller.page=="battle" and arena.fighters[0].current_health==0 and not arena.fighters[0].visible)
	arena.director.set_physics_process(false)
	for actor in arena.fighters: actor.freeze=true
	arena.fighters[1].take_damage(arena.fighters[1].current_health,arena.fighters[2],&"test")
	await create_timer(1.3).timeout
	assert(controller.page=="defeat" and controller.account["active_run"].is_empty())
	assert(controller.account["coins"]==5 and controller.account["xp"]==4)
	assert(controller.account["features"]["ally_slot_owned"] and controller.account["selected_ally"]=="knifeman")
	controller.free(); await process_frame; await process_frame
	print("campaign_ally_flow_test: PASS"); quit(0)
