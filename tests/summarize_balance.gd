extends SceneTree
## Merge independent simulation shards using the same generic statistics.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var rows: Array = []
	var shards: Array = []
	var profiles: Dictionary = {}
	var hashes: Dictionary = {}
	var seen: Dictionary = {}
	var version := ""
	for path in args.slice(2):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		if hashes.is_empty():
			hashes = data["source_hashes"]
			profiles = data["effective_profiles"]
			version = data["engine_version"]
		assert(hashes == data["source_hashes"] and profiles == data["effective_profiles"],"Shard versions or parameters differ.")
		assert(data["config"]["left"] == config["left"] and data["config"]["right"] == config["right"])
		for row in data["trials"]:
			var key := str(row["candidate"])+"/"+str(row["scenario"]["seed"])+"/"+str(row["swap"])
			assert(not seen.has(key),"Duplicate scenario and role swap.")
			seen[key] = true
			rows.append(row)
		shards.append({"config":data["config"],"arguments":data["arguments"],"file":path})
	assert(rows.size() == int(config["scenario_count"])*int(config["pair_runs"])*config["candidates"].size(),"Missing validation trials.")
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a["scenario"]["seed"] != b["scenario"]["seed"]:
			return a["scenario"]["seed"] < b["scenario"]["seed"]
		return a["swap"] < b["swap"])
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	assert(file != null,"Could not save merged report.")
	file.store_string(JSON.stringify({"config":config,"trials":rows,"shards":shards,
		"physics_hz":Engine.physics_ticks_per_second,"engine_version":version,
		"source_hashes":hashes,"effective_profiles":profiles,
		"summary":CombatStatistics.by_candidate(rows,config["candidates"])},"  "))
	print("PASS: merged and recomputed %d catalog-driven bouts" % rows.size())
	quit(0)
