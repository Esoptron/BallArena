extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	check(CharacterCatalog.ids().has("club"),"Club must be discovered by the shared catalog.")
	var arena: BallArena = load("res://scenes/arena.tscn").instantiate()
	arena.blue_character_id = &"club"
	arena.red_character_id = &"knifeman"
	arena.randomize_spawns = false
	root.add_child(arena)
	arena.director.set_physics_process(false)
	var body: ArenaBall = arena.fighters[0]
	var enemy: ArenaBall = arena.fighters[1]
	var club: ClubAbility = body.get_node("Club")
	check(body.diameter == 84 and body.current_health == 120 and body.weight_class == 4,"Club body must be 84 units, 120 HP and heaviest weight.")
	check(club.definition.weapon_weight_class == 4 and club.hit_cooldown == 3,"Weapon must be heavy with a three-second damage cooldown.")
	check(club.blade_segment(0)[0].distance_to(club.blade_segment(0)[1]) == 120 and club.weapon_radius() == 15,"Club weapon length and thickness must both scale by 1.5, without scaling the body.")
	for id in ["swordsman","knifeman","katana"]:
		var definition := CharacterCatalog.character(StringName(id))
		check(body.movement_speed < definition.movement_speed and club.base_damage > int(definition.abilities[0].parameters["base_damage"]),"Club must move slower and begin with more damage than other armed heroes.")
		check(club.spin_speed < float(definition.abilities[0].parameters["spin_speed"]),"Club must rotate slowest.")
	# The normal impulse uses both masses and preserves tangential motion.
	var responses: Array[Vector2] = []
	for category in [0,2,4]:
		enemy.weight_class = category
		enemy.movement_speed = 320
		enemy.impact_speed_loss = 0
		enemy.linear_velocity = Vector2(-320,0)
		enemy.receive_heavy_weapon_impact(Vector2.RIGHT,Vector2.ZERO,4,.65,.8)
		responses.append(enemy.linear_velocity)
	check(responses[0].x > 0 and responses[2].x < 0,"A light frontal attacker must reverse; an equally heavy one must slow while continuing forward.")
	enemy.impact_speed_loss = 0
	enemy.linear_velocity = Vector2(-32,318)
	enemy.receive_heavy_weapon_impact(Vector2.RIGHT,Vector2.ZERO,4,.65,.8)
	check(enemy.linear_velocity.y > 300 and enemy.linear_velocity.length() > responses[0].length(),"A grazing collision must retain tangential speed.")
	for tick in 110: await physics_frame
	check(enemy.impact_speed_loss == 0,"Impact deceleration must recover smoothly within the configured duration.")
	# Damage cooldown and physical club contact are independent.
	body.position = Vector2(400,300)
	enemy.position = Vector2(480,320)
	body.current_health = 120
	enemy.current_health = 1000
	club.rotation = 0
	club.cooldown_remaining = 0
	club._contact_victim = null
	check(club.try_hit(enemy),"Club must deal damage on a ready hit.")
	check(enemy.current_health == 980 and club.cooldown_remaining == 3,"Ready hit must deal 20 damage and start three seconds.")
	club._contact_victim = null
	club._body_contact_this_step = false
	club._clashed_this_step = false
	club.spin_direction = 1
	enemy.linear_velocity = Vector2(0,-320)
	club._orbit_contact(enemy,0,0)
	check(enemy.current_health == 980 and enemy.linear_velocity.y > 0,"A cooling-down club must still repel a body without dealing another hit.")
	check(club.current_damage == 25,"A ready successful hit must add five damage; cooldown contacts must add none.")
	var health := enemy.current_health
	for expected in [25,30,35,40]:
		club.cooldown_remaining = 0
		club._contact_victim = null
		check(club.try_hit(enemy),"Repeated ready club hit must succeed.")
		health -= expected
		check(enemy.current_health == health and club.current_damage == expected+5,"Club damage must keep growing beyond the former 32-damage ceiling.")
	club.reset_runtime()
	check(club.current_damage == 20,"Starting a fresh fight must reset club damage to twenty.")
	check(club.progression_stats().any(func(stat: Dictionary) -> bool: return stat["label"] == "Урон"),"Club damage growth must appear in the shared progression HUD.")
	# Guaranteed proc fixture: received hit applies, then subsequent damage is blocked.
	club.shield_chance = 1
	body.current_health = 120
	check(body.take_damage(7,enemy,&"test") == 7 and club.shield_remaining == 5 and body.is_invulnerable(),"Surviving an enemy hit may activate five seconds of absolute protection.")
	var state := club.rng.state
	check(body.take_damage(7,enemy,&"test") == 0 and club.rng.state == state,"Shield must block all later damage without rerolling or refreshing.")
	var protection := Node.new()
	root.add_child(protection)
	body.set_invulnerable(protection,true)
	body.hold_motion(club)
	club.combat_step(5)
	check(club.shield_remaining == 0 and body.is_invulnerable(),"Shield must expire while immobilized without clearing another protection source.")
	body.set_invulnerable(protection,false)
	body.release_motion(club,Vector2.RIGHT)
	protection.queue_free()
	check(not body.is_invulnerable(),"Club's protection source must be removed at expiry.")
	body.current_health = 10000
	body.take_damage(1,enemy,&"katana",false)
	check(club.shield_remaining == 0,"Periodic bleed must not count as a fresh direct enemy hit.")
	body.take_damage(1,body,&"test")
	check(club.shield_remaining == 0,"Self damage must not roll shield.")
	club.shield_chance = .05
	club.rng.seed = 59001
	var procs := 0
	for i in 1000:
		body.take_damage(1,enemy,&"sword")
		if club.shield_remaining > 0: procs += 1
		club.shield_remaining = 0
		body.set_invulnerable(club,false)
	check(procs >= 20 and procs <= 85,"One thousand seeded incoming hits must approximate five-percent shield chance.")
	# A multi-tick vampire bite is one fresh hit for reactive shields.
	CharacterCatalog.apply(enemy,CharacterCatalog.character(&"vampire"),70)
	var fangs: VampireFangs = enemy.get_node("Vampire")
	club.shield_chance = .000001
	club.rng.seed = 12
	body.position = Vector2(480,300)
	enemy.position = Vector2(400,300)
	body.capture_immunity_remaining = 0
	check(fangs.try_bite(body),"Shield scheduling fixture must begin a bite.")
	fangs._bite_tick()
	check(club.shield_remaining == 0,"Seeded first bite unit must not trigger this rare shield fixture.")
	state = club.rng.state
	for tick in 14: fangs._bite_tick()
	check(club.rng.state == state,"The remaining fourteen drain units must not reroll a reactive shield.")
	club.shield_chance = 1
	body.take_damage(1,enemy,&"test")
	CharacterCatalog.apply(body,CharacterCatalog.character(&"ordinary"),70)
	check(not body.is_invulnerable(),"Switching character must clear its old club shield.")
	# All catalog weapons use the same cooldown indication, including vampire teeth.
	for id in CharacterCatalog.ids():
		CharacterCatalog.apply(body,CharacterCatalog.character(StringName(id)),70)
		var indicator := body.get_node("CooldownIndicator")
		var active: CombatAbility
		for ability in body.combat_components:
			if ability.is_enabled(): active = ability
		if active == null:
			indicator.call("_process",.5)
			check(not indicator.visible,"Unarmed hero must not display a loading icon.")
			continue
		active.set("cooldown_remaining",1.0)
		indicator.call("_process",.5)
		check(indicator.visible and active.cooldown_visual().self_modulate.a < 1,"Every cooling-down weapon must pulse and show a loading icon.")
		active.set("cooldown_remaining",0.0)
		indicator.call("_process",.1)
		check(not indicator.visible and active.cooldown_visual().self_modulate.a == 1,"Cooldown expiry must restore full weapon opacity and hide loading.")
	arena.queue_free()
	await process_frame
	print("Club profiles, weighted momentum, cooldown contacts, shields (",procs,"/1000), shared recharge UI: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
