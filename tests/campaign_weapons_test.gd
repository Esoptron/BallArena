extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node2D.new(); root.add_child(world)
	var director := CombatDirector.new(); director.group_battle=true; world.add_child(director)
	var fighters := Node2D.new(); world.add_child(fighters)
	var player := CampaignProfiles.create_actor(CampaignProfiles.hero("swordsman",CampaignProgression.new_account()),fighters)
	player.actor_id="player"; player.team_id=&"blue"; player.position=Vector2(300,300); director.register(player)
	for id in CampaignCatalog.data():
		var profile := CampaignCatalog.enemy(id)
		check(CharacterCatalog.validation_errors(profile["definition"]).is_empty(),"valid "+id)
		var enemy := CampaignProfiles.create_actor(profile,fighters)
		enemy.actor_id=id; enemy.team_id=&"red"; enemy.position=Vector2(420,300); director.register(enemy)
		var weapon := enemy.get_node("CampaignWeapon") as CombatAbility
		check(weapon.is_enabled(),"enabled "+id)
		if weapon is SwordAbility:
			weapon.rotation=PI
			var old := player.current_health
			weapon.try_hit(player)
			check(player.current_health < old,"melee damage "+id)
			check(not weapon.try_hit(player),"contact dedup "+id)
		player.current_health=20000
		director.unregister(enemy); enemy.free()
	var spear := CampaignProfiles.create_actor(CampaignCatalog.enemy("spearman"),fighters)
	var weapon := spear.get_node("CampaignWeapon") as SwordAbility
	spear.position=Vector2(300,300); weapon.rotation=0
	player.position=Vector2(354,300); player.diameter=10
	check(not weapon.intersects_target(player,0),"spear shaft is not full damage")
	player.position=Vector2(408,300)
	check(weapon.intersects_target(player,0),"spear tip damage")
	var shield := CampaignProfiles.create_actor(CampaignCatalog.enemy("shield"),fighters)
	shield.shield_sector={"facing":Vector2.RIGHT,"reduction":0.35}
	player.position=shield.position+Vector2(100,0)
	check(shield.take_damage(1000,player)==650,"front shield")
	player.position=shield.position-Vector2(100,0)
	check(shield.take_damage(1000,player)==1000,"rear exposed")
	var field := preload("res://scripts/campaign/combat/projectiles.gd").new(); world.add_child(field); field.director=director
	check(is_equal_approx(field._entry(Vector2.ZERO,Vector2(100,0),Vector2(50,0),10),0.4),"swept projectile entry")
	check(is_equal_approx(field._wall_fraction(Vector2(950,300),Vector2(980,300)),1.0/3),"wall before target")
	world.free()
	await process_frame
	if failures.is_empty(): print("campaign_weapons_test: PASS"); quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
