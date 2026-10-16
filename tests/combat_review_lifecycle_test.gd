extends SceneTree

const BALL := preload("res://scenes/ball.tscn")
const PROBE := preload("res://tests/combat_review_probe.gd")
var failures: Array[String] = []
var resolved: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var fighter := BALL.instantiate() as ArenaBall
	fighter.actor_id = "probe"
	root.add_child(fighter)
	CharacterCatalog.apply(fighter, CharacterCatalog.character(&"ordinary"), 70.0)
	var first := CombatDirector.new()
	var second := CombatDirector.new()
	root.add_child(first)
	root.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	first.register(fighter)
	first.set_match_seed(431)
	var settings := AbilityDefinition.new()
	settings.ability_id = &"probe"
	settings.node_name = &"Probe"
	settings.implementation = PROBE
	settings.parameters = {"payload": {"nested": [1]}}
	var profile := CharacterDefinition.new()
	profile.character_id = &"probe"
	profile.abilities = [settings]
	CharacterCatalog.apply(fighter, profile, 70.0)
	var component := fighter.get_node("Probe") as CombatAbility
	check(component.director == first and first.abilities.has(component), "New live-profile components must use their existing director.")
	check(component.get("seeded") == 1, "A late component must receive the active match seed once.")
	component.get("payload")["nested"].append(2)
	check(settings.parameters["payload"]["nested"] == [1], "Mutable runtime parameters must not modify their profile.")
	var count := first.abilities.size()
	first.register(fighter)
	first.register(fighter)
	check(first.fighters.size() == 1 and first.abilities.size() == count, "Registration must be idempotent.")
	check(component.get("seeded") == 1, "Repeated registration must preserve random state.")
	first._physics_process(0.01)
	check(component.get("steps") == 1, "A registered component must execute once per director step.")
	first.submit(component, func() -> void: resolved += 1, 0.5)
	second.register(fighter)
	check(first.fighters.is_empty() and first.abilities.is_empty() and first.pending.is_empty(), "Transfer must detach every old director reference and pending action.")
	first._physics_process(0.0)
	check(resolved == 0 and component.director == second, "Transferred contacts must not execute in their old match.")
	second.submit(component, func() -> void: resolved += 1, 0.5)
	component.queue_free()
	await process_frame
	check(second.abilities.size() == count - 1 and second.pending.is_empty(), "Removing an individual component must release its director entry and queued contact.")
	second.set_match_seed(712)
	fighter.queue_free()
	await process_frame
	check(second.fighters.is_empty() and second.abilities.is_empty() and second._slots.is_empty(), "Tree exit must release fighters, abilities and initiative slots.")
	first.queue_free()
	second.queue_free()
	await process_frame
	print("PASS: combat registration, transfer, live profile components, seeded initialization and parameter isolation" if failures.is_empty() else "FAIL: combat lifecycle")
	quit(0 if failures.is_empty() else 1)
