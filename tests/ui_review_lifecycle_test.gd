extends SceneTree
## Regression coverage for UI boundaries, reusable portraits and screen disposal.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle(frames: int = 12) -> void:
	for frame in frames:
		await process_frame

func check_portrait(fighter: ArenaBall) -> void:
	check(fighter.freeze and fighter.collision_layer == 0 and fighter.collision_mask == 0, "Portraits must not participate in physical collisions.")
	for component in fighter.combat_components:
		check(not component.is_physics_processing() and not component.is_processing(), "Static portraits must not advance or redraw combat abilities every frame.")
	check(not fighter.get_node("HealthDisplay").is_processing(), "Hidden portrait HP must not poll transforms every frame.")

func run() -> void:
	root.size = Vector2i(844, 390)
	var launcher: Node = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	var front: Control = launcher.front_menu
	front.show_page("free")
	await settle()
	var selector: Control = front.selector
	var selections: Array = selector.selections.duplicate()
	selector.select_character(-1, &"swordsman")
	selector.select_character(2, &"swordsman")
	selector.select_character(0, &"not_a_character")
	selector.cycle(-1, 1)
	selector.change_count(2, 1)
	check(selector.selections == selections and selector.total_count() == 0, "Malformed selection API calls must leave a valid selection unchanged.")
	for id in selector.ids:
		selector.select_character(0, StringName(id), false)
		check_portrait(selector.panels[0]["fighter"])
	for change in 80:
		selector.cycle(0, 1)
		if change % 5 == 0:
			await process_frame
	await settle(80)
	check(selector.panels[0]["viewport"].get_child_count() == 1, "Rapid carousel changes must eventually retain exactly the current portrait.")
	var old_selector: WeakRef = weakref(selector)
	var old_viewport: WeakRef = weakref(selector.panels[0]["viewport"])
	front.show_page("home")
	await settle(2)
	check(old_selector.get_ref() == null and old_viewport.get_ref() == null, "Leaving the selection page must free its viewports, fighters and tween owner.")
	check(front.free_start == null and front.status_label == null, "Page references must not retain freed selection controls.")
	front.show_page("not_a_page")
	check(front.page == "home" and front.buttons.has("free"), "Unknown routes must not destroy the current page.")
	launcher.open_duel()
	await settle()
	var duel: Control = launcher.menu
	check(not duel.is_processing(), "Legacy static portraits must be positioned by layout signals, not idle polling.")
	duel.select_character(-1, &"swordsman")
	duel.select_character(0, &"not_a_character")
	for id in CharacterCatalog.ids():
		duel.select_character(0, StringName(id))
		check_portrait(duel.panels[0]["fighter"])
	await settle()
	launcher.start_battle(&"not_a_character", &"vampire")
	check(launcher.battle == null and duel.visible, "Invalid duel profiles must be rejected before hiding the menu.")
	var invalid_rosters: Array[Array] = [
		[{"character": "swordsman", "team": "blue"}, {"character": "missing", "team": "red"}],
		[{"character": "swordsman", "team": "blue"}, {"character": "vampire", "team": "blue"}],
	]
	for invalid in invalid_rosters:
		var typed: Array[Dictionary] = []
		for entry in invalid:
			typed.append(entry)
		launcher.start_roster_battle(typed, &"teams", "Invalid")
		check(launcher.battle == null, "Invalid roster requests must not start partially configured matches.")
	launcher.last_format = &"ffa"
	launcher.start_battle(&"swordsman", &"vampire")
	check(launcher.last_format == &"teams", "A legacy duel must reset a previous free-for-all format.")
	var old_match: WeakRef = weakref(launcher.battle)
	launcher.replay.pressed.emit()
	await settle(2)
	check(old_match.get_ref() == null, "Replay must free the detached match.")
	launcher.return_to_menu()
	check(launcher.battle == null and launcher.hud == null and launcher.winner_label == null and launcher.replay == null, "Returning must clear all battle-owned references.")
	launcher.queue_free()
	await settle(2)
	print("UI review lifecycle, static portraits, API boundaries: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
