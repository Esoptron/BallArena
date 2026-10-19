class_name CampaignLevels
extends RefCounted
static var _levels: Array = []
static func all() -> Array:
	if _levels.is_empty(): _levels=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/campaign/data/levels.json"))
	return _levels
static func encounter(level: int, battle: int) -> Dictionary:
	assert(level>=1 and level<=5 and battle>=1 and battle<=10)
	return all()[level-1]["battles"][battle-1].duplicate(true)
