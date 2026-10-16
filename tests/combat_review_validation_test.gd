extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	for id in CharacterCatalog.ids():
		var issues := CharacterCatalog.validation_errors(CharacterCatalog.character(StringName(id)))
		check(issues.is_empty(), "Existing %s profile must remain valid: %s" % [id, issues])
	var roster: Array = [{"character": "swordsman", "team": "blue"}, {"character": "vampire", "team": "red"}]
	var saved := roster.duplicate(true)
	check(BattleRoster.validation_errors(roster, &"teams").is_empty(), "Current team roster must be accepted.")
	check(BattleRoster.validation_errors(roster, &"ffa").is_empty(), "Current FFA roster must be accepted.")
	check(roster == saved, "Validation must not mutate roster order or entries.")
	check(not BattleRoster.validation_errors(roster, &"invalid").is_empty(), "Unknown formats must not silently become FFA.")
	check(not BattleRoster.validation_errors([{}, {}], &"teams").is_empty(), "One-team requests must not create unfinished matches.")
	check(not BattleRoster.validation_errors([1, {}], &"ffa").is_empty(), "Malformed roster entries must be rejected before construction.")
	check(not BattleRoster.validation_errors([{"character": "missing"}, {}], &"ffa").is_empty(), "Unknown character IDs must fail boundary validation.")
	var invalid := CharacterCatalog.character(&"swordsman")
	invalid.movement_speed = 0.0
	check(not CharacterCatalog.validation_errors(invalid).is_empty(), "Zero speed must be rejected before profile division.")
	invalid = CharacterCatalog.character(&"swordsman")
	invalid.abilities.append(invalid.abilities[0])
	check(not CharacterCatalog.validation_errors(invalid).is_empty(), "Duplicate ability nodes must be rejected before partial application.")
	invalid = CharacterCatalog.character(&"swordsman")
	invalid.abilities[0].parameters["nonexistent_parameter"] = 1
	check(not CharacterCatalog.validation_errors(invalid).is_empty(), "Unknown ability parameters must be reported before runtime mutation.")
	invalid = CharacterCatalog.character(&"swordsman")
	invalid.abilities[0].parameters["fighter"] = null
	check(not CharacterCatalog.validation_errors(invalid).is_empty(), "Parameters must not overwrite component ownership/context.")
	invalid = CharacterCatalog.character(&"swordsman")
	invalid.abilities[0].parameters["base_damage"] = {"invalid": 1}
	check(not CharacterCatalog.validation_errors(invalid).is_empty(), "Invalid parameter types must be rejected before applying any profile fields.")
	invalid = CharacterCatalog.character(&"swordsman")
	check(not CharacterCatalog.override_validation_errors(invalid, {"abilities": 1}).is_empty(), "Malformed override containers must not reach dictionary operations.")
	check(not CharacterCatalog.override_validation_errors(invalid, {"abilities": {"unknown": {}}}).is_empty(), "Misspelled override abilities must not silently disappear.")
	check(not CharacterCatalog.override_validation_errors(invalid, {"unknown": 1}).is_empty(), "Misspelled profile keys must not silently disappear.")
	var fighter := load("res://scenes/ball.tscn").instantiate() as ArenaBall
	invalid = CharacterCatalog.character(&"swordsman")
	invalid.abilities[0].node_name = &"CollisionShape2D"
	check(not CharacterCatalog.validation_errors(invalid, fighter).is_empty(), "A name collision with a body node must be rejected before construction.")
	fighter.free()
	var arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	arena.blue_character = 99
	check(not arena.validation_errors().is_empty(), "Invalid legacy indices must not crash an array lookup in exported builds.")
	arena.free()
	var invalid_arena := load("res://scenes/arena.tscn").instantiate() as BallArena
	invalid_arena.character_overrides = {"swordsman": 42}
	check(not invalid_arena.validation_errors().is_empty(), "Malformed per-character JSON must fail before typed profile application.")
	# This test deliberately exercises the logged rejection of an invalid scene.
	var previous_errors := Engine.print_error_messages
	Engine.print_error_messages = false
	root.add_child(invalid_arena)
	Engine.print_error_messages = previous_errors
	check(invalid_arena.process_mode == Node.PROCESS_MODE_DISABLED and invalid_arena.director == null,
		"Invalid arena must stop without creating a partial match.")
	for child in invalid_arena.get_node("Balls").get_children():
		check(child.freeze, "Invalid arena must freeze child bodies which initialized before its parent.")
	check(invalid_arena.get_node("Walls").get_child_count() == 0, "Invalid overrides must be rejected before creating walls.")
	invalid_arena.queue_free()
	await process_frame
	print("PASS: profile, runtime component and roster boundary validation" if failures.is_empty() else "FAIL: combat validation")
	quit(0 if failures.is_empty() else 1)
