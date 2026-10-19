class_name CharacterCatalog
extends RefCounted
## Definitions are read-only templates. Overrides always deep-copy a character.

static func ids() -> Array[String]:
	var result: Array[String] = []
	for file in ResourceLoader.list_directory("res://characters"):
		if file.ends_with(".tres"):
			result.append(file.trim_suffix(".tres"))
	result.sort()
	return result


static func character(id: StringName, overrides: Dictionary = {}) -> CharacterDefinition:
	var path := "res://characters/%s.tres" % id
	if not String(id).is_valid_filename() or not ResourceLoader.exists(path):
		push_error("Unknown character: %s" % id)
		return null
	var template := load(path) as CharacterDefinition
	if template == null:
		push_error("Character resource must extend CharacterDefinition: %s" % id)
		return null
	var override_errors := override_validation_errors(template, overrides)
	if not override_errors.is_empty():
		push_error("Invalid character overrides: " + "; ".join(override_errors))
		return null
	var definition := template.duplicate(false) as CharacterDefinition
	var copies: Array[AbilityDefinition] = []
	for original in template.abilities:
		if original == null:
			push_error("Character %s contains an empty ability." % id)
			return null
		var copy := original.duplicate(false) as AbilityDefinition
		copy.parameters = original.parameters.duplicate(true)
		copies.append(copy)
	definition.abilities = copies
	for key in overrides:
		if key == "abilities":
			for ability in definition.abilities:
				if overrides[key].has(String(ability.ability_id)):
					ability.parameters.merge(overrides[key][String(ability.ability_id)].duplicate(true),true)
		else:
			var value = overrides[key]
			definition.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
	return definition


static func ability(id: StringName) -> AbilityDefinition:
	return load("res://characters/abilities/%s.tres" % id) as AbilityDefinition


static func apply(fighter: ArenaBall, definition: CharacterDefinition, size: float, speed_override: float = 0.0) -> void:
	var errors := validation_errors(definition, fighter)
	if not is_finite(size) or size <= 0.0 or not is_finite(speed_override) or speed_override < 0.0:
		errors.append("Character size must be positive and speed override nonnegative.")
	if not errors.is_empty():
		push_error("Cannot apply character profile: " + "; ".join(errors))
		return
	# Release captures/protection with the old owner geometry and tags intact.
	for child in fighter.get_children():
		if child is CombatAbility:
			child.deactivate()
	fighter.character_id = definition.character_id
	fighter.character_definition = definition
	fighter.max_health = definition.reference_health
	fighter.starting_health = definition.starting_health
	fighter.current_health = definition.starting_health
	fighter.katana_wound_stage = 0
	var cut := fighter.get_node_or_null("KatanaWound")
	if cut != null:
		cut.call("_process", 0.0)
	fighter.is_vampire = definition.tags.has("vampire")
	fighter.is_swordsman = definition.tags.has("swordsman")
	fighter.weight_class = definition.weight_class
	fighter.wall_boost_scale = definition.wall_boost_scale
	fighter.boost_decay_seconds = definition.boost_decay_seconds
	fighter.mass = preload("res://scripts/combat/weight_classes.gd").factor(definition.weight_class)
	fighter.configure(size * definition.diameter_multiplier,speed_override if speed_override > 0 else definition.movement_speed)
	fighter.movement_scale = fighter.movement_speed/definition.movement_speed
	for settings in definition.abilities:
		var component := fighter.get_node_or_null(NodePath(settings.node_name)) as CombatAbility
		if component == null:
			component = settings.implementation.new() as CombatAbility
			assert(component != null,"Ability implementation must extend CombatAbility.")
			component.name = settings.node_name
			component.fighter = fighter
			component.configure(settings)
			fighter.add_child(component)
		assert(component.get_script() == settings.implementation,"Ability node name has a different implementation.")
		component.enabled = true
		component.configure(settings)
		component.reset_runtime()
	# New runtime components join the same ordered/seeding pipeline as existing ones.
	if is_instance_valid(fighter.combat_director):
		fighter.combat_director.register(fighter)


## Validate the whole profile before changing HP, movement, or active abilities.
static func validation_errors(definition: CharacterDefinition, fighter: ArenaBall = null) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("Character definition is missing.")
		return errors
	if definition.character_id.is_empty():
		errors.append("Character ID is empty.")
	if definition.reference_health <= 0 or definition.starting_health <= 0:
		errors.append("Character health values must be positive.")
	if not is_finite(definition.movement_speed) or definition.movement_speed <= 0.0:
		errors.append("Character movement speed must be finite and positive.")
	if not is_finite(definition.diameter_multiplier) or definition.diameter_multiplier <= 0.0:
		errors.append("Character diameter multiplier must be finite and positive.")
	if definition.weight_class < 0 or definition.weight_class > 4:
		errors.append("Character weight class is outside the supported range.")
	if not is_finite(definition.wall_boost_scale) or definition.wall_boost_scale < 0.0:
		errors.append("Character wall boost must be finite and nonnegative.")
	if not is_finite(definition.boost_decay_seconds) or definition.boost_decay_seconds <= 0.0:
		errors.append("Character wall boost decay must be finite and positive.")
	var names: Dictionary = {}
	var ids: Dictionary = {}
	for settings in definition.abilities:
		if settings == null:
			errors.append("Character contains an empty ability.")
			continue
		if settings.ability_id.is_empty() or ids.has(settings.ability_id):
			errors.append("Ability IDs must be nonempty and unique: %s" % settings.ability_id)
		ids[settings.ability_id] = true
		var node_name := String(settings.node_name)
		if node_name.is_empty() or node_name.validate_node_name() != node_name or names.has(node_name):
			errors.append("Ability node names must be valid and unique: %s" % node_name)
		names[node_name] = true
		var implementation := settings.implementation
		var ancestor := implementation
		var compatible := false
		var parameters: Dictionary = {}
		while ancestor != null:
			if ancestor == preload("res://scripts/combat/combat_ability.gd"):
				compatible = true
				break
			for property in ancestor.get_script_property_list():
				parameters[property["name"]] = property
			ancestor = ancestor.get_base_script()
		if not compatible or implementation == preload("res://scripts/combat/combat_ability.gd"):
			errors.append("Ability %s must implement CombatAbility." % settings.ability_id)
		for key in settings.parameters:
			if not key is String and not key is StringName:
				errors.append("Ability parameter names must be strings.")
			elif not parameters.has(String(key)) or String(key).begins_with("_") \
					or String(key) in ["fighter", "director", "definition", "ability_id", "enabled", "rng"]:
				errors.append("Unknown or internal ability parameter: %s/%s" % [settings.ability_id, key])
			elif not _matches_property_type(settings.parameters[key], parameters[String(key)]):
				errors.append("Wrong ability parameter type: %s/%s" % [settings.ability_id, key])
		if settings.weapon_weight_class < 0 or settings.weapon_weight_class > 4:
			errors.append("Ability weapon weight class is outside the supported range.")
		if not is_finite(settings.impact_strength) or settings.impact_strength < 0.0:
			errors.append("Ability impact strength must be finite and nonnegative.")
		if is_instance_valid(fighter) and not node_name.is_empty():
			var component := fighter.get_node_or_null(NodePath(node_name))
			if component != null and (not component is CombatAbility or component.get_script() != implementation):
				errors.append("Ability node has a different implementation: %s" % node_name)
	return errors


static func override_validation_errors(template: CharacterDefinition, overrides: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if template == null:
		errors.append("Character template is missing.")
		return errors
	if overrides.is_empty():
		return errors
	var properties: Dictionary = {}
	for property in template.get_script().get_script_property_list():
		properties[property["name"]] = property
	var ability_ids: Dictionary = {}
	for ability_definition in template.abilities:
		if ability_definition != null:
			ability_ids[String(ability_definition.ability_id)] = true
	for key in overrides:
		if not key is String and not key is StringName:
			errors.append("Character override names must be strings.")
		elif String(key) == "abilities":
			if not overrides[key] is Dictionary:
				errors.append("Ability overrides must be a dictionary keyed by ability ID.")
				continue
			for id in overrides[key]:
				if (not id is String and not id is StringName) or not ability_ids.has(String(id)):
					errors.append("Unknown overridden ability: %s" % id)
				elif not overrides[key][id] is Dictionary:
					errors.append("Ability parameter overrides must be dictionaries: %s" % id)
		elif not properties.has(String(key)) or String(key).begins_with("_"):
			errors.append("Unknown character override: %s" % key)
		elif not _matches_property_type(overrides[key], properties[String(key)]):
			errors.append("Wrong character override type: %s" % key)
	return errors


static func _matches_property_type(value: Variant, property: Dictionary) -> bool:
	var expected: int = property["type"]
	var actual := typeof(value)
	if expected in [TYPE_INT, TYPE_FLOAT]:
		return actual in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
	if expected in [TYPE_STRING, TYPE_STRING_NAME]:
		return actual in [TYPE_STRING, TYPE_STRING_NAME]
	return expected == TYPE_NIL or expected == actual
