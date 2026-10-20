extends SceneTree
## Statistical checks use held-out seeds, not combat tuning or drop-rate adjustment.
func _initialize() -> void: call_deferred("run")
func close_to(actual: float, expected: float, samples: int) -> void:
	assert(absf(actual-expected)<6.0*sqrt(expected*(1.0-expected)/samples)+0.001,"Observed %.4f; expected %.4f"%[actual,expected])
func count_units(cards: Dictionary) -> int:
	var total := 0
	for value in cards.values(): total+=int(value)
	return total
func run() -> void:
	var a := CampaignProgression.new_account()
	var report := {"samples_per_chest":60000,"chests":{},"character_rarity":{},"weapon_active":[]}
	var samples := int(report["samples_per_chest"])
	for kind in ["common","rare","epic"]:
		var run_state := {"level":1,"battle":1,"serial":1,"seed":806317,"hero":"swordsman","chest":kind,"reward_half_units":2,"loot":CampaignEconomy.empty_loot()}
		var both := 0
		for index in samples:
			run_state["serial"]=index+1; run_state["battle"]=index%10+1
			var character_before := count_units(run_state["loot"]["characters"])
			var weapon_before := count_units(run_state["loot"]["weapons"])
			CampaignEconomy.roll_wave(a,run_state,{"xp":1})
			if count_units(run_state["loot"]["characters"])>character_before and count_units(run_state["loot"]["weapons"])>weapon_before: both+=1
		var character_rate := float(count_units(run_state["loot"]["characters"]))/2/samples
		var weapon_rate := float(count_units(run_state["loot"]["weapons"]))/2/samples
		var expected: Dictionary=CampaignEconomy.data()["chests"][kind]
		close_to(character_rate,expected["character_chance"],samples)
		close_to(weapon_rate,expected["weapon_chance"],samples)
		close_to(float(both)/samples,float(expected["character_chance"])*float(expected["weapon_chance"]),samples)
		assert(run_state["loot"]["weapons"].keys()==["swordsman"])
		report["chests"][kind]={"character_rate":character_rate,"weapon_rate":weapon_rate,"both_rate":float(both)/samples}
	var rng := RandomNumberGenerator.new(); rng.seed=2097593
	var counts := {"common":0,"rare":0,"epic":0}
	for index in samples:
		var target := CampaignEconomy.character_target(rng)
		assert(not target["id"].is_empty())
		counts[target["rarity"]]+=1
	for kind in counts:
		close_to(float(counts[kind])/samples,float(CampaignEconomy.data()["character_rarity_weights"][kind])/100,samples)
		report["character_rarity"][kind]=float(counts[kind])/samples
	for stage in 7:
		a["heroes"]["swordsman"]["weapon_stage"]=stage
		var active := 0
		for index in samples:
			var target := CampaignEconomy.weapon_target(a,"swordsman",rng)
			if target=="swordsman": active+=1
			else: assert(not target.is_empty()) # Locked heroes are eligible.
		close_to(float(active)/samples,CampaignEconomy.data()["weapon_active_chances"][stage],samples)
		report["weapon_active"].append(float(active)/samples)
	for id in a["heroes"]: a["heroes"][id]["weapon_stage"]=6
	assert(CampaignEconomy.weapon_target(a,"swordsman",rng).is_empty())
	# No reroll when a rarity has no real catalog entries.
	var original := CampaignEconomy.data().duplicate(true)
	CampaignEconomy._data["character_rarity_weights"]={"epic":100}
	CampaignEconomy._data["hero_catalog"]["club"]["rarity"]="common"
	var missing := CampaignEconomy.character_target(rng)
	assert(missing["rarity"]=="epic" and missing["id"].is_empty())
	CampaignEconomy._data=original
	var file := FileAccess.open("res://builds/campaign-work/economy-v1-distribution.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("campaign_economy_distribution_test: PASS"); quit(0)
