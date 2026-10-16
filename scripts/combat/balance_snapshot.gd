class_name BalanceSnapshot
extends RefCounted


static func describe(id: StringName, overrides: Dictionary) -> Dictionary:
	var profile := CharacterCatalog.character(id,overrides)
	var abilities: Array = []
	for ability in profile.abilities:
		abilities.append({"ability_id":String(ability.ability_id),"script":ability.implementation.resource_path,
			"weapon_weight_class":ability.weapon_weight_class,"impact_strength":ability.impact_strength,
			"tags":Array(ability.tags),"parameters":ability.parameters.duplicate(true)})
	return {"id":String(id),"health":profile.starting_health,"reference_health":profile.reference_health,
		"wall_boost_scale":profile.wall_boost_scale,"boost_decay_seconds":profile.boost_decay_seconds,
		"weight_class":profile.weight_class,"diameter_multiplier":profile.diameter_multiplier,
		"movement_speed":profile.movement_speed,"abilities":abilities}


static func source_hashes() -> Dictionary:
	var files: Dictionary = {}
	for folder in ["res://scripts","res://characters","res://scenes","res://tests"]:
		_collect(folder,files)
	files["res://project.godot"] = FileAccess.get_sha256("res://project.godot")
	return files


static func _collect(folder: String, result: Dictionary) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd","tres","tscn","gdshader"]:
			var path := folder.path_join(file)
			result[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(child),result)
