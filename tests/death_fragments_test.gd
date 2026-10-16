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
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	var arena := main.get_node("Arena") as BallArena
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] in ["knifeman","katana","club"]:
		arena.blue_character_id = OS.get_cmdline_user_args()[1]
	arena.randomize_spawns = false
	root.add_child(main)
	arena.director.set_physics_process(false)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	blue.freeze = true
	red.freeze = true
	blue.position = Vector2(460,300)
	red.position = Vector2(570,300)
	blue.get_node("Sword").rotation = -PI * 0.5
	var camera := main.get_node("Camera2D") as Camera2D
	camera.zoom = Vector2.ONE * 3.0
	camera.global_position = Vector2(515,290)
	var victim := blue
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "vampire":
		victim = red
	var survivor := red if victim == blue else blue
	for frame in 8:
		await process_frame
	arena.death_fragments.rng.seed = 42017
	victim.take_damage(10000,survivor,&"test")
	check(not victim.visible and victim.current_health == 0, "Dead body must disappear immediately.")
	await create_timer(0.06,true,false,true).timeout
	var effects := arena.death_fragments
	check(effects.groups.size() == 1, "Death must create one puzzle group.")
	if effects.groups.size() == 1:
		var pieces := effects.groups[0].get_children()
		check(pieces.size() >= 15 and pieces.size() <= 80, "Death must produce a bounded number of irregular pieces.")
		print("Pieces: ", pieces.size())
		var max_velocity := 0.0
		var weapon_pieces := 0
		for body: RigidBody2D in pieces:
			max_velocity = maxf(max_velocity, body.linear_velocity.length())
			var art := body.get_child(1) as Polygon2D
			check(art.texture != null and art.uv.size() == art.polygon.size(), "Every piece must keep the actual portrait texture and matching UVs.")
			if victim.is_vampire:
				# Fangs are shorter than 0.8 body diameters. Check their ivory pixels,
				# rather than the distance rule designed for long sword fragments.
				if has_ivory_pixels(art): weapon_pieces += 1
			elif body.global_position.distance_to(victim.global_position) > victim.diameter * 0.8:
				weapon_pieces += 1
		print("Max shard speed: ", max_velocity)
		check(max_velocity < 500.0, "Initial shards must not explode from collider overlap.")
		check(weapon_pieces > 0, "Weapon must break into pieces along with the body.")
		check(effects.weapons.size() > 0, "Survivor weapon must have shard-only physical colliders.")
	if not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	# Send real rigid shards into the survivor body and weapon, after the preview.
	if effects.groups.size() == 1 and effects.groups[0].get_child_count() >= 2 and not effects.weapons.is_empty():
		var body_shard := effects.groups[0].get_child(0) as RigidBody2D
		body_shard.global_position = survivor.global_position + Vector2(survivor.diameter * 0.5 + 25.0, 0)
		body_shard.linear_velocity = Vector2.LEFT * 140.0
		var weapon_shard := effects.groups[0].get_child(1) as RigidBody2D
		var weapon: AnimatableBody2D = effects.weapons[0]["body"]
		var side := Vector2.RIGHT.rotated(weapon.global_rotation)
		weapon_shard.global_position = weapon.global_position + side * 25.0
		weapon_shard.linear_velocity = -side * 140.0
	await create_timer(1.3,true,false,true).timeout
	print("Shard contacts: body=", effects.body_contacts, " weapon=", effects.weapon_contacts)
	check(effects.body_contacts > 0, "Shards must physically collide with surviving bodies.")
	check(effects.weapon_contacts > 0, "Shards must physically collide with surviving weapons.")
	if not effects.groups.is_empty() and effects.groups[0].get_child_count() > 0:
		check(effects.groups[0].get_child(0).modulate.a < 1.0, "Pieces must gradually fade.")
	await create_timer(1.95,true,false,true).timeout
	check(effects.groups.is_empty() and effects.weapons.is_empty(), "Pieces and weapon colliders must be cleaned up after three real seconds.")
	main.queue_free()
	await process_frame
	print("Death fragments: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)


func has_ivory_pixels(art: Polygon2D) -> bool:
	var image := art.texture.get_image()
	var bounds := Rect2(art.uv[0],Vector2.ZERO)
	for point in art.uv: bounds = bounds.expand(point)
	for y in range(maxi(0,floori(bounds.position.y)),mini(image.get_height(),ceili(bounds.end.y)),2):
		for x in range(maxi(0,floori(bounds.position.x)),mini(image.get_width(),ceili(bounds.end.x)),2):
			if not Geometry2D.is_point_in_polygon(Vector2(x,y),art.uv): continue
			var color := image.get_pixel(x,y)
			if color.a > 0.3 and minf(color.r,minf(color.g,color.b)) > 0.6: return true
	return false
