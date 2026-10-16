extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var effects := ArenaCombatEffects.new()
	root.add_child(effects)
	effects.set_process(false)
	effects.spawn_slash(Vector2(200, 200), Vector2(1, -0.3))
	assert(effects.slashes.size() == 1)
	effects.advance(0.05)
	await process_frame
	await process_frame
	effects.advance(0.18)
	assert(effects.slashes.is_empty())
	print("PASS: slash draws and expires after 0.22 game seconds")
	quit(0)
