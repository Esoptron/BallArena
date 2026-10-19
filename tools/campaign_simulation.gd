extends SceneTree
## Actual campaign actors/World2D/director. No proxy combat or manual integrator.
var jobs: Array[Dictionary] = []
var active: Array[Dictionary] = []
var trials: Array[Dictionary] = []
var cursor := 0
var output := "res://builds/campaign-work/simulation.json"
var per_pair := 12
var base_seed := 700000
var last_report := 0
var frames := 0
var config_hashes := {}
var config_snapshot := {}
var source_hashes := {}
var hero_filter := ""
var boss_filter := ""
const BOSSES := ["bridge_guard","chain_maestro","storm_crossbow","nox","magnetic_archon"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()>0: per_pair=maxi(1,int(args[0]))
	if args.size()>1: output=args[1]
	if args.size()>2: base_seed=int(args[2])
	if args.size()>3: hero_filter=args[3]
	if args.size()>4: boss_filter=args[4]
	for hero in CampaignProgression.playable_ids():
		for boss in BOSSES:
			for sample in per_pair:
				jobs.append({"hero":hero,"enemies":[{"id":boss}],"seed":base_seed+sample*104729+hero.hash()%1009+boss.hash()%1013,"tier":sample%3,"type":"boss"})
	for hero in CampaignProgression.playable_ids():
		for level in 5:
			for sample in maxi(3,per_pair/5):
				jobs.append({"hero":hero,"enemies":CampaignLevels.encounter(level+1,9)["enemies"],"seed":base_seed+300000+sample*7919+level*101,"tier":sample%3,"type":"dual_l%d"%(level+1)})
		for level in 5:
			for battle in 9:
				jobs.append({"hero":hero,"enemies":CampaignLevels.encounter(level+1,battle+1)["enemies"],"seed":base_seed+900000+level*1009+battle*199+hero.hash()%103,"tier":mini(2,level/2),"type":"authored_l%d"%(level+1)})
	for sample in 12:
		jobs.append({"hero":"club","enemies":[{"id":"harpoon"},{"id":"cryo"}],"seed":base_seed+2000000+sample*7919,"tier":2,"rarity":3,"extra_bonuses":{"ice":1.0,"shatter":1.0},"type":"stress_club_legend"})
		jobs.append({"hero":"vampire","enemies":[{"id":"magnetic_archon"}],"seed":base_seed+3000000+sample*104729,"tier":2,"overheal":true,"type":"stress_vamp_overheal"})
	if not hero_filter.is_empty(): jobs=jobs.filter(func(job: Dictionary) -> bool: return job["hero"]==hero_filter)
	if not boss_filter.is_empty(): jobs=jobs.filter(func(job: Dictionary) -> bool: return job["type"]=="boss" and job["enemies"][0]["id"]==boss_filter)
	if jobs.is_empty(): push_error("No matching simulation jobs"); quit(1); return
	print("CAMPAIGN SIM START ",jobs.size())
	_fill()
	source_hashes=BalanceSnapshot.source_hashes()
	for name in ["progression","enemies","levels"]:
		var path := "res://scripts/campaign/data/%s.json"%name
		config_hashes[name]=FileAccess.get_sha256(path)
		config_snapshot[name]=JSON.parse_string(FileAccess.get_file_as_string(path))
	while not active.is_empty():
		await physics_frame
		frames+=1
		if frames%2400==0: print("FRAME ",frames," time ",active[0]["arena"].director.time_seconds," done ",trials.size()," active ",active.size())
		for index in range(active.size()-1,-1,-1):
			var entry := active[index]
			var arena := entry["arena"] as BallArena
			var player := arena.fighters[0] as CampaignBall
			var elapsed := arena.director.time_seconds
			if arena.director.match_over or elapsed>=90:
				var row: Dictionary=entry["metrics"]
				row.merge(entry["job"])
				row["duration"]=elapsed; row["win"]=player.current_health>0 and arena.director.match_over
				row["timeout"]=elapsed>=90 and not arena.director.match_over
				row["hp"]=CampaignUnits.unpack(player.current_health); row["enemy_hp"]=0.0
				for enemy in arena.fighters:
					if enemy!=player: row["enemy_hp"]+=CampaignUnits.unpack(enemy.current_health)
				row["winner_hp"]=row["hp"] if row["win"] else row["enemy_hp"]
				trials.append(row)
				var viewport := entry["viewport"] as SubViewport
				viewport.get_parent().remove_child(viewport); viewport.queue_free(); active.remove_at(index)
			else:
				if player.is_paralyzed(): entry["metrics"]["captured"]+=1.0/Engine.physics_ticks_per_second
				if player.is_feeding: entry["metrics"]["feeding"]+=1.0/Engine.physics_ticks_per_second
		_fill()
		if trials.size()-last_report>=100:
			last_report=trials.size(); print("CAMPAIGN SIM ",trials.size(),"/",jobs.size())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("Cannot write simulation report"); quit(1); return
	file.store_string(JSON.stringify({"engine":Engine.get_version_info()["string"],"physics_hz":Engine.physics_ticks_per_second,"base_seed":base_seed,"requested_trials":jobs.size(),"per_pair":per_pair,"hero_filter":hero_filter,"config_hashes":config_hashes,"source_hashes":source_hashes,"config":config_snapshot,"trials":trials},"\t")); file.close()
	print("CAMPAIGN SIM PASS ",trials.size()); quit(0)

func _fill() -> void:
	while active.size()<40 and cursor<jobs.size():
		var job := jobs[cursor]; cursor+=1
		var viewport := SubViewport.new(); viewport.world_2d=World2D.new(); viewport.size=Vector2i.ONE
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(viewport)
		var account := CampaignProgression.new_account()
		var hero: String = job["hero"]
		var tier: int = job["tier"]
		var ranks: Dictionary=account["heroes"][hero]["ranks"]
		for skill in CampaignProgression.data()["players"][hero]["xp_skills"]: ranks[skill]=0 if tier==0 else (2 if tier==1 else 5)
		account["heroes"][hero]["ability_rank"]=tier*2
		account["heroes"][hero]["equipped_rarity"]=job.get("rarity",tier)
		var bonuses := {} if tier==0 else {"damage":0.1*tier,"hp":0.05*tier,"spin":0.05*tier}
		bonuses.merge(job.get("extra_bonuses",{}),true)
		job["ranks"]=ranks.duplicate(true); job["cards"]=bonuses.duplicate(true); job["rarity"]=account["heroes"][hero]["equipped_rarity"]
		var lineup: Array[Dictionary]=[CampaignProfiles.hero(hero,account,bonuses)]
		for enemy in job["enemies"]: lineup.append(CampaignCatalog.enemy(enemy["id"],enemy))
		var arena := preload("res://scenes/arena.tscn").instantiate() as BallArena
		arena.set_script(preload("res://scripts/campaign/arena.gd")); arena.set("lineup",lineup)
		arena.spawn_seed=job["seed"]; arena.set("speed_variation",0.12); arena.set("presentation",false)
		if job.get("overheal",false): arena.set("carried_hp",45000); arena.set("carried_peak",60000)
		viewport.add_child(arena)
		job["scenario"]=[]
		for actor in arena.fighters:
			job["scenario"].append({"id":String(actor.character_id),"position":[actor.position.x,actor.position.y],"velocity":[actor.linear_velocity.x,actor.linear_velocity.y],"hp":CampaignUnits.unpack(actor.current_health),"diameter":actor.diameter,"mass":actor.mass})
		var metrics := {"hits":0,"bites":0,"abilities":0,"damage":0.0,"healing":0.0,"dot":0.0,"captured":0.0,"feeding":0.0,"enemy_hits":0,"enemy_damage":0.0,"ability_counts":{}}
		arena.director.event_recorded.connect(func(e: Dictionary) -> void:
			var player: bool=e["actor_id"]=="player"
			match e["kind"]:
				"hit", "projectile_hit": metrics["hits" if player else "enemy_hits"]+=1
				"damage":
					metrics["damage" if player else "enemy_damage"]+=CampaignUnits.unpack(e["amount"])
				"campaign_dot":
					if player: metrics["dot"]+=CampaignUnits.unpack(e["amount"])
				"heal":
					if player: metrics["healing"]+=CampaignUnits.unpack(e["amount"])
				"cast_started":
					if player and hero=="vampire": metrics["bites"]+=1
				"berserk_started","hunt_started","shield_started","capture_counter","magnetic_pulse","drone_summoned","critical_hit":
					metrics["abilities"]+=1
					var key: String=("player/" if player else "enemy/")+e["kind"]
					metrics["ability_counts"][key]=int(metrics["ability_counts"].get(key,0))+1
		)
		active.append({"job":job,"arena":arena,"viewport":viewport,"metrics":metrics})
