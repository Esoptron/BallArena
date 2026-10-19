extends SceneTree
var viewport: SubViewport
var output := "res://builds/campaign-work/campaign.png"
func _initialize() -> void: call_deferred("run")
func capture(suffix: String) -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.get_width()==1280 and image.get_height()==720)
	assert(image.save_png(output.get_basename()+suffix+".png")==OK)
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty(): output=OS.get_cmdline_user_args()[0]
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,720); viewport.world_2d=World2D.new(); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var layer := CanvasLayer.new(); viewport.add_child(layer)
	var controller := preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/render-save-%d.json"%Time.get_ticks_usec(); layer.add_child(controller)
	await capture("-levels")
	controller.show_page("barracks"); await capture("-barracks")
	controller._select("vampire"); await capture("-vampire")
	controller.show_page("shop"); await capture("-shop")
	controller.account["selected_hero"]="swordsman"; controller._start(1)
	controller.battle_arena.director.set_physics_process(false)
	for actor in controller.battle_arena.fighters: actor.freeze=true
	await capture("-battle")
	var enemy := controller.battle_arena.fighters[1] as ArenaBall
	enemy.take_damage(enemy.current_health,controller.battle_arena.fighters[0],&"test")
	for frame in 12: await process_frame
	assert(controller.battle_arena.death_fragments.groups.size()>0)
	await capture("-death")
	await create_timer(1.3).timeout
	assert(controller.page=="reward"); await capture("-reward")
	viewport.free(); await process_frame; await process_frame
	print("render_campaign_test: PASS"); quit(0)
