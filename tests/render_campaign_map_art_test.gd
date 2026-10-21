extends SceneTree
var viewport: SubViewport
var view: Control
var output := ""
func _initialize() -> void: call_deferred("run")
func capture(suffix: String) -> void:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output.get_basename()+suffix+".png")==OK)
func run() -> void:
	output=OS.get_cmdline_user_args()[0]
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,600); viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var layer := CanvasLayer.new(); viewport.add_child(layer)
	view=preload("res://scenes/campaign/level_map_art_preview.tscn").instantiate()
	view.account=CampaignProgression.new_account()
	layer.add_child(view); await capture("-wide")
	var before: Vector2=view.upper.position
	view.scroller.go_to(view.scroller.maximum)
	for frame in 50: await process_frame
	assert(view.upper.position!=before and view.scroller.offset>100)
	assert(is_equal_approx(view.upper.position.x,-view.scroller.offset*.25))
	assert(is_equal_approx(view.lower.position.x,-view.scroller.offset*.55))
	await capture("-scrolled")
	viewport.size=Vector2i(844,390); view.scroller.jump(0); await capture("-mobile")
	assert(view.header.size.x<=844 and view.footer.size.x<=844)
	viewport.free(); await process_frame; await process_frame
	print("render_campaign_map_art_test: PASS"); quit(0)
