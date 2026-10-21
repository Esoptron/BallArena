extends SceneTree
var viewport: SubViewport
var controller: Control
var output := ""
func _initialize() -> void: call_deferred("run")
func capture(name: String, scroll: int = 0) -> void:
	for frame in 5: await process_frame
	if is_instance_valid(controller.content):
		(controller.content.get_parent() as ScrollContainer).scroll_vertical=scroll
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var page: Control = controller.content if is_instance_valid(controller.content) else controller.level_map
	assert(page.size.x<=viewport.size.x)
	assert(viewport.get_texture().get_image().save_png(output.get_basename()+"-"+name+".png")==OK)
func win_wave() -> void:
	assert(CampaignRun.begin(controller.account))
	assert(CampaignRun.settle(controller.account,true,20000,20000,{}))
func run() -> void:
	output=OS.get_cmdline_user_args()[0]
	viewport=SubViewport.new(); viewport.size=Vector2i(844,390); viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var layer := CanvasLayer.new(); viewport.add_child(layer)
	controller=preload("res://scripts/campaign/controller.gd").new()
	controller.save_path="res://builds/campaign-work/render-economy-%d.json"%Time.get_ticks_usec(); layer.add_child(controller)
	controller.account["coins"]=123456; controller.account["coins_quarters"]=1
	controller.account["xp"]=456; controller.account["xp_quarters"]=2; controller.account["crystals"]=999
	controller.account["completions"]={"1":2,"5":1}; controller.account["unlocked_level"]=5
	controller.show_page("levels"); await capture("levels-mobile")
	controller.show_page("shop"); await capture("shop-mobile"); await capture("shop-epic-mobile",650)
	controller.account["heroes"]["club"]["weapon_cards"][0]=3
	controller.viewed_hero="club"; controller.show_page("barracks"); await capture("inventory-half-mobile",1000)
	controller.account=CampaignProgression.new_account(); controller.account["completions"]={"1":2}
	assert(CampaignRun.start(controller.account,1,"swordsman",789))
	for wave in 9: win_wave(); assert(CampaignRun.choose(controller.account,0))
	controller.account["active_run"]["loot"]["weapons"]={"katana":1}
	controller.account["active_run"]["loot"]["characters"]={"club":1}
	win_wave()
	controller.show_page("reward"); await capture("chest-mobile")
	assert(controller.account["heroes"]["club"]["unlock_card_units"]==1)
	controller._choose(0); await capture("complete-mobile")
	controller.account=CampaignProgression.new_account(); assert(CampaignRun.start(controller.account,1,"swordsman",124))
	for wave in 2: win_wave(); assert(CampaignRun.choose(controller.account,0))
	controller.account["active_run"]["loot"]["weapons"]={"swordsman":2}
	assert(CampaignRun.begin(controller.account)); assert(CampaignRun.settle(controller.account,false,0,20000,{}))
	controller.show_page("defeat"); await capture("defeat-mobile")
	controller.account["features"]["ally_slot_owned"]=true
	CampaignProgression.add_character_cards(controller.account,"vampire",2)
	controller._select("vampire")
	controller._select_ally("vampire"); await capture("ally-select-mobile")
	controller._start(1); controller.battle_arena.director.set_physics_process(false)
	for actor in controller.battle_arena.fighters: actor.freeze=true
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(controller.battle_arena.fighters.size()==3)
	assert(not controller.battle_stats.get_global_rect().intersects(controller.battle_view.arena_screen_rect))
	assert(viewport.get_texture().get_image().save_png(output.get_basename()+"-ally-battle-mobile.png")==OK)
	controller._clear_battle()
	viewport.size=Vector2i(1280,720); controller.show_page("defeat"); await capture("result-desktop")
	viewport.free(); await process_frame; await process_frame
	print("render_campaign_economy_test: PASS"); quit(0)
