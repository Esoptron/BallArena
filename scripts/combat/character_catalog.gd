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
	var template := load("res://characters/%s.tres" % id) as CharacterDefinition
	assert(template != null, "Unknown character: %s" % id)
	var definition := template.duplicate(false) as CharacterDefinition
	var copies: Array[AbilityDefinition] = []
	for original in template.abilities:
		var copy := original.duplicate(false) as AbilityDefinition
		copy.parameters = original.parameters.duplicate(true)
		copies.append(copy)
	definition.abilities = copies
	for key in overrides:
		if key == "abilities":
			for ability in definition.abilities:
				if overrides[key].has(String(ability.ability_id)):
					ability.parameters.merge(overrides[key][String(ability.ability_id)],true)
		else:
			definition.set(key,overrides[key])
	return definition


static func ability(id: StringName) -> AbilityDefinition:
	return load("res://characters/abilities/%s.tres" % id) as AbilityDefinition


static func apply(fighter: ArenaBall, definition: CharacterDefinition, size: float, speed_override: float = 0.0) -> void:
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
	for child in fighter.get_children():
		if child is CombatAbility:
			child.deactivate()
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
