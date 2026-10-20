extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var controller := preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/bestiary-%d.json"%Time.get_ticks_usec()
	root.add_child(controller)
	var before := controller.account.duplicate(true)
	var catalog_before := CampaignCatalog.data().duplicate(true)
	controller.show_page("bestiary"); await process_frame
	var view = controller.content.get_child(controller.content.get_child_count()-1)
	assert(view.visible_ids.size()==21)
	assert(view.DESCRIPTIONS.size()==CampaignCatalog.data().size())
	for index in view.visible_ids.size():
		view._select_index(index)
		var id: String = view.selected_id
		assert(not view.encounters(id).is_empty())
		assert(view.portrait_actor.character_id==StringName(id))
		assert(view.portrait_actor.collision_layer==0 and view.portrait_actor.collision_mask==0)
		assert(view.portrait_actor.freeze and not view.portrait_actor.is_physics_processing())
		assert(view.portrait_actor.current_health==CampaignCatalog.enemy(id)["definition"].starting_health)
		for child in view.portrait_actor.get_children():
			assert(not child.is_processing() and not child.is_physics_processing())
		assert(view.portrait_actor.get_parent().get_child_count()==1)
	view._filter(1); assert(view.visible_ids.size()==16)
	view._step(-1); assert(view.selector.selected==15)
	view._step(1); assert(view.selector.selected==0)
	view._filter(2); assert(view.visible_ids.size()==5)
	for id in view.visible_ids: assert(CampaignCatalog.data()[id].has("boss"))
	assert(controller.account==before and CampaignCatalog.data()==catalog_before)
	controller.back(); assert(controller.page=="levels")
	controller.free(); await process_frame; await process_frame
	print("campaign_bestiary_test: PASS"); quit(0)
