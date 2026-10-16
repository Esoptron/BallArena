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
	for hero in ["swordsman","knifeman","katana"]:
		var main := load("res://scenes/main.tscn").instantiate() as Node2D
		var arena := main.get_node("Arena") as BallArena
		arena.blue_character_id = hero
		arena.red_character_id = &"ordinary"
		arena.randomize_spawns = false
		root.add_child(main)
		arena.director.set_physics_process(false)
		var a := arena.get_node("Balls/BlueBall") as ArenaBall
		var b := arena.get_node("Balls/RedBall") as ArenaBall
		for fighter in [a,b]:
			fighter.freeze = true
			fighter.set_physics_process(false)
		a.position = Vector2(410,300)
		b.position = Vector2(490,300)
		b.current_health = 100000
		var weapon: SwordAbility
		for child in a.get_children():
			if child is SwordAbility and child.is_enabled(): weapon = child
		weapon.rotation = 0.0
		var hud: Control = main.progression
		var before: String = hud.labels[0].text
		check(hud.labels[1].text == "Нет усилений за попадание","Ordinary ball must not show fictional progression.")
		check(weapon.try_hit(b),"Actual successful hit must drive the HUD.")
		check(hud.labels[0].text != before,"HUD must update immediately after real hit.")
		match hero:
			"swordsman": check("Скорость" in hud.labels[0].text and not "Вращение" in hud.labels[0].text,"Sword progression must show movement speed, not unchanged spin.")
			"knifeman": check("Вращение" in hud.labels[0].text,"Knife progression must show orbit gain.")
			"katana": check("Крит" in hud.labels[0].text,"Katana progression must show critical chance.")
		before = hud.labels[0].text
		b.set_invulnerable(b,true)
		weapon.cooldown_remaining = 0.0
		weapon._contact_victim = null
		check(not weapon.try_hit(b),"Protected target must reject damage.")
		hud.refresh()
		check(hud.labels[0].text == before,"Blocked hit must not inflate displayed progression.")
		for dimensions in [Vector2i(1280,900),Vector2i(390,844),Vector2i(640,360),Vector2i(844,390),Vector2i(1920,1080)]:
			root.size = dimensions
			for frame in 3: await process_frame
			main.get_node("Camera2D").force_update_scroll()
			hud.layout()
			var logical_size := root.get_visible_rect().size
			var arena_bounds: Rect2 = main.arena_screen_rect
			if preload("res://scripts/screen_layout.gd").landscape(logical_size):
				check(hud.cards[0].get_global_rect().end.x < arena_bounds.position.x and hud.cards[1].global_position.x > arena_bounds.end.x,"Landscape stats must stay beside the arena.")
			else:
				check(hud.position.y > arena_bounds.end.y,"Portrait progression must stay below the arena.")
			check(hud.position.y + hud.size.y <= logical_size.y + 1,"Progression must fit viewport height.")
			check(hud.cards[0].position.y + hud.cards[0].size.y <= hud.cards[1].position.y if logical_size.x < 600 else hud.cards[0].position.x + hud.cards[0].size.x <= hud.cards[1].position.x,"Character panels must not overlap.")
			check(hud.position.x >= 0 and hud.position.x + hud.size.x <= logical_size.x,"Progression must fit viewport width.")
			check(arena.arena_size == Vector2(960,600) and arena.scale == Vector2.ONE,"HUD must not stretch the physical arena.")
			if hero == "katana" and DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().size() >= 2:
				if dimensions.x == 1280 or dimensions.x == 390:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0 if dimensions.x == 1280 else 1])
		main.queue_free()
		await process_frame
		Engine.time_scale = 1.0
	# Restart reads fresh combat state, rather than retaining the previous HUD delta.
	var fresh := load("res://scenes/main.tscn").instantiate() as Node2D
	fresh.get_node("Arena").randomize_spawns = false
	root.add_child(fresh)
	check("(+0)" in fresh.progression.labels[0].text,"New duel must show zero accumulated progression.")
	fresh.queue_free()
	await process_frame
	print("Live progression and responsive HUD: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
