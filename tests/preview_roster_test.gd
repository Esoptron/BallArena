extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func settle() -> void:
	for frame in 12: await process_frame
func run() -> void:
	root.size = Vector2i(844,390)
	var launcher: Node = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	launcher.front_menu.show_page("free")
	var builder: Control = launcher.front_menu.selector
	await settle()
	check(builder.total_count() == 0,"New menu must not preselect any explicit copies.")
	check(not builder.start_button.disabled and builder.battle_roster().size() == 2,"Empty composition must allow an immediate preview duel.")
	builder.select_character(0,&"katana",false)
	builder.select_character(1,&"club",false)
	check(builder.battle_roster() == [{"character":"katana","team":"blue"},{"character":"club","team":"red"}],"Paging without + must change the actual duel.")
	builder.start_battle()
	var arena: BallArena = launcher.battle.get_node("Arena")
	check(arena.fighters.size() == 2 and arena.fighters[0].character_id == &"katana" and arena.fighters[1].character_id == &"club","Actual spawn must use the preview roster.")
	launcher.return_to_menu()
	builder.change_count(0,1)
	check(builder.total_count() == 1 and builder.battle_roster().size() == 2,"First + must save one copy, replacing rather than adding to the preview.")
	builder.change_count(1,1)
	check(builder.total_count() == 2 and builder.battle_roster().size() == 2,"One saved fighter per side must stay a 1v1.")
	builder.select_character(0,&"vampire",false)
	check(builder.battle_roster()[0]["character"] == "katana" and builder.counts["katana"][0] == 1,"Paging must preserve explicitly saved fighters without adding previews.")
	builder.change_count(0,1)
	check(builder.battle_roster().size() == 3,"A new + must extend mixed composition.")
	builder.change_count(0,-1)
	builder.set_count("katana",0,0)
	builder.set_count("club",1,0)
	check(builder.total_count() == 0 and builder.battle_roster().size() == 2 and not builder.start_button.disabled,"Removing all copies must restore preview duels.")
	check(not builder.panels[0]["badge"].visible,"Flame number must only indicate explicitly saved copies.")
	for dimensions in [Vector2i(844,390),Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(390,844)]:
		root.size = dimensions
		await settle()
		for panel in builder.panels:
			var stage: Control = panel["stage"]
			var viewport: SubViewport = panel["viewport"]
			var scale: float = viewport.canvas_transform.x.length()
			check(scale >= 2 and scale <= 3,"Preview detail must be bounded to 2–3x, never allocate an unbounded buffer.")
			check(absf(viewport.size.x-stage.size.x*scale) <= 1 and absf(viewport.size.y-stage.size.y*scale) <= 1,"Portrait buffer must track stage size and display density.")
			check(panel["portrait"].texture == viewport.get_texture(),"Display must use the full-resolution portrait texture.")
	root.size = Vector2i(844,390)
	await settle()
	builder.set_count("vampire",0,20)
	check(builder.total_count() == 19 and builder.battle_roster().size() == 20,"Teams must reserve one slot for the other preview.")
	builder.select_character(1,&"swordsman",false)
	check(not builder.panels[1]["plus"].disabled,"At capacity an empty side may explicitly save its existing preview.")
	builder.change_count(1,1)
	check(builder.total_count() == 20 and builder.battle_roster().size() == 20,"Saving a reserved preview must not duplicate it.")
	for hero in builder.ids:
		for side in 2: builder.set_count(hero,side,0)
	builder.set_mode(&"ffa")
	check(builder.battle_roster().size() == 2,"Empty FFA must also use the two previews.")
	builder.change_count(0,1)
	check(builder.battle_roster().size() == 2,"Single explicit FFA fighter must retain a preview opponent.")
	builder.set_count("vampire",0,20)
	check(builder.total_count() == 20 and builder.battle_roster().size() == 20 and not builder.start_button.disabled,"FFA must still support twenty saved fighters in one column.")
	launcher.front_menu.show_page("home")
	launcher.front_menu.show_page("free")
	builder = launcher.front_menu.selector
	check(builder.counts["vampire"][0] == 20 and builder.mode == &"ffa","Leaving and returning must preserve explicit counts and mode.")
	launcher.queue_free()
	await process_frame
	print("Preview duels, explicit rosters and portrait density: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
