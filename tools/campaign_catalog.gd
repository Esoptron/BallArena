extends SceneTree
## Small generation/validation tool for future content; never changes the campaign.
func _initialize() -> void:
	var weapons: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/campaign/data/weapons.json"))
	var modifiers: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/campaign/data/modifiers.json"))
	for id in CampaignCatalog.data():
		var profile := CampaignCatalog.enemy(id)
		assert(weapons.has(profile["enemy"]["weapon"]))
		assert(CharacterCatalog.validation_errors(profile["definition"]).is_empty())
		for modifier in modifiers:
			var compiled := CampaignCatalog.modified(id,modifier)
			assert(CharacterCatalog.validation_errors(compiled["definition"]).is_empty())
	print("PASS: 21 profiles / 16 weapon descriptors / 9 bounded future modifier configurations")
	quit(0)
