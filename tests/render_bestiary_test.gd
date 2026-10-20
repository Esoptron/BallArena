extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	var viewport := SubViewport.new(); viewport.size=Vector2i(844,390)
	viewport.world_2d=World2D.new(); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var controller := preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/bestiary-render-%d.json"%Time.get_ticks_usec()
	viewport.add_child(controller)
	controller.show_page("bestiary")
	var view = controller.content.get_child(controller.content.get_child_count()-1)
	for index in [0,16,20]:
		view._select_index(index)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		assert(controller.content.size.x<=844)
		assert(view.selector.size.x>=300)
		assert(view.detail.position.x+view.detail.size.x<=controller.content.size.x+1)
		assert(view.portrait_actor.get_node("OrdinaryBallArt").visible)
		assert(viewport.get_texture().get_image().save_png(output.get_basename()+"-%d.png"%index)==OK)
		var scroll := controller.content.get_parent() as ScrollContainer
		scroll.scroll_vertical=250
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(output.get_basename()+"-%d-detail.png"%index)==OK)
		scroll.scroll_vertical=0
	viewport.size=Vector2i(1280,720)
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(output)==OK)
	viewport.free(); await process_frame; await process_frame
	print("render_bestiary_test: PASS"); quit(0)
