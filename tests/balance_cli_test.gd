extends SceneTree
const INPUT := preload("res://tests/support/balance_cli_input.gd")
var failures: Array[String] = []
var directory: String

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func save_json(name: String, value: Variant) -> String:
	var path := directory.path_join(name + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Regression fixture must be writable.")
	if file != null:
		file.store_string(JSON.stringify(value))
		file.close()
	return path

func execute(script: String, arguments: Array[String]) -> Dictionary:
	var command := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", "240", "--script", "res://tests/" + script + ".gd",
		"--log-file", directory.path_join(script + ".log"), "--"])
	command.append_array(arguments)
	var captured: Array = []
	var status := OS.execute(OS.get_executable_path(), command, captured, true, false)
	var output := "\n".join(captured)
	return {"status": status, "output": output,
		"clean": not "ERROR:" in output and not "ObjectDB instances leaked" in output
			and not "resources still in use" in output}

func rejected(script: String, arguments: Array[String], reason: String) -> void:
	var result := execute(script, arguments)
	check(result["status"] == 1 and not "PASS:" in result["output"] and not "SCRIPT ERROR:" in result["output"]
		and "Balance" in result["output"], "CLI must explicitly reject %s without a script crash: %s" % [reason, result])

func run() -> void:
	directory = ProjectSettings.globalize_path("res://builds/qa/balance-cli/%s" % OS.get_process_id())
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Regression fixture directory must be creatable.")
	var config := {"left": "ordinary", "right": "ordinary", "candidates": [{"id": "baseline"}],
		"scenario_count": 1, "pair_runs": 1, "concurrent": 1, "time_limit": 0.02, "seed_base": 673210, "mixed": false}
	var config_path := save_json("valid", config)
	var output := directory.path_join("report.json")
	rejected("combat_balance", [], "missing simulation arguments")
	rejected("summarize_balance", [], "missing merge arguments")
	rejected("combat_balance", [directory.path_join("missing.json"), output], "missing JSON input")
	rejected("combat_balance", [save_json("array-root", []), output], "non-object JSON input")
	var broken := directory.path_join("broken.json")
	var broken_file := FileAccess.open(broken, FileAccess.WRITE)
	broken_file.store_string("{ broken")
	broken_file.close()
	rejected("combat_balance", [broken, output], "invalid JSON syntax")
	for key in ["concurrent", "scenario_count", "pair_runs", "time_limit"]:
		var invalid := config.duplicate(true)
		invalid[key] = 0
		rejected("combat_balance", [save_json("zero-" + key, invalid), output], "zero " + key)
	var invalid := config.duplicate(true)
	invalid["candidates"] = []
	rejected("combat_balance", [save_json("empty-candidates", invalid), output], "empty candidate list")
	invalid = config.duplicate(true)
	invalid["candidates"].append({"id": "baseline"})
	rejected("combat_balance", [save_json("duplicate-candidates", invalid), output], "duplicate candidate IDs")
	invalid = config.duplicate(true)
	invalid["left"] = "missing"
	rejected("combat_balance", [save_json("unknown-hero", invalid), output], "unknown hero")
	invalid = config.duplicate(true)
	invalid["candidates"][0]["overrides"] = {"ordinary": 1}
	rejected("combat_balance", [save_json("broken-overrides", invalid), output], "malformed overrides")
	check(INPUT.config_error(config).is_empty(), "Existing valid config must remain accepted.")
	var valid := execute("combat_balance", [config_path, output])
	check(valid["status"] == 0 and valid["clean"] and "PASS: 1 actual" in valid["output"], "Valid CLI must execute one actual simulation: %s" % valid)
	var loaded := INPUT.read_object(output)
	check(loaded.has("data"), "Successful simulation must write a readable JSON report.")
	if loaded.has("data"):
		var report: Dictionary = loaded["data"]
		check(report["trials"].size() == 1 and INPUT.shard_error(report).is_empty(), "Written trial must match the report protocol.")
		var merged_path := directory.path_join("merged.json")
		var merged := execute("summarize_balance", [config_path, merged_path, output])
		check(merged["status"] == 0 and merged["clean"] and "PASS: merged" in merged["output"], "Valid shard must merge successfully: %s" % merged)
		var merged_data := INPUT.read_object(merged_path)
		if merged_data.has("data"):
			check(merged_data["data"]["trials"] == report["trials"] and merged_data["data"]["summary"] == report["summary"], "Merge must preserve actual trials and recomputed valid statistics.")
		for key in ["mixed", "time_limit", "overrides"]:
			var mismatched := config.duplicate(true)
			if key == "overrides":
				mismatched["candidates"][0]["overrides"] = {"ordinary": {"movement_speed": 321.0}}
			elif key == "mixed":
				mismatched[key] = true
			else:
				mismatched[key] = 1.0
			rejected("summarize_balance", [save_json("mismatched-" + key, mismatched), merged_path, output],
				"requested configuration disagrees with actual shard " + key)
		rejected("summarize_balance", [config_path, merged_path, output, output], "duplicate trials")
		var missing := config.duplicate(true)
		missing["scenario_count"] = 2
		rejected("summarize_balance", [save_json("missing-trial-config", missing), merged_path, output], "missing trials")
		var foreign := report.duplicate(true)
		foreign["trials"][0]["scenario"]["seed"] += 20
		rejected("summarize_balance", [config_path, merged_path, save_json("foreign-trial", foreign)], "out-of-range scenario")
		foreign = report.duplicate(true)
		foreign["trials"][0].erase("participants")
		rejected("summarize_balance", [config_path, merged_path, save_json("broken-trial", foreign)], "malformed trial")
		foreign = report.duplicate(true)
		foreign["trials"] = []
		rejected("summarize_balance", [config_path, merged_path, save_json("empty-shard", foreign)], "empty shard")
		foreign = report.duplicate(true)
		foreign["physics_hz"] = 240
		var metadata_path := save_json("metadata", foreign)
		merged = execute("summarize_balance", [config_path, merged_path, metadata_path])
		merged_data = INPUT.read_object(merged_path)
		check(merged["status"] == 0 and merged["clean"] and merged_data.get("data", {}).get("physics_hz") == 240, "Merged metadata must use the shard physics rate.")
		rejected("summarize_balance", [config_path, merged_path, output, metadata_path], "incompatible physics rates")
		rejected("summarize_balance", [config_path, directory, output], "unwritable merge output")
	rejected("combat_balance", [config_path, directory], "unwritable simulation output")
	print("PASS: offline balance CLI rejects bad arguments, JSON, empty runs, mismatched shards and failed writes; valid statistics preserved" if failures.is_empty() else "FAIL: balance CLI")
	quit(0 if failures.is_empty() else 1)
