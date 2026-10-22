extends SceneTree
var viewport: SubViewport
var controller: Control
var output := ""
func _initialize() -> void: call_deferred("run")
func capture(suffix: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.get_basename()+"-"+suffix+".png")==OK)
func check_layout() -> void:
	var view: Control=controller.barracks_view
	var screen := Rect2(Vector2.ZERO,Vector2(viewport.size))
	assert(screen.encloses(view.margin.get_global_rect()))
	assert(screen.encloses(view.resources.get_global_rect()))
	assert(screen.encloses(view.selector.get_global_rect()))
	assert(screen.encloses(view.showcase.get_global_rect()))
	assert(screen.encloses(view.local_scroll.get_global_rect()))
	for button in view.tab_buttons:
		assert(screen.encloses(button.get_global_rect()))
		assert(button.size.y>=44 and button.size.x>=100)
		assert(not button.get_global_rect().intersects(view.local_scroll.get_global_rect()))
	var active: Control=view.panels[view.active_tab]
	assert(active.size.x<=view.local_scroll.size.x+1.0)
func run() -> void:
	output=OS.get_cmdline_user_args()[0]
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,720); viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	viewport.gui_embed_subwindows=true
	var layer := CanvasLayer.new(); viewport.add_child(layer)
	controller=preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/barracks-render-%d.json"%Time.get_ticks_usec(); layer.add_child(controller)
	controller.account["coins"]=1263; controller.account["coins_quarters"]=2
	controller.account["xp"]=324; controller.account["xp_quarters"]=2
	controller.show_page("barracks"); await capture("stats-desktop")
	controller.barracks_view.set_tab(1); await capture("upgrades-desktop")
	controller.barracks_view.panels[1]._set_mode(1); await capture("training-desktop")
	controller.account["heroes"]["swordsman"]["weapon_cards"][0]=3
	controller.barracks_view.refresh(controller.account)
	controller.barracks_view.set_tab(2); await capture("weapons-desktop")
	controller.account["heroes"]["swordsman"]["evolution"]["card_units"]=3
	controller.barracks_view.refresh(controller.account)
	controller.barracks_view.set_tab(3); await capture("evolution-desktop")
	controller.barracks_view.set_tab(0)
	viewport.size=Vector2i(844,390); await capture("stats-mobile")
	check_layout()
	controller._select("vampire"); await capture("vampire-mobile")
	for resolution in [Vector2i(844,390),Vector2i(960,540),Vector2i(1280,720),Vector2i(1482,702)]:
		viewport.size=resolution
		for id in CampaignProgression.playable_ids():
			controller._select(id)
			for tab in 4:
				controller.barracks_view.set_tab(tab)
				for frame in 3: await process_frame
				check_layout()
		controller._select("katana"); controller.barracks_view.set_tab(1)
		controller.barracks_view.panels[1]._set_mode(0)
		await capture("katana-upgrades-%dx%d"%[resolution.x,resolution.y])
	viewport.size=Vector2i(844,390); controller._select("club"); controller.barracks_view.set_tab(2)
	await capture("club-weapons-mobile")
	controller.barracks_view.local_scroll.scroll_vertical=10000; await capture("club-merge-mobile")
	controller.barracks_view.set_tab(3)
	controller.barracks_view.local_scroll.scroll_vertical=10000; await capture("evolution-mobile")
	controller.barracks_view.panels[3]._show_help(); await capture("evolution-help-mobile")
	var popup: AcceptDialog=controller.barracks_view.panels[3].help
	assert(Rect2i(Vector2i.ZERO,viewport.size).encloses(Rect2i(popup.position,popup.size)))
	controller.barracks_view.panels[3].help.hide()
	controller._select("vampire"); controller.barracks_view.set_tab(0)
	controller.barracks_view.panels[0]._toggle()
	controller.barracks_view.local_scroll.scroll_vertical=10000; await capture("vampire-details-mobile")
	viewport.free(); await process_frame; await process_frame
	print("render_barracks_test: PASS"); quit(0)
