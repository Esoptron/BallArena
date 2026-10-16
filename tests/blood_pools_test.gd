extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var blood := ArenaBlood.new()
	root.add_child(blood)
	blood.set_process(false)
	blood._surface_splash(Vector2(400,595.8),Vector2.UP,4.2)
	assert(blood.surface_marks.size() == 1)
	assert(blood.impact_drops.size() == 5)
	for tiny in blood.impact_drops:
		assert(tiny["radius"] >= 1.134 and tiny["radius"] <= 2.1)
	blood.advance(30.0)
	assert(not blood.surface_marks.is_empty())
	assert(blood.impact_drops.is_empty())
	blood.surface_marks.clear()
	blood._add_surface_pool(Vector2(400,595.8),Vector2.UP,4.2)
	var old_radius: float = blood.surface_marks[0]["radius"]
	blood._add_surface_pool(Vector2(400,595.8),Vector2.UP,4.2)
	assert(blood.surface_marks[0]["radius"] > old_radius)
	blood.surface_marks.clear()
	# Two separated patches become one when a third patch bridges their edges.
	blood._add_surface_pool(Vector2(100,595.8),Vector2.UP,4.2)
	blood._add_surface_pool(Vector2(144,595.8),Vector2.UP,4.2)
	assert(blood.surface_marks.size() == 2)
	blood._add_surface_pool(Vector2(122,595.8),Vector2.UP,4.2)
	assert(blood.surface_marks.size() == 1)
	assert(blood.surface_marks[0]["start"] <= 88.241 and blood.surface_marks[0]["end"] >= 155.759)
	for index in 600:
		blood._surface_splash(Vector2(float(index % 960),595.8),Vector2.UP,4.2)
	assert(blood.surface_marks.size() <= blood.max_surface_pools)
	assert(blood.surface_marks.size() == 1)
	assert(blood.surface_marks[0]["shape"].size() == 48)
	assert(blood.surface_marks[0]["end"] - blood.surface_marks[0]["start"] > 590.0)
	blood.queue_free()
	await process_frame
	print("PASS: permanent glossy pools, larger splashes, accumulation and bounded geometry")
	quit(0)
