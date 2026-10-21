extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 5: await process_frame
func run() -> void:
	root.size = Vector2i(844,390)
	var launcher := preload("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	# Use an isolated save; never overwrite the developer's ongoing campaign.
	var controller := preload("res://scripts/campaign/controller.gd").new()
	controller.save_path = "res://builds/campaign-work/map-integration-%d.json"%Time.get_ticks_usec()
	launcher.front_menu.get_parent().add_child(controller)
	launcher.campaign = controller
	controller.closed.connect(launcher._close_campaign)
	controller.home_requested.connect(launcher._campaign_home)
	launcher._open_campaign(); await settle()
	assert(controller.page=="levels" and is_instance_valid(controller.level_map))
	var map: Control = controller.level_map
	map.scroller.jump(350)
	var center: float = map.center_on_map()
	map.shop_requested.emit(); assert(controller.page=="shop")
	controller.back(); await settle()
	assert(absf(controller.level_map.center_on_map()-center)<1)
	controller.level_map.barracks_requested.emit(); assert(controller.page=="barracks")
	controller.back(); await settle()
	controller.level_map.bestiary_requested.emit(); assert(controller.page=="bestiary")
	controller.back(); await settle()
	controller.level_map.art_preview_requested.emit(); assert(controller.page=="map_art_preview")
	var art: Control=controller.page_root.get_child(0)
	await settle()
	assert(art.level_nodes.size()==3 and art.account==controller.account)
	art._activate(2); assert(controller.page=="map_art_preview")
	art.back_requested.emit(); await settle()
	assert(controller.page=="levels" and controller.level_map.level_nodes.size()==20)
	controller.level_map._activate(6); controller.level_map._activate(2)
	assert(controller.page=="levels" and controller.account["active_run"].is_empty())
	controller.level_map._activate(1)
	assert(controller.page=="battle" and controller.battle_arena.fighters.size()==2)
	controller.battle_arena.director.set_physics_process(false)
	for actor in controller.battle_arena.fighters: actor.freeze = true
	controller.account["active_run"]["status"]="ready"
	controller._clear_battle(); controller.show_page("levels"); await settle()
	assert(controller.level_map.level_nodes[0].entry["can_enter"])
	controller.level_map.resume_requested.emit(); assert(controller.page=="battle")
	controller.account["active_run"]["status"]="ready"
	controller._clear_battle(); controller.show_page("levels"); await settle()
	controller.level_map.abandon_requested.emit()
	var dialog: ConfirmationDialog
	for child in controller.get_children():
		if child is ConfirmationDialog: dialog = child
	assert(is_instance_valid(dialog))
	dialog.confirmed.emit(); dialog.hide(); await settle()
	assert(controller.account["active_run"].is_empty() and controller.page=="levels")
	controller.level_map.home_requested.emit()
	assert(launcher.front_menu.visible and launcher.front_menu.page=="home" and not controller.visible)
	launcher._open_campaign(); await settle()
	controller.save_blocked = true; controller.show_page("levels")
	assert(controller.level_map==null and is_instance_valid(controller.content))
	launcher.free(); await settle()
	print("campaign_map_integration_test: PASS"); quit(0)
