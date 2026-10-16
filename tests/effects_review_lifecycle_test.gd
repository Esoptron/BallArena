extends SceneTree
## Regression coverage for teardown races and independently resized effect batches.

const BALL := preload("res://scenes/ball.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func run() -> void:
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	for fighter in arena.fighters:
		fighter.freeze = true
		fighter.set_physics_process(false)
		for ability in fighter.combat_components:
			ability.set_physics_process(false)
	var first := arena.fighters[0]
	var second := arena.fighters[1]

	var blood := ArenaBlood.new()
	blood.max_drops = 1
	blood.max_splashes = 1
	root.add_child(blood)
	blood.set_process(false)
	blood.max_splashes = 240
	for index in 200:
		blood.spawn_spray(Vector2(200, 200), Vector2.RIGHT, 2.0)
	blood.advance(0.01)
	check(blood._particle_layer.multimesh.instance_count >= 200,
		"Changing the spray budget after ready must resize its batch before writes.")
	check(blood._particle_layer.multimesh.visible_instance_count == 200,
		"Every spray remains visible after a runtime budget increase.")

	var effects := ArenaCombatEffects.new()
	effects.max_orbs = 1
	effects.spray_rate = 0.0
	root.add_child(effects)
	effects.set_process(false)
	effects.max_orbs = 200
	effects.orb_rate = 1000.0
	var drain := effects.start_drain(first, second)
	effects.advance(0.01)
	check(effects.orbs.size() > 1 and effects._orb_layer.multimesh.instance_count >= 200,
		"Changing the orb budget after ready must keep all live orbs in a resized batch.")
	var old_orb: Dictionary = effects.orbs[0]
	var old_parent := second.get_parent()
	old_parent.remove_child(second)
	effects.advance(0.01)
	check(effects.drains.is_empty() and effects.orbs.is_empty(),
		"A removed but unfreed actor must stop a drain without global-transform errors.")
	check(effects.orb_position(old_orb) == Vector2.ZERO,
		"An expired public orb reference must not index a missing drain.")
	old_parent.add_child(second)
	effects.stop_drain(drain)

	var first_batch := BloodDrawing.make_instances(BloodDrawing.get_drop_mesh(), 2)
	var second_batch := BloodDrawing.make_instances(BloodDrawing.get_drop_mesh(), 2)
	root.add_child(first_batch)
	root.add_child(second_batch)
	check(first_batch.multimesh != second_batch.multimesh,
		"Shared immutable art must not share mutable instance transforms or capacities.")
	BloodDrawing.ensure_capacity(first_batch, 5)
	check(second_batch.multimesh.instance_count == 2,
		"Resizing one effect must not change another layer.")
	check(first_batch.multimesh.mesh == second_batch.multimesh.mesh,
		"Separate instance buffers must still reuse retained mesh geometry.")

	var fragments := ArenaDeathFragments.new()
	root.add_child(fragments)
	fragments.set_process(false)
	fragments.set_physics_process(false)
	fragments.watch(first)
	fragments.watch(first)
	check(fragments.fighters.size() == 1, "Watching an actor twice must not duplicate death capture.")
	var ghost := BALL.instantiate() as ArenaBall
	root.add_child(ghost)
	ghost.freeze = true
	fragments._capture_busy = true
	fragments._begin_capture.call_deferred({
		"fighter": weakref(ghost), "diameter": 70.0, "departure": Vector2.ZERO
	})
	ghost.free()
	await process_frame
	await process_frame
	check(not fragments._capture_busy,
		"Actor removal between queue and deferred capture must release the capture lock.")

	# Keep one synthetic shard group alive while exercising proxy teardown.
	var group := Node2D.new()
	group.add_child(Node2D.new())
	fragments.add_child(group)
	fragments.groups.append(group)
	fragments._physics_process(0.0)
	check(not fragments.weapons.is_empty(), "The proxy fixture must include a live sword.")
	if not fragments.weapons.is_empty():
		var proxy: Dictionary = fragments.weapons[0]
		var ability: CombatAbility = proxy["ability"]
		if ability != null:
			check(fragments._weapon_segment(first, 99, ability).is_empty(),
				"A changed segment count must not index past the weapon array.")
			ability.free()
			fragments._physics_process(0.0)
			check(proxy["body"].collision_layer == 0,
				"A removed ability must disable its shard-only weapon collider safely.")
		proxy["body"].free()
		fragments._physics_process(0.0)
	var retained := SubViewport.new()
	fragments.add_child(retained)
	fragments._captures[group.get_instance_id()] = retained
	group.free()
	fragments._process(0.0)
	check(fragments._captures.is_empty() and fragments.groups.is_empty(),
		"A removed puzzle group must release its retained viewport.")
	await process_frame
	check(not is_instance_valid(retained), "Orphan capture cleanup must actually free its viewport.")

	if DisplayServer.get_name() != "headless":
		await verify_capture_after_actor_removal(fragments)

	fragments.queue_free()
	blood.queue_free()
	effects.queue_free()
	first_batch.queue_free()
	second_batch.queue_free()
	arena.queue_free()
	await process_frame
	print("Effects teardown, independent batch budgets and deferred capture: ",
		"PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)


func verify_capture_after_actor_removal(fragments: ArenaDeathFragments) -> void:
	var fighter := BALL.instantiate() as ArenaBall
	root.add_child(fighter)
	fighter.freeze = true
	fragments._capture(fighter, 70.0, Vector2.ZERO)
	fighter.free()
	await RenderingServer.frame_post_draw
	await process_frame
	check(not fragments._capture_busy and fragments.groups.is_empty(),
		"Actor removal during GPU capture must cancel it and leave the service reusable.")
	await process_frame
	check(fragments.get_child_count() == 0, "Cancelled GPU capture must release its viewport.")

	# A cancellation must not prevent the next valid portrait from becoming shards.
	fighter = BALL.instantiate() as ArenaBall
	root.add_child(fighter)
	fighter.freeze = true
	fragments._capture(fighter, 70.0, Vector2.ZERO)
	await RenderingServer.frame_post_draw
	await process_frame
	check(fragments.groups.size() == 1 and not fragments._capture_busy,
		"The next capture must succeed after an asynchronous cancellation.")
	fighter.queue_free()
