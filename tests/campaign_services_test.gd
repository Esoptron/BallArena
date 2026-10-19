extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := preload("res://scenes/arena.tscn").instantiate() as BallArena
	arena.set_script(preload("res://scripts/campaign/arena.gd"))
	var lineup: Array[Dictionary]=[CampaignProfiles.hero("swordsman",CampaignProgression.new_account()),CampaignCatalog.enemy("spearman")]
	arena.set("lineup",lineup); arena.set("presentation",false); root.add_child(arena)
	arena.director.set_physics_process(false)
	var a := arena.fighters[0] as CampaignBall
	var b := arena.fighters[1] as CampaignBall
	a.freeze=true; b.freeze=true; a.position=Vector2(100,300); b.position=Vector2(400,300)
	var ally := CampaignProfiles.create_actor(CampaignCatalog.enemy("shield"),arena.get_node("Balls"))
	ally.position=Vector2(250,300); ally.team_id=&"blue"; ally.actor_id="ally"; ally.freeze=true; arena.director.register(ally)
	var field := arena.get_node("ProjectileField")
	var hp := b.current_health; var ally_hp := ally.current_health
	field.launch(a,Vector2.RIGHT,1000,"crossbow",1000)
	field._physics_process(0.5)
	assert(b.current_health==hp-1000 and ally.current_health==ally_hp and field.shots.is_empty())
	a.position=Vector2(900,300); b.position=Vector2(1030,300); hp=b.current_health
	field.launch(a,Vector2.RIGHT,1000,"crossbow",1000); field._physics_process(0.2)
	assert(b.current_health==hp and field.shots.is_empty())
	b.position=Vector2(500,300)
	for i in 20: field._zone(a,{"position":Vector2(500,300),"zones":1,"kind":"flask"})
	assert(field.zones.size()==1)
	assert(b.add_campaign_effect("ice",ally,0.1,1))
	assert(not ally.add_campaign_effect("ice",a,0.1,1))
	b.campaign_effects.clear()
	for i in 20: b.add_campaign_effect("cut",a,0.2,4,2)
	assert(b.campaign_effects.size()==2)
	b.campaign_effects.clear(); field.zones.clear()
	b.freeze=false; b.position=Vector2(918,555); b.movement_speed=600; b.initial_direction=Vector2(1,1); b.start_motion()
	b.arm_wall_burst(a,0.2,0.85); hp=b.current_health
	for i in 90: await physics_frame
	assert(b.current_health==hp-roundi(b.campaign_effective_max*0.2))
	assert(b.wall_burst.is_empty())
	b.arm_wall_burst(a,0.2,0.85); b.receive_weapon_impact(Vector2.LEFT,2,100)
	assert(b.wall_burst.is_empty())
	# A lethal wall hit must resolve after query flushing (freezing a body inside
	# _integrate_forces is rejected by Godot).
	a.position=Vector2(100,100)
	b.current_health=100; b.position=Vector2(850,300); b.initial_direction=Vector2.RIGHT; b.start_motion()
	b.arm_wall_burst(a,0.2,0.85)
	for i in 90: await physics_frame
	assert(b.current_health==0)
	arena.free(); await process_frame; await process_frame
	print("campaign_services_test: PASS"); quit(0)
