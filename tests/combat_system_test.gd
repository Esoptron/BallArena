extends SceneTree
const ARENA := preload("res://scenes/arena.tscn")
const BALL := preload("res://scenes/ball.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var baseline := CharacterCatalog.character(&"swordsman")
	var baseline_damage: int = baseline.abilities[0].parameters["base_damage"]
	var variant := CharacterCatalog.character(&"swordsman",{"abilities":{"sword":{"base_damage":19}}})
	check(variant.abilities[0].parameters["base_damage"] == 19
		and baseline.abilities[0].parameters["base_damage"] == baseline_damage,
		"Profile overrides must not mutate the shared catalog.")
	var arena := ARENA.instantiate() as BallArena
	arena.randomize_spawns = false
	arena.blue_character = 0
	root.add_child(arena)
	var blue := arena.get_node("Balls/BlueBall") as ArenaBall
	var red := arena.get_node("Balls/RedBall") as ArenaBall
	var fangs := red.get_node("Vampire") as VampireFangs
	fangs.set_physics_process(false)
	fangs.call("_update_mist")
	check(not (fangs.get("_mist") as Polygon2D).visible,"Ready vampire must have no aura at match start.")
	blue.freeze = true
	red.freeze = true
	blue.position = Vector2(400,300)
	red.position = Vector2(500,300)
	fangs.aim_at_opponent()
	check(not fangs.tooth_contact(blue),"Distance 100 must not substitute for actual tooth contact.")
	red.position = Vector2(480,300)
	check(fangs.tooth_contact(blue),"Long tooth tips must contact a 70-unit target near distance 80.")
	check(fangs.try_bite(blue),"Bite fixture must start.")
	fangs.combat_step(fangs.bite_duration/fangs.bite_units)
	arena.director._physics_process(0.0)
	check(blue.current_health == 99,"First bite damage unit must arrive at the configured interval.")
	fangs.call("_finish_bite")
	check(not blue.is_immobilized() or blue.is_paralyzed(),"Ending a bite must release its motion hold.")
	check(blue.capture_immunity_remaining > 0 and blue.attack_recovery_remaining == 0,
		"Release must grant control immunity without blocking attacks.")
	fangs.call("_update_mist")
	check((fangs.get("_mist") as Polygon2D).visible,"Existing mist must return during bite cooldown.")
	var elapsed := fangs.cooldown_remaining
	fangs.combat_step(elapsed-0.1)
	check(fangs.cooldown_remaining > 0 and fangs.cooldown_remaining < elapsed,
		"Configured cooldown must count from release.")
	fangs.combat_step(0.2)
	fangs.call("_update_mist")
	check(not (fangs.get("_mist") as Polygon2D).visible,"Cooldown mist must disappear when a used bite is ready.")
	var quiet_profile := CharacterDefinition.new()
	quiet_profile.character_id = &"quiet_vampire"
	quiet_profile.tags = PackedStringArray(["vampire"])
	CharacterCatalog.apply(blue,quiet_profile,70)
	var disabled_bite := blue.get_node("Vampire") as VampireFangs
	check(not disabled_bite.is_enabled() and not disabled_bite.try_bite(red),
		"A visual tag must not activate an ability missing from the central profile.")
	arena.queue_free()
	await process_frame
	# A never-before-seen component must work with the same factory and collector.
	var probe := BALL.instantiate() as ArenaBall
	probe.actor_id = "probe"
	root.add_child(probe)
	var ability := AbilityDefinition.new()
	ability.ability_id = &"probe_heal"
	ability.node_name = &"Probe"
	ability.implementation = preload("res://tests/fixtures/probe_ability.gd")
	ability.parameters = {"pulse_heal":2}
	var definition := CharacterDefinition.new()
	definition.character_id = &"probe"
	definition.abilities = [ability]
	CharacterCatalog.apply(probe,definition,70)
	check(probe.get_node("Probe").get("initialized_heal") == 2,
		"New components must receive profile parameters before initializing their nodes.")
	var director := CombatDirector.new()
	root.add_child(director)
	director.register(probe)
	var metrics := CombatMetrics.new()
	var actors: Array[ArenaBall] = [probe]
	metrics.attach(actors,director)
	await physics_frame
	await physics_frame
	await physics_frame
	check(probe.current_health == 102 and metrics.participants["probe"]["healing"] == 2
		and probe.get_node("Probe").get("healing_observed") == 2,
		"New ability must heal above base HP and automatically appear in generic metrics.")
	probe.current_health = 0
	var outcome := metrics.finish(actors,1.0,false)
	check(outcome["winner_role"] == "", "Defeated last actor must not be recorded as winner.")
	metrics.observe({"actor_id":"probe","target_id":"probe","ability_id":"probe_heal","time":1.0,"kind":"cast_started"})
	metrics.observe({"actor_id":"probe","target_id":"probe","ability_id":"probe_heal","time":1.1,"kind":"hit"})
	check(metrics.participants["probe"]["abilities"]["probe_heal"]["successes"] == 1,
		"A final lethal hit must count as a successful cast before its animation ends.")
	probe.queue_free()
	director.queue_free()
	await process_frame
	# Identical characters still need distinct winning roles; censored trials are not wins.
	var alive := ArenaBall.new()
	var dead := ArenaBall.new()
	alive.actor_id = "a"; alive.battle_role = "left"; alive.character_id = &"ordinary"
	dead.actor_id = "b"; dead.battle_role = "right"; dead.character_id = &"ordinary"
	alive.current_health = 100; dead.current_health = 0
	var mirror_metrics := CombatMetrics.new()
	var mirror_actors: Array[ArenaBall] = [alive,dead]
	var mirror_director := CombatDirector.new()
	mirror_metrics.attach(mirror_actors,mirror_director)
	var mirror_row := mirror_metrics.finish(mirror_actors,25.0,false)
	check(mirror_row["winner_actor_id"] == "a" and mirror_row["winner_role"] == "left",
		"A dead final participant must not overwrite the mirror match winner.")
	var stats := CombatStatistics.summarize([mirror_row])
	check(stats["wins"]["left"] == 1 and stats["mean_completed"] == 25.0,
		"Generic statistics must use role identity in mirror matches.")
	mirror_row["timeout"] = true; mirror_row["winner_role"] = ""
	stats = CombatStatistics.summarize([mirror_row])
	check(stats["timeouts"] == 1 and stats["mean_completed"] == null,
		"Censored bouts must not be included in completed duration means or wins.")
	mirror_director.free(); alive.free(); dead.free()
	if failures.is_empty():
		print("PASS: immutable central profiles; real tooth geometry; cooldown aura; release rules; generic future ability and metrics")
		quit(0)
	else:
		quit(1)
