extends SceneTree
var failures: Array[String] = []
var launcher: Node
var snapshot_dir: String = ""
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or snapshot_dir.is_empty(): return
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(snapshot_dir.path_join(name+".png")) == OK,"Screenshot must save.")
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty(): snapshot_dir = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280,900)
	launcher = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	check(launcher.front_menu.visible and not launcher.menu.visible,"Launch must show main menu.")
	check(launcher.front_menu.buttons.has("exit") and launcher.front_menu.buttons.has("settings"),"Main menu must include exit and future settings.")
	await capture("menu-home")
	launcher.front_menu.buttons["settings"].pressed.emit()
	check(launcher.front_menu.page == "settings","Settings must open its placeholder page.")
	launcher.front_menu.buttons["back"].pressed.emit()
	launcher.front_menu.buttons["modes"].pressed.emit()
	check(launcher.front_menu.buttons.has("level_01"),"Trials must expose its first playable level.")
	await capture("menu-modes")
	launcher.front_menu.buttons["level_01"].pressed.emit()
	check(launcher.campaign.visible and launcher.campaign.page=="levels","Campaign button must open the isolated campaign map.")
	launcher._close_campaign()
	# Preserve coverage for the original 1-v-3 roster/launcher API independently.
	launcher.start_roster_battle(load("res://levels/level_01.tres").roster(),&"teams","Кампания · 01")
	var arena := launcher.battle.get_node("Arena") as BallArena
	check(arena.fighters.size() == 4 and arena.director.group_battle,"Level must contain four registered fighters.")
	var hero := arena.get_node("Balls/BlueBall") as ArenaBall
	check(hero.character_id == &"swordsman" and arena.director.opponents_of(hero).size() == 3,"Level hero must be swordsman against three enemies.")
	for enemy in arena.director.opponents_of(hero):
		check(enemy.character_id == &"ordinary" and not enemy.is_swordsman and not enemy.is_vampire,"Level enemies must be unarmed ordinary balls.")
	arena.director.set_physics_process(false)
	for fighter in arena.fighters: fighter.freeze = true
	await capture("level-01")
	var prior: Node = launcher.battle
	launcher.replay.pressed.emit()
	check(launcher.battle != prior and not prior.is_inside_tree(),"Replay must detach the old match safely from inside its button signal.")
	arena = launcher.battle.get_node("Arena")
	hero = arena.fighters[0]
	arena.director.set_physics_process(false)
	for fighter in arena.fighters: fighter.freeze = true
	var enemies := arena.director.opponents_of(hero)
	enemies[0].add_bleeding(hero)
	enemies[1].take_damage(10000,hero)
	check(not launcher.match_finished and not enemies[0].bleeding_stacks.is_empty(),"First casualty must not finish a team battle or clear other bleeding.")
	arena.director.refresh_targets()
	check(hero.opponent != enemies[1],"A dead opponent must be replaced by a living enemy.")
	enemies[0].take_damage(10000,hero)
	check(not launcher.match_finished,"Battle must continue until all three enemies die.")
	enemies[2].take_damage(10000,hero)
	check(launcher.match_finished and launcher.winner_label.text == "ПОБЕДА","Last enemy death must finish the level with victory.")
	launcher.hud.get_child(0).get_child(0).pressed.emit()
	check(launcher.front_menu.visible and launcher.front_menu.page == "modes","Level exit must return to its modes screen.")
	launcher.front_menu.show_page("free")
	var menu: Control = launcher.front_menu
	menu._set_count(0,"vampire",1)
	check(not menu.free_start.disabled,"Empty side must use its current preview for an instant duel.")
	var builder: Control = menu.selector
	for id in builder.ids:
		for side in 2: builder.set_count(id,side,2)
	check(not menu.free_start.disabled,"Builder must accept twenty participants.")
	root.size = Vector2i(390,844)
	await capture("menu-free-phone")
	for frame in 3: await process_frame
	check(menu.content.size.x <= root.get_visible_rect().size.x-30.0,"Free builder must fit phone width.")
	menu.free_start.pressed.emit()
	arena = launcher.battle.get_node("Arena")
	check(arena.fighters.size() == 20,"Free mode must create all selected participants.")
	var identities := {}
	for fighter in arena.fighters: identities[fighter.actor_id] = true
	check(identities.size() == 20,"Each fighter must have a distinct identity.")
	var sword: SwordAbility
	var ally: ArenaBall
	for fighter in arena.fighters:
		if fighter.team_id == &"blue":
			if fighter.character_id == &"swordsman": sword = fighter.get_node("Sword")
			else: ally = fighter
	check(not sword.try_hit(ally),"Weapons must reject friendly fire.")
	for frame in 240:
		await physics_frame
		for fighter in arena.fighters:
			check(fighter.position.x >= -2 and fighter.position.y >= -2 and fighter.position.x <= 962 and fighter.position.y <= 602,"Twenty-fighter simulation must keep bodies in the arena.")
	arena.director.set_physics_process(false)
	for fighter in arena.fighters: fighter.freeze = true
	await capture("free-battle-phone")
	launcher.return_to_menu()
	check(menu.free_counts["swordsman"][0] == 2,"Returning must preserve chosen counts.")
	menu._set_count(10,"swordsman",0)
	check(builder.total_count() == 20,"Builder must clamp copies to the twenty-participant limit.")
	for id in menu.free_counts: menu.free_counts[id] = [0,0]
	menu.free_counts["vampire"] = [3,0]
	builder.set_mode(&"ffa")
	check(not menu.free_start.disabled,"Free-for-all must allow all participants in one builder column.")
	menu.free_start.pressed.emit()
	arena = launcher.battle.get_node("Arena")
	check(arena.fighters.size() == 3 and arena.director.opponents_of(arena.fighters[0]).size() == 2,"Free-for-all must treat every other actor as hostile.")
	arena.fighters[1].take_damage(10000,arena.fighters[0])
	check(not launcher.match_finished,"Free-for-all must continue while more than one participant survives.")
	arena.fighters[2].take_damage(10000,arena.fighters[0])
	check(launcher.match_finished,"Last survivor must win free-for-all.")
	launcher.return_to_menu()
	# Two vampires cannot carry the same victim in two contradictory directions.
	var capture_roster: Array[Dictionary] = [{"character":"knifeman","team":"blue"},{"character":"vampire","team":"red"},{"character":"vampire","team":"red"}]
	launcher.start_roster_battle(capture_roster,&"teams","Тест захвата")
	arena = launcher.battle.get_node("Arena")
	var victim := arena.fighters[0]
	var first := arena.fighters[1].get_node("Vampire") as VampireFangs
	var second := arena.fighters[2].get_node("Vampire") as VampireFangs
	check(first.try_bite(victim) and not second.try_bite(victim),"A captured victim must not be captured by a second vampire.")
	launcher.return_to_menu()
	# Actual first-level combat, with production stats, random positions and real physics.
	if DisplayServer.get_name() == "headless":
		launcher.start_roster_battle(load("res://levels/level_01.tres").roster(),&"teams","Испытание 01")
		arena = launcher.battle.get_node("Arena")
		for frame in 43200:
			await physics_frame
			if launcher.match_finished: break
		print("Live level duration: ",arena.director.time_seconds)
		check(launcher.match_finished and arena.fighters[0].current_health > 0,"Actual first level must be playable and finish with a surviving swordsman.")
		launcher.return_to_menu()
	launcher.queue_free()
	await process_frame
	print("Main menu, free battles and level 01: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
