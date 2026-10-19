extends RefCounted
## Validation and I/O shared only by the offline balance command-line tools.

const DEFAULT_COUNTS := {"scenario_count": 24, "pair_runs": 2, "concurrent": 48}

static func read_object(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Cannot read JSON file: %s (%s)" % [path, error_string(FileAccess.get_open_error())]}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "Invalid JSON in %s, line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()]}
	if not parser.data is Dictionary:
		return {"error": "JSON root must be an object: %s" % path}
	return {"data": parser.data}

static func write_object(path: String, data: Dictionary) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Cannot write JSON file: %s (%s)" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	var status := file.get_error()
	file.close()
	return "Cannot finish JSON file: %s (%s)" % [path, error_string(status)] if status != OK else ""

static func is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

static func is_integer(value: Variant, minimum: int = 0) -> bool:
	return is_number(value) and float(value) >= minimum and float(value) == floorf(float(value))

static func config_error(config: Dictionary) -> String:
	var available := CharacterCatalog.ids()
	for key in ["left", "right"]:
		var id = config.get(key, "swordsman" if key == "left" else "vampire")
		if not id is String or not available.has(id):
			return "Unknown %s character: %s" % [key, id]
	for key in DEFAULT_COUNTS:
		if not is_integer(config.get(key, DEFAULT_COUNTS[key]), 1):
			return "%s must be a positive integer." % key
	if not is_integer(config.get("seed_base", 90000)):
		return "seed_base must be a nonnegative integer."
	if not is_number(config.get("time_limit", 120.0)) or float(config.get("time_limit", 120.0)) <= 0.0:
		return "time_limit must be finite and positive."
	if not config.get("mixed", true) is bool:
		return "mixed must be a boolean."
	if not config.get("candidates") is Array or config["candidates"].is_empty():
		return "candidates must be a nonempty array."
	var seen: Dictionary = {}
	for candidate in config["candidates"]:
		if not candidate is Dictionary or not candidate.get("id") is String or candidate["id"].strip_edges().is_empty():
			return "Each candidate must have a nonempty string ID."
		if seen.has(candidate["id"]):
			return "Duplicate candidate ID: %s" % candidate["id"]
		seen[candidate["id"]] = true
		var overrides = candidate.get("overrides", {})
		if not overrides is Dictionary:
			return "Candidate overrides must be an object."
		for id in overrides:
			if not id is String or not available.has(id) or not overrides[id] is Dictionary:
				return "Overrides must use known character IDs and object values: %s" % id
			var template := CharacterCatalog.character(StringName(id))
			var errors := CharacterCatalog.override_validation_errors(template, overrides[id])
			if not errors.is_empty():
				return "; ".join(errors)
			var profile := CharacterCatalog.character(StringName(id), overrides[id])
			errors = CharacterCatalog.validation_errors(profile)
			if not errors.is_empty():
				return "; ".join(errors)
	return ""

static func shard_error(data: Dictionary) -> String:
	for field in ["source_hashes", "effective_profiles", "config"]:
		if not data.get(field) is Dictionary or data[field].is_empty():
			return "Shard %s must be a nonempty object." % field
	if not data.get("engine_version") is String or data["engine_version"].is_empty() \
			or not is_integer(data.get("physics_hz"), 1) or not data.get("arguments") is Array:
		return "Shard must contain engine version, physics rate and arguments."
	if not data.get("trials") is Array or data["trials"].is_empty():
		return "Shard trials must be a nonempty array."
	var error := config_error(data["config"])
	if not error.is_empty():
		return error
	for row in data["trials"]:
		if not row is Dictionary or not row.get("candidate") is String or not is_integer(row.get("swap")) \
				or not is_number(row.get("duration")) or row["duration"] < 0 or not row.get("timeout") is bool \
				or not row.get("winner_role", "") is String or not row.get("scenario") is Dictionary \
				or not row.get("participants") is Dictionary or row["participants"].is_empty():
			return "Malformed trial identity, duration or participants."
		var scenario: Dictionary = row["scenario"]
		if not is_integer(scenario.get("seed")) or not scenario.get("group") is String or not is_number(scenario.get("speed")):
			return "Malformed trial scenario."
		for participant in row["participants"].values():
			if not participant is Dictionary or not participant.get("role", "") is String \
					or not _numeric_array(participant.get("hit_times")) or not participant.get("abilities") is Dictionary:
				return "Malformed trial participant."
			for field in ["hits", "damage_dealt", "damage_received", "healing", "capture_seconds", "protection_seconds", "attack_lock_seconds", "recaptures_without_reply"]:
				if not is_number(participant.get(field)):
					return "Missing numeric participant metric: %s" % field
			for ability in participant["abilities"].values():
				if not ability is Dictionary or not _numeric_array(ability.get("times", [])) or not _numeric_array(ability.get("success_times", [])):
					return "Malformed trial ability times."
				for field in ["starts", "successes", "completed", "hits"]:
					if not is_number(ability.get(field, 0)):
						return "Malformed trial ability metric: %s" % field
	return ""

static func _numeric_array(value: Variant) -> bool:
	return value is Array and value.all(func(item: Variant) -> bool: return is_number(item))
