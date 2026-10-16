extends SceneTree
var failures: Array[String] = []
var folder: String = ""
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func snapshot(name: String) -> void:
	if DisplayServer.get_name() == "headless" or folder.is_empty(): return
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"Screenshot must save.")
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty(): folder = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(390,844)
	var launcher: Node = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	var menu: Control = launcher.front_menu
	check(launcher.menu.panels.is_empty(),"Unified mobile menu must not allocate unused legacy preview viewports.")
	check(menu.buttons["modes"].text == "Выбор режима","Home must expose mode selection without the old feature panel.")
	await snapshot("mobile-home")
	menu.buttons["modes"].pressed.emit()
	check(menu.buttons["campaign"].text == "Основная кампания","Mode selection must expose the campaign button.")
	await snapshot("mobile-modes")
	menu.buttons["back"].pressed.emit()
	menu.buttons["free"].pressed.emit()
	var builder: Control = menu.selector
	check(builder.panels.size() == 2 and builder.find_children("*","SpinBox",true,false).is_empty(),"Free battle must use two hero cards, without the old quantity table.")
	builder.select_character(0,&"swordsman",false)
	builder.set_count("swordsman",0,2)
	builder.select_character(0,&"vampire")
	builder.set_count("vampire",0,3)
	check(builder.counts["swordsman"][0] == 2 and builder.panels[0]["badge"].count == 3,"Changing hero must preserve other hero copies and show the current quantity.")
	builder.select_character(0,&"swordsman")
	check(builder.panels[0]["badge"].count == 2,"Returning to a hero must restore its flame number.")
	var id: StringName = builder.selections[1]
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	builder.panels[1]["stage"].gui_input.emit(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(-70,0)
	builder.panels[1]["stage"].gui_input.emit(drag)
	touch.pressed = false
	builder.panels[1]["stage"].gui_input.emit(touch)
	check(builder.selections[1] != id,"A horizontal touch swipe must change the hero.")
	id = builder.selections[1]
	touch.pressed = true
	builder.panels[1]["stage"].gui_input.emit(touch)
	drag.relative = Vector2(45,100)
	builder.panels[1]["stage"].gui_input.emit(drag)
	touch.pressed = false
	builder.panels[1]["stage"].gui_input.emit(touch)
	check(builder.selections[1] == id,"Predominantly vertical scrolling must not change the hero.")
	builder.select_character(1,&"vampire",false)
	for dimensions in [Vector2i(320,640),Vector2i(390,844),Vector2i(430,932),Vector2i(1080,2400)]:
		root.size = dimensions
		for frame in 6: await process_frame
		var width := root.get_visible_rect().size.x
		var viewport_height := root.get_visible_rect().size.y
		check(builder.start_button.global_position.y >= 0 and builder.start_button.global_position.y+builder.start_button.size.y <= viewport_height,"Start battle must remain in reach at the viewport bottom.")
		check(menu.content.size.x <= width-30+1,"Mobile content must stay inside logical viewport width.")
		for panel in builder.panels:
			check(panel["minus"].size.y >= 48 and panel["plus"].size.y >= 48,"Copy buttons must retain touch-friendly height.")
			check(panel["badge"].get_child_count() == 1 and panel["badge"].get_child(0) is ColorRect,"Flame must use one retained shader rectangle, without particle emitters.")
	root.size = Vector2i(390,844)
	await snapshot("mobile-free")
	# Rapid paging must clean outgoing portraits instead of accumulating nodes.
	for page in 24:
		builder.cycle(0,1)
		await process_frame
	for frame in 65: await process_frame
	check(builder.panels[0]["viewport"].get_child_count() <= 2,"Carousel must keep at most two portraits during transitions.")
	builder.set_mode(&"ffa")
	builder.select_character(0,&"vampire",false)
	await snapshot("mobile-free-ffa")
	for hero in builder.ids:
		for side in 2: builder.set_count(hero,side,0)
	builder.set_count("swordsman",0,20)
	check(builder.total_count() == 20 and not builder.start_button.disabled,"Free-for-all must allow twenty copies from one side.")
	builder.change_count(0,1)
	check(builder.total_count() == 20,"Copy increment must not exceed twenty.")
	builder.set_mode(&"teams")
	check(builder.start_button.disabled,"Teams must require opponents on both sides.")
	builder.set_count("swordsman",0,2)
	builder.set_count("vampire",0,3)
	builder.set_count("ordinary",1,3)
	builder.start_button.pressed.emit()
	var arena := launcher.battle.get_node("Arena") as BallArena
	check(arena.fighters.size() == 8,"Mixed roster must spawn every stored hero copy.")
	check(arena.arena_size == Vector2(960,600) and arena.scale == Vector2.ONE,"Arena must retain its physical size and 8:5 aspect.")
	arena.director.set_physics_process(false)
	for fighter in arena.fighters: fighter.freeze = true
	await snapshot("mobile-battle")
	launcher.return_to_menu()
	menu.show_page("home")
	menu.show_page("free")
	check(menu.selector.counts["swordsman"][0] == 2 and menu.selector.counts["vampire"][0] == 3,"Leaving the screen must preserve mixed composition.")
	launcher.queue_free()
	await process_frame
	print("Mobile menus, carousel, flame counts and mixed rosters: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
