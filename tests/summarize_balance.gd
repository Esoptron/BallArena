extends SceneTree
## Merge independent simulation shards using the same generic statistics.
const INPUT := preload("res://tests/support/balance_cli_input.gd")

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error("Balance merge input/output: " + message)
	quit(1)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or args[1].strip_edges().is_empty():
		fail("Usage: summarize_balance.gd -- CONFIG.json OUTPUT.json SHARD.json [SHARD.json ...]")
		return
	var loaded := INPUT.read_object(args[0])
	if loaded.has("error"):
		fail(loaded["error"])
		return
	var config: Dictionary = loaded["data"]
	var problem := INPUT.config_error(config)
	if not problem.is_empty():
		fail(problem)
		return
	var rows: Array = []
	var shards: Array = []
	var profiles: Dictionary = {}
	var hashes: Dictionary = {}
	var seen: Dictionary = {}
	var candidate_ids: Dictionary = {}
	for candidate in config["candidates"]:
		candidate_ids[candidate["id"]] = candidate.get("overrides", {})
	var version := ""
	var physics_rate := 0
	for path in args.slice(2):
		loaded = INPUT.read_object(path)
		if loaded.has("error"):
			fail(loaded["error"])
			return
		var data: Dictionary = loaded["data"]
		problem = INPUT.shard_error(data)
		if not problem.is_empty():
			fail("%s: %s" % [path, problem])
			return
		if version.is_empty():
			hashes = data["source_hashes"]
			profiles = data["effective_profiles"]
			version = data["engine_version"]
			physics_rate = int(data["physics_hz"])
		if hashes != data["source_hashes"] or profiles != data["effective_profiles"] \
				or version != data["engine_version"] or physics_rate != int(data["physics_hz"]):
			fail("Shard versions, physics rates or effective parameters differ.")
			return
		for side in ["left", "right"]:
			var fallback := "swordsman" if side == "left" else "vampire"
			if data["config"].get(side, fallback) != config.get(side, fallback):
				fail("Shard character pairing differs from the requested configuration.")
				return
		# Seed ranges/counts may differ between shards; simulation rules may not.
		for key in {"mixed": true, "time_limit": 120.0}:
			var fallback: Variant = true if key == "mixed" else 120.0
			if data["config"].get(key, fallback) != config.get(key, fallback):
				fail("Shard simulation rules differ from the requested configuration: " + key)
				return
		var shard_candidates: Dictionary = {}
		for candidate in data["config"]["candidates"]:
			shard_candidates[candidate["id"]] = candidate.get("overrides", {})
		for row in data["trials"]:
			var seed_value := int(row["scenario"]["seed"])
			if not candidate_ids.has(row["candidate"]) or int(row["swap"]) >= int(config.get("pair_runs", 2)) \
					or seed_value < int(config.get("seed_base", 90000)) \
					or seed_value >= int(config.get("seed_base", 90000)) + int(config.get("scenario_count", 24)):
				fail("Shard contains a candidate, seed or role swap outside the requested validation set.")
				return
			if candidate_ids[row["candidate"]] != shard_candidates.get(row["candidate"]):
				fail("Shard candidate overrides differ from the requested configuration.")
				return
			var key := str(row["candidate"])+"/"+str(seed_value)+"/"+str(int(row["swap"]))
			if seen.has(key):
				fail("Duplicate scenario and role swap: " + key)
				return
			seen[key] = true
			rows.append(row)
		shards.append({"config":data["config"],"arguments":data["arguments"],"file":path})
	var expected: int = int(config.get("scenario_count", 24)) * int(config.get("pair_runs", 2)) * config["candidates"].size()
	if rows.is_empty() or rows.size() != expected:
		fail("Missing validation trials: expected %d, found %d." % [expected, rows.size()])
		return
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a["scenario"]["seed"] != b["scenario"]["seed"]:
			return a["scenario"]["seed"] < b["scenario"]["seed"]
		return a["swap"] < b["swap"])
	var report := {"config":config,"trials":rows,"shards":shards,
		"physics_hz":physics_rate,"engine_version":version,
		"source_hashes":hashes,"effective_profiles":profiles,
		"summary":CombatStatistics.by_candidate(rows,config["candidates"])}
	problem = INPUT.write_object(args[1], report)
	if not problem.is_empty():
		fail(problem)
		return
	print("PASS: merged and recomputed %d catalog-driven bouts" % rows.size())
	quit(0)
