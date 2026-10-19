extends SceneTree
## Generic catalog-driven battles. No character-specific simulation branches.
const INPUT := preload("res://tests/support/balance_cli_input.gd")
const ARENA := preload("res://scenes/arena.tscn")
var config: Dictionary
var jobs: Array[Dictionary] = []
var active: Array[Dictionary] = []
var results: Array[Dictionary] = []
var cursor: int = 0
var output: String
var last_progress: int = 0
var effective_profiles: Dictionary = {}
var source_hashes: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func cosmetics_off(node: Node) -> void:
	node.set_process(false)
	for child in node.get_children():
		cosmetics_off(child)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[1].strip_edges().is_empty():
		fail("Usage: combat_balance.gd -- CONFIG.json OUTPUT.json")
		return
	var loaded := INPUT.read_object(args[0])
	if loaded.has("error"):
		fail(loaded["error"])
		return
	config = loaded["data"]
	var input_error := INPUT.config_error(config)
	if not input_error.is_empty():
		fail(input_error)
		return
	output = args[1]
	source_hashes = BalanceSnapshot.source_hashes()
	for candidate in config["candidates"]:
		effective_profiles[candidate["id"]] = {}
		for id in [config.get("left","swordsman"),config.get("right","vampire")]:
			effective_profiles[candidate["id"]][id] = BalanceSnapshot.describe(id,candidate.get("overrides",{}).get(id,{}))
		for scenario_index in int(config.get("scenario_count",24)):
			var scenario := CombatScenarioFactory.make(int(config.get("seed_base",90000))+scenario_index,
				config.get("mixed",true))
			for swap in int(config.get("pair_runs",2)):
				jobs.append({"candidate":candidate,"scenario":scenario,"swap":swap})
	print("BALANCE v2 START: %d catalog-driven bouts" % jobs.size())
	fill_slots()
	var delta := 1.0/Engine.physics_ticks_per_second
	while not active.is_empty():
		await physics_frame
		for index in range(active.size()-1,-1,-1):
			var match_data := active[index]
			var actors: Array[ArenaBall] = match_data["actors"]
			var arena: BallArena = match_data["arena"]
			var elapsed := arena.director.time_seconds
			var dead := actors.any(func(actor: ArenaBall) -> bool: return actor.current_health <= 0)
			var timeout: bool = elapsed >= float(config.get("time_limit",120.0))
			if dead or timeout:
				var metrics: CombatMetrics = match_data["metrics"]
				metrics.detach()
				var row := metrics.finish(actors,elapsed,timeout)
				row["candidate"] = match_data["job"]["candidate"]["id"]
				row["scenario"] = match_data["job"]["scenario"]
				row["swap"] = match_data["job"]["swap"]
				results.append(row)
				match_data["viewport"].queue_free()
				active.remove_at(index)
			else:
				match_data["metrics"].sample(actors,delta)
		fill_slots()
		if results.size()-last_progress >= 32:
			last_progress = results.size()
			print("BALANCE v2 progress: %d/%d" % [results.size(),jobs.size()])
	if results.is_empty() or results.size() != jobs.size():
		fail("Simulation did not complete every requested match.")
		return
	var report := {"engine_version":Engine.get_version_info()["string"],"arguments":OS.get_cmdline_args(),"config":config,"physics_hz":Engine.physics_ticks_per_second,
		"trials":results,"effective_profiles":effective_profiles,"source_hashes":source_hashes,"summary":CombatStatistics.by_candidate(results,config["candidates"])}
	var write_error := INPUT.write_object(output, report)
	if not write_error.is_empty():
		fail(write_error)
		return
	print("PASS: %d actual catalog-driven matches recorded" % results.size())
	quit(0)


func fail(message: String) -> void:
	push_error("Balance input/output: " + message)
	quit(1)



func fill_slots() -> void:
	while cursor < jobs.size() and active.size() < int(config.get("concurrent",48)):
		var job := jobs[cursor]
		cursor += 1
		var viewport := SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.size = Vector2i(1,1)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(viewport)
		var arena := ARENA.instantiate() as BallArena
		arena.randomize_spawns = false
		arena.spawn_seed = job["scenario"]["seed"]
		arena.blue_character_id = config.get("left","swordsman") if job["swap"]%2==0 else config.get("right","vampire")
		arena.red_character_id = config.get("right","vampire") if job["swap"]%2==0 else config.get("left","swordsman")
		arena.character_overrides = job["candidate"].get("overrides",{})
		arena.ball_speed = 0
		viewport.add_child(arena)
		var actors: Array[ArenaBall] = [arena.get_node("Balls/BlueBall"),arena.get_node("Balls/RedBall")]
		var scenario: Dictionary = job["scenario"]
		for index in 2:
			var position_values: Array = scenario["a" if index==0 else "b"]
			var direction_values: Array = scenario["direction_a" if index==0 else "direction_b"]
			var actor := actors[index]
			actor.battle_role = "left" if index == job["swap"]%2 else "right"
			actor.position = Vector2(position_values[0],position_values[1])
			actor.initial_direction = Vector2(direction_values[0],direction_values[1])
			actor.movement_scale *= float(scenario["speed"])/320.0*float(scenario["ratio_a" if index==0 else "ratio_b"])
			actor.movement_speed *= float(scenario["speed"])/320.0*float(scenario["ratio_a" if index==0 else "ratio_b"])
			actor.start_motion()
			actor.blood_effects = null
			actor.combat_effects = null
			actor.experimental_blood_runoff = false
		arena.director.set_match_seed(scenario["seed"])
		cosmetics_off(arena)
		var metrics := CombatMetrics.new()
		metrics.attach(actors,arena.director)
		active.append({"job":job,"viewport":viewport,"arena":arena,"actors":actors,"metrics":metrics})
