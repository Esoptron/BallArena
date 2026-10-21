extends SceneTree
var viewport: SubViewport
var view: Control
var output := ""
func _initialize() -> void: call_deferred("run")
func capture(suffix: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.get_basename()+suffix+".png")==OK)
func run() -> void:
	output=OS.get_cmdline_user_args()[0]
	viewport=SubViewport.new(); viewport.size=Vector2i(844,390); viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var layer := CanvasLayer.new(); viewport.add_child(layer)
	view=preload("res://scenes/campaign/level_map.tscn").instantiate(); layer.add_child(view)
	await capture("-start-mobile")
	assert(view.level_nodes[0].get_global_rect().size.x>100)
	view.scroller.jump(view.scroller.maximum); await capture("-fog-mobile")
	assert(view.terminal.is_processing())
	view.free()
	view=preload("res://scenes/campaign/level_map.tscn").instantiate()
	view.account=CampaignProgression.new_account(); view.account["unlocked_level"]=5; view.account["completions"]={"1":1,"2":2,"3":1,"4":1}
	layer.add_child(view); await capture("-level5-mobile")
	view.scroller.jump(0); await capture("-completed-mobile")
	viewport.size=Vector2i(1280,720); await capture("-desktop")
	view.scroller.jump(view.scroller.maximum); await capture("-fog-desktop")
	viewport.free(); await process_frame; await process_frame
	print("render_campaign_map_test: PASS"); quit(0)
