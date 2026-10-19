extends SceneTree
var failures: Array[String] = []
var folder := ""
const LAYOUT := preload("res://scripts/screen_layout.gd")
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 12: await process_frame
func snapshot(name: String) -> void:
	if DisplayServer.get_name() == "headless" or folder.is_empty(): return
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"Screenshot must save.")
func contained(rect: Rect2) -> bool:
	var screen := root.get_visible_rect().size
	return rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= screen.x + 1 and rect.end.y <= screen.y + 1
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty(): folder = OS.get_cmdline_user_args()[0]
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_LANDSCAPE,"Phones must request landscape orientation.")
	root.size = Vector2i(844,390)
	var launcher: Node = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	await settle()
	var menu: Control = launcher.front_menu
	for button in menu.buttons.values(): check(contained(button.get_global_rect()),"Home actions must fit in landscape without scrolling.")
	check(menu.home_grid.columns == 1,"Concept home must stack the four actions vertically.")
	await snapshot("landscape-home")
	menu.show_page("modes")
	await snapshot("landscape-modes")
	menu.show_page("free")
	var builder: Control = menu.selector
	builder.set_count("swordsman",0,2)
	builder.set_count("vampire",0,3)
	for dimensions in [Vector2i(844,390),Vector2i(740,360),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size = dimensions
		await settle()
		check(builder.landscape_layout and not builder.cards.vertical,"Landscape cards must sit side by side.")
		check(builder.panels[0]["panel"].get_global_rect().end.x < builder.panels[1]["panel"].global_position.x,"Hero cards must not overlap.")
		for panel in builder.panels:
			for key in ["plus","minus","stage","badge"]: check(contained(panel[key].get_global_rect()),"Hero controls must stay on screen: "+key)
			check(panel["plus"].get_global_rect().end.y < builder.start_button.global_position.y,"Copy controls must be above pinned start button.")
			check(panel["plus"].size.y >= 48,"Touch controls must remain at least 48 units tall.")
		for button in builder.mode_buttons: check(contained(button.get_global_rect()),"Mode buttons must be visible.")
		check(contained(builder.start_button.get_global_rect()),"Pinned start action must stay on screen.")
	# Resize the same UI across orientations: retain selection and all mixed counts.
	root.size = Vector2i(390,844)
	await settle()
	check(builder.cards.vertical and builder.modes.get_parent() == builder.column,"Tall windows must retain a usable stacked fallback.")
	root.size = Vector2i(844,390)
	await settle()
	check(builder.counts["swordsman"][0] == 2 and builder.counts["vampire"][0] == 3,"Rotation must preserve mixed rosters.")
	await snapshot("landscape-free")
	builder.set_mode(&"ffa")
	await snapshot("landscape-free-ffa")
	builder.set_mode(&"teams")
	# Preview every hero to exercise wide-stage weapon bounds and paging cleanup.
	for id in builder.ids:
		builder.select_character(0,StringName(id),false)
		await settle()
		var panel: Dictionary = builder.panels[0]
		var fighter: ArenaBall = panel["fighter"]
		check(fighter.position.y + fighter.diameter * fighter.scale.y * 0.5 <= panel["stage"].size.y + 1,"Portrait body must fit its stage: "+id)
		if id == "club":
			var weapon: ClubAbility = fighter.get_node("Club")
			for segment in weapon.current_weapon_segments():
				for endpoint in segment:
					var drawn: Vector2 = fighter.position+(endpoint-fighter.global_position)*fighter.scale.x
					var r := weapon.weapon_radius()*fighter.scale.x
					check(drawn.x >= r-1 and drawn.y >= r-1 and drawn.x+r <= panel["stage"].size.x+1 and drawn.y+r <= panel["stage"].size.y+1,"Enlarged club must fit the phone preview.")
	builder.select_character(0,&"swordsman",false)
	for hero in builder.ids:
		for side in 2: builder.set_count(hero,side,0)
	builder.set_count("swordsman",0,1)
	builder.set_count("vampire",1,1)
	builder.start_button.pressed.emit()
	var main: Node2D = launcher.battle
	var arena: BallArena = main.get_node("Arena")
	arena.director.set_physics_process(false)
	for fighter in arena.fighters: fighter.freeze = true
	arena.fighters[0].position = Vector2(360,320)
	arena.fighters[1].position = Vector2(600,280)
	for dimensions in [Vector2i(844,390),Vector2i(740,360),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size = dimensions
		await settle()
		main.camera.force_update_scroll()
		main.progression.layout()
		var bounds: Rect2 = main.arena_screen_rect
		check(contained(bounds),"Arena must be fully visible.")
		check(is_equal_approx(bounds.size.x / bounds.size.y,1.6),"Arena must retain 8:5 proportions.")
		check(arena.arena_size == Vector2(960,600) and arena.scale == Vector2.ONE,"UI must leave physical arena unchanged.")
		check(main.camera.zoom.x == main.camera.zoom.y,"Camera scaling must be uniform.")
		for card in main.progression.cards:
			check(contained(card.get_global_rect()),"Battle stats must stay visible: %s / %s" % [dimensions,card.get_global_rect()])
			check(not card.get_global_rect().intersects(bounds),"Stats must not cover the arena.")
		if dimensions == Vector2i(844,390):
			check(bounds.size.y >= 290,"Landscape arena must reclaim height for readability.")
			check(70 * main.camera.zoom.x >= 33,"Standard body must be larger on the base phone viewport.")
	root.size = Vector2i(844,390)
	await snapshot("landscape-battle")
	launcher.return_to_menu()
	await settle()
	check(builder.counts["swordsman"][0] == 1 and builder.counts["vampire"][1] == 1,"Returning from battle must preserve composition.")
	menu.show_page("modes")
	menu.buttons["campaign"].pressed.emit()
	check(launcher.campaign.visible and launcher.campaign.page=="levels","Landscape campaign button must open the five-level campaign map.")
	launcher.queue_free()
	await process_frame
	print("Landscape menu, orientation, larger arena and roster persistence: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
