extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280,900)
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	for frame in 10:
		await process_frame
	check(launcher.front_menu.visible and launcher.battle == null, "Project must open the main menu before battle.")
	launcher.open_duel()
	check(launcher.menu.visible,"Quick duel must open character selection.")
	check(launcher.menu.panels.size() == 2, "Menu must provide independent selections.")
	launcher.menu.select_character(0, &"katana")
	for frame in 3:
		await process_frame
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	check(launcher.menu.panels[0]["buttons"].has("katana"), "Katana must appear in both selection panels.")
	launcher.menu.select_character(0, &"katana")
	launcher.menu.start_button.pressed.emit()
	check(launcher.battle.get_node("Arena/Balls/BlueBall").has_node("Katana"), "Menu must instantiate actual katana ability.")
	launcher.return_to_menu()
	check(launcher.menu.panels[0]["buttons"].has("knifeman"), "Knife must appear in both selection panels.")
	launcher.menu.select_character(0, &"knifeman")
	launcher.menu.start_button.pressed.emit()
	check(launcher.battle.get_node("Arena/Balls/BlueBall").has_node("Knives"), "Menu must create the knife ability for the selected player.")
	launcher.return_to_menu()
	launcher.menu.select_character(0, &"vampire")
	launcher.menu.select_character(1, &"swordsman")
	launcher.menu.start_button.pressed.emit()
	var arena := launcher.battle.get_node("Arena") as BallArena
	check(arena.blue_character_id == &"vampire" and arena.red_character_id == &"swordsman", "Start button must apply both selected profiles.")
	check(arena.get_node("Balls/BlueBall").is_vampire and arena.get_node("Balls/RedBall").is_swordsman, "Selected roles must receive their actual abilities.")
	check(arena.get_node("Balls/BlueBall").ball_color.b > arena.get_node("Balls/BlueBall").ball_color.r, "Player must stay blue even as vampire.")
	launcher.return_to_menu()
	check(launcher.menu.visible and launcher.menu.selections[0] == &"vampire", "Back must preserve selection.")
	launcher.start_battle(&"vampire", &"vampire")
	arena = launcher.battle.get_node("Arena") as BallArena
	check(arena.get_node("Balls/BlueBall").is_vampire and arena.get_node("Balls/RedBall").is_vampire, "Mirror matches must be supported.")
	arena.get_node("Balls/RedBall").take_damage(10000,arena.get_node("Balls/BlueBall"))
	check(launcher.match_finished, "Match death must show the result.")
	launcher.return_to_menu()
	root.size = Vector2i(390,844)
	for frame in 10:
		await process_frame
	check(launcher.menu.cards is VBoxContainer, "Phone layout must stack character panels.")
	check(launcher.menu.content.size.x <= root.get_visible_rect().size.x, "Phone menu must not overflow horizontally.")
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().size() > 1:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	launcher.start_battle(&"ordinary", &"swordsman")
	for frame in 5:
		await process_frame
	check(launcher.hud.get_child(0).size.x <= root.get_visible_rect().size.x, "Battle navigation must fit the phone screen.")
	launcher.return_to_menu()
	root.size = Vector2i(1280,900)
	for frame in 5:
		await process_frame
	check(launcher.menu.cards is HBoxContainer, "Widening must restore side-by-side layout.")
	launcher.queue_free()
	await process_frame
	print("Character selection: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
