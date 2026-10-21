class_name CampaignMapData
extends RefCounted
## Read-only visual projection. CampaignRun remains the authority for starting battles.
const PATH := "res://scripts/campaign/data/level_map.json"
const STATES := ["open", "current", "locked", "unavailable", "completed"]
static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _config

static func current_level(account: Dictionary) -> int:
	var run: Dictionary = account.get("active_run", {})
	return int(run["level"]) if not run.is_empty() else mini(int(account["unlocked_level"]), CampaignLevels.all().size())

static func entries(account: Dictionary) -> Array[Dictionary]:
	var implemented := {}
	for level in CampaignLevels.all(): implemented[int(level["level"])] = level
	var result: Array[Dictionary] = []
	var run: Dictionary = account.get("active_run", {})
	for source: Dictionary in config()["levels"]:
		var entry := source.duplicate(true)
		var number := int(entry["level_number"])
		var wins := CampaignEconomy.completions(account, number)
		var state: String = entry.get("state", "auto")
		if not implemented.has(number) or state == "unavailable": state = "unavailable"
		elif number > int(account["unlocked_level"]): state = "locked"
		elif state == "auto":
			state = "current" if number == current_level(account) else ("completed" if wins > 0 else "open")
		entry["state"] = state
		entry["is_current"] = state == "current"
		entry["is_unavailable"] = state == "unavailable"
		entry["completions"] = wins
		entry["name"] = implemented[number]["name"] if implemented.has(number) else "Уровень %d" % number
		entry["can_enter"] = state in ["open", "current", "completed"] and (run.is_empty() or int(run["level"]) == number)
		if implemented.has(number) and wins > 0:
			entry["chest_type"] = entry.get("repeat_chest_type", "bronze")
		entry["reward_type"] = CampaignEconomy.chest_type(number, wins)
		entry["reward_percent"] = CampaignEconomy.reward_half_units(wins) * 50
		var theme: Dictionary = config()["theme"].duplicate()
		theme.merge(config().get("zones",{}).get(entry.get("zone_id",""),{}).get("theme",{}),true)
		entry["zone_theme"] = theme
		result.append(entry)
	return result

static func position_of(entry: Dictionary) -> Vector2:
	return Vector2(float(entry["map_position"][0]), float(entry["map_position"][1]))

static func end_position(entries_value: Array[Dictionary]) -> Vector2:
	var right := 0.0
	for entry in entries_value: right = maxf(right, position_of(entry).x)
	return Vector2(right + float(config()["terminal"]["gap"]), 0)

static func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}; var numbers := {}
	for entry in config()["levels"]:
		if ids.has(entry["id"]) or numbers.has(int(entry["level_number"])): errors.append("Duplicate map level")
		ids[entry["id"]] = true; numbers[int(entry["level_number"])] = true
		if not entry.get("state", "auto") in STATES + ["auto"]: errors.append("Unknown state")
		if not config()["chest_skins"].has(entry["chest_type"]): errors.append("Unknown chest skin")
		var point := position_of(entry)
		if not point.is_finite() or point.x < 0 or point.y < 148 or point.y > float(config()["design_height"]) - 36: errors.append("Map position outside design bounds")
	return errors
