extends BallArena
signal campaign_finished(won: bool, hp: int, peak: int)
var lineup: Array[Dictionary] = []
var carried_hp := -1
var carried_peak := -1
var speed_variation := 0.0
var presentation := true
var _spawn_rng := RandomNumberGenerator.new()

func _ready() -> void:
	for child in $Balls.get_children():
		$Balls.remove_child(child); child.free()
	_create_walls()
	director=CombatDirector.new(); director.group_battle=true; add_child(director)
	death_fragments=ArenaDeathFragments.new(); death_fragments.portrait_factory=CampaignProfiles.empty_actor; add_child(death_fragments)
	$CombatEffects.number_layer.set_script(preload("res://scripts/campaign/combat/numbers.gd"))
	$BloodEffects.floor_y=arena_size.y; $BloodEffects.arena_width=arena_size.x
	var field := preload("res://scripts/campaign/combat/projectiles.gd").new()
	field.name="ProjectileField"; field.director=director; add_child(field)
	if presentation:
		var audio := preload("res://scripts/campaign/combat/audio.gd").new(); audio.name="CampaignAudio"; add_child(audio)
	_spawn_rng.seed=spawn_seed if spawn_seed!=0 else 1
	resolved_seed=_spawn_rng.seed
	for i in lineup.size():
		var actor := CampaignProfiles.create_actor(lineup[i],$Balls,carried_hp if i==0 else -1,carried_peak if i==0 else -1)
		_setup(actor,i)
		if i==0 and not actor.campaign_bonuses.is_empty():
			var enchantment := preload("res://scripts/campaign/combat/enchantments.gd").new()
			enchantment.actor=actor; enchantment.director=director; add_child(enchantment)
	director.set_match_seed(resolved_seed); director.refresh_targets()
	director.match_finished.connect(_finished)
	_configure_physics_rate()
	if not presentation:
		$BloodEffects.set_process(false); $CombatEffects.set_process(false)
		for actor in fighters:
			actor.blood_effects=null; actor.combat_effects=null
			actor.set_process(false)
			for child in actor.get_children(): child.set_process(false)

func _setup(actor: CampaignBall, index: int) -> void:
	actor.actor_id="player" if index==0 else "enemy_%d"%index
	actor.team_id=&"blue" if index==0 else &"red"
	actor.battle_role=String(actor.team_id)
	actor.ball_color=preload("res://scripts/campaign/combat/boss_art.gd").colour(actor.character_id,Color("2c81ff") if index==0 else Color("ff293b"))
	if presentation: preload("res://scripts/campaign/combat/boss_art.gd").attach(actor,actor.character_id)
	actor.blood_effects=$BloodEffects if presentation else null
	actor.combat_effects=$CombatEffects if presentation else null
	actor.health_delta.connect(_show_combat_number.bind(actor))
	var margin := actor.diameter*0.5+4
	actor.position=Vector2(margin,margin)
	for attempt in 100:
		var point := Vector2(_spawn_rng.randf_range(margin,arena_size.x-margin),_spawn_rng.randf_range(margin,arena_size.y-margin))
		var clear := true
		for other in fighters:
			if point.distance_to(other.position)<(actor.diameter+other.diameter)*0.5+55: clear=false; break
		if clear: actor.position=point; break
	actor.initial_direction=Vector2.from_angle(_spawn_rng.randf_range(-PI,PI))
	actor.movement_speed *= 1+_spawn_rng.randf_range(-speed_variation,speed_variation)
	actor.start_motion()
	fighters.append(actor); director.register(actor)
	if presentation: death_fragments.watch(actor)

func summon_drone(owner: ArenaBall) -> void:
	for actor in fighters:
		if actor!=owner and actor.team_id==&"red" and actor.current_health>0: return
	var drone := CampaignProfiles.create_actor(CampaignCatalog.enemy("magnet",{"hp":15,"damage":1,"size":0.65,"speed":310}),$Balls)
	_setup(drone,fighters.size())
	var direction := (owner.position-arena_size*0.5).normalized()
	drone.position=(owner.position-direction*(owner.diameter+drone.diameter)).clamp(Vector2.ONE*32,arena_size-Vector2.ONE*32)
	owner.combat_event(&"drone_summoned",drone,&"magnet")
	director.refresh_targets()

func _finished(team: StringName) -> void:
	director.set_physics_process(false)
	for actor in fighters:
		actor.freeze=true
		actor.set_physics_process(false)
	var player := fighters[0] as CampaignBall
	campaign_finished.emit(team==&"blue",player.current_health,player.campaign_effective_max)
