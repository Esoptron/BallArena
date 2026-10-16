class_name BattleRoster
extends RefCounted
## Shared boundary validation for menu requests and direct scene/test starts.

const MIN_FIGHTERS := 2
const MAX_FIGHTERS := 20
const FORMATS: Array[StringName] = [&"teams", &"ffa"]


static func validation_errors(roster: Array, format: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if format not in FORMATS:
		errors.append("Unknown battle format: %s" % format)
	if roster.size() < MIN_FIGHTERS or roster.size() > MAX_FIGHTERS:
		errors.append("Battle requires two to twenty fighters.")
	var available := CharacterCatalog.ids()
	var teams: Dictionary = {}
	for index in roster.size():
		var entry = roster[index]
		if not entry is Dictionary:
			errors.append("Roster entry %d must be a dictionary." % index)
			continue
		var character = entry.get("character", "ordinary")
		if not character is String and not character is StringName:
			errors.append("Roster entry %d must name a character." % index)
		elif not available.has(String(character)):
			errors.append("Unknown roster character: %s" % character)
		if format == &"teams":
			var team = entry.get("team", "blue")
			if (not team is String and not team is StringName) or String(team).is_empty():
				errors.append("Roster entry %d must name a nonempty team." % index)
			else:
				teams[String(team)] = true
	if format == &"teams" and teams.size() < 2:
		errors.append("A team battle requires at least two opposing teams.")
	return errors
