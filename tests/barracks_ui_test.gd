extends SceneTree
var controller: Control
func _initialize() -> void: call_deferred("run")
func check_frozen(node: Node) -> void:
	assert(not node.is_processing() and not node.is_physics_processing())
	for child in node.get_children(): check_frozen(child)
func run() -> void:
	var layer := CanvasLayer.new(); root.add_child(layer)
	controller=preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/barracks-ui-%d.json"%Time.get_ticks_usec(); layer.add_child(controller)
	controller.account["xp"]=1000; controller.account["coins"]=100000
	controller.account["features"]["ally_slot_owned"]=true
	controller.show_page("barracks")
	var view: Control=controller.barracks_view
	var identity := view.get_instance_id()
	var panel_ids: Array[int]=[]
	for panel in view.panels: panel_ids.append(panel.get_instance_id())
	for tab in 4:
		view.set_tab(tab)
		assert(view.active_tab==tab and view.hero_id=="swordsman")
		assert(controller.barracks_view.get_instance_id()==identity)
		for index in 4: assert(view.panels[index].get_instance_id()==panel_ids[index])
	view.set_tab(1); await process_frame
	var hp_action: Button=view.panels[1].cards["hp"].action
	hp_action.pressed.emit(); hp_action.pressed.emit()
	assert(controller.account["xp"]==980)
	assert(CampaignProgression.stats("swordsman",controller.account)["max_hp"]==22.0)
	assert(controller.barracks_view.get_instance_id()==identity and view.active_tab==1)
	assert(CampaignSave.load_account(controller.save_path)["account"]["xp"]==980)
	await process_frame
	view.panels[1]._set_mode(1)
	view.panels[1].training.card.action.pressed.emit()
	assert(controller.account["coins"]==99960 and controller.account["heroes"]["swordsman"]["ability_rank"]==1)
	assert(view.active_tab==1 and view.panels[1].mode==1)
	# Browsing a locked hero neither buys nor appoints it. All four pages work.
	controller._select("club")
	assert(not controller.account["heroes"]["club"]["owned"])
	controller._choose_hero("club"); assert(controller.account["selected_hero"]=="swordsman")
	for tab in 4: view.set_tab(tab); assert(view.hero_id=="club")
	assert(view.panels[3].evolution_button.disabled)
	assert(view.panels[1].training.card.action.disabled)
	# Closed hero inventory still merges; half cards are never rounded.
	controller.account["heroes"]["club"]["weapon_cards"][0]=5
	view.set_tab(2); view.refresh(controller.account)
	await process_frame
	view.panels[2].merge_button.pressed.emit()
	assert(controller.account["heroes"]["club"]["weapon_cards"][0]==1)
	assert(controller.account["heroes"]["club"]["weapon_cards"][1]==2)
	assert(controller.account["heroes"]["club"]["weapon_stage"]==1)
	assert(view.active_tab==2 and view.hero_id=="club")
	# A failed disk write must roll the whole operation back, including cards.
	var valid_path: String=controller.save_path
	var blocker := "res://builds/campaign-work/barracks-blocker-%d"%Time.get_ticks_usec()
	var file := FileAccess.open(blocker,FileAccess.WRITE); file.store_string("block directory creation"); file.close()
	controller.save_path=blocker+"/account.json"
	controller.account["heroes"]["club"]["weapon_cards"][0]=4
	var before: Dictionary=controller.account.duplicate(true)
	controller._merge("club",0)
	assert(controller.account==before and not controller.save_warning.is_empty())
	assert(view.warning_bar.visible)
	controller.save_path=valid_path; controller.save_warning=""
	controller._buy("club","coins")
	assert(controller.account["heroes"]["club"]["owned"] and controller.account["coins"]==79960)
	controller._select("club"); view=controller.barracks_view
	controller._select_ally("club"); assert(controller.account["selected_ally"]=="club")
	controller._select_ally(""); assert(controller.account["selected_ally"]=="")
	controller._choose_hero("club"); assert(controller.account["selected_hero"]=="club")
	# Every model is the actual compiled campaign profile and has no live combat.
	for id in CampaignProgression.playable_ids():
		controller._select(id)
		var actor: CampaignBall=view.showcase.preview.actor
		var stats := CampaignProgression.stats(id,controller.account)
		assert(actor.character_id==StringName(id) and actor.diameter==stats["diameter"])
		assert(actor.max_health==CampaignUnits.pack(stats["max_hp"]))
		assert(actor.freeze and actor.collision_layer==0 and actor.collision_mask==0)
		check_frozen(actor)
		assert(actor.get_node("ApprovedVampireArt").visible==(id=="vampire"))
		assert(actor.get_node("OrdinaryBallArt").visible==(id!="vampire"))
	# Caps explain themselves; active runs preserve all progression restrictions.
	controller._select("swordsman")
	controller.account["heroes"]["swordsman"]["ranks"]["recovery"]=10
	view.set_tab(1); view.panels[1]._set_mode(0); view.refresh(controller.account)
	assert(view.panels[1].cards["recovery"].action.disabled)
	assert(CampaignRun.start(controller.account,1,"swordsman",9183))
	view.refresh(controller.account)
	assert(view.showcase.primary.disabled and view.showcase.ally.disabled)
	for card in view.panels[1].cards.values(): assert(card.action.disabled)
	before=controller.account.duplicate(true)
	controller._upgrade("swordsman","hp"); controller._merge("club",0); controller._choose_hero("club"); controller._select_ally("club")
	assert(controller.account==before)
	view.set_tab(2); assert(view.panels[2].merge_button.disabled)
	controller.show_page("levels"); await process_frame; await process_frame
	assert(not is_instance_valid(view))
	layer.free(); await process_frame; await process_frame
	print("barracks_ui_test: PASS"); quit(0)
