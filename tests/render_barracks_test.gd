extends SceneTree
var viewport: SubViewport
var controller: Control
var output := ""
func _initialize() -> void: call_deferred("run")
func capture(suffix: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.get_basename()+"-"+suffix+".png")==OK)
func run() -> void:
	output=OS.get_cmdline_user_args()[0]
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,720); viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
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
	controller._select("vampire"); await capture("vampire-mobile")
	viewport.free(); await process_frame; await process_frame
	print("render_barracks_test: PASS"); quit(0)
