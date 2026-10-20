extends SceneTree
func _initialize() -> void: call_deferred("run")
func win_wave(a: Dictionary) -> void:
	assert(CampaignRun.begin(a))
	assert(CampaignRun.settle(a,true,20000,20000,{}))
	assert(CampaignSave.validate(a).is_empty())
	assert(not CampaignRun.settle(a,true,20000,20000,{}))
func run() -> void:
	var a := CampaignProgression.new_account()
	for repetition in 3:
		var gold_before := CampaignEconomy.wallet_units(a,"coins")
		var xp_before := CampaignEconomy.wallet_units(a,"xp")
		assert(CampaignRun.start(a,1,"swordsman",100+repetition))
		for wave in 10:
			win_wave(a)
			if wave<9:
				assert(CampaignEconomy.wallet_units(a,"coins")==gold_before)
				assert(CampaignEconomy.wallet_units(a,"xp")==xp_before)
			assert(CampaignRun.choose(a,0))
		assert(CampaignEconomy.wallet_units(a,"coins")-gold_before==480 if repetition<2 else CampaignEconomy.wallet_units(a,"coins")-gold_before==240)
		assert(CampaignEconomy.wallet_units(a,"xp")-xp_before==300 if repetition<2 else CampaignEconomy.wallet_units(a,"xp")-xp_before==150)
		assert(CampaignEconomy.completions(a,1)==repetition+1)
	var coins := CampaignEconomy.wallet_units(a,"coins")
	var xp := CampaignEconomy.wallet_units(a,"xp")
	assert(CampaignRun.start(a,1,"swordsman",55)); win_wave(a)
	# Explicitly generated pending cards must all be lost on defeat.
	a["active_run"]["loot"]["weapons"]={"katana":1}
	a["active_run"]["loot"]["characters"]={"club":2}
	assert(CampaignRun.choose(a,0)); assert(CampaignRun.begin(a))
	assert(CampaignRun.settle(a,false,0,20000,{}))
	assert(CampaignEconomy.wallet_units(a,"coins")==coins+10)
	assert(CampaignEconomy.wallet_units(a,"xp")==xp+8)
	assert(not a["heroes"]["club"]["owned"] and a["heroes"]["katana"]["weapon_cards"][0]==2)
	assert(a["last_result"]["awarded"]["characters"].is_empty() and CampaignEconomy.completions(a,1)==3)
	assert(CampaignSave.validate(a).is_empty())
	var path := "res://builds/campaign-work/economy-v1-save-%d.json"%Time.get_ticks_usec()
	assert(CampaignSave.write(a,path)==OK)
	var restored := CampaignSave.load_account(path)["account"] as Dictionary
	assert(CampaignEconomy.wallet_units(restored,"xp")==CampaignEconomy.wallet_units(a,"xp"))
	var h: Dictionary=a["heroes"]["katana"]
	CampaignProgression.add_character_cards(a,"katana",1); assert(not h["owned"])
	CampaignProgression.add_character_cards(a,"katana",1); assert(h["owned"] and h["evolution"]["card_units"]==0)
	CampaignProgression.add_character_cards(a,"katana",5); assert(not CampaignProgression.evolution_ready(a,"katana"))
	CampaignProgression.add_character_cards(a,"katana",1); assert(CampaignProgression.evolution_ready(a,"katana"))
	h["weapon_cards"]=[128,0,0,0,0,0,0]
	for tier in 6:
		while h["weapon_cards"][tier]>=4: assert(CampaignProgression.merge(a,"katana",tier))
	assert(h["weapon_stage"]==6 and h["weapon_cards"][6]==2)
	assert(CampaignProgression.stats("katana",a)["length_factor"]==1.1)
	assert(not CampaignProgression.merge(a,"katana",6))
	var legacy := CampaignProgression.new_account(); legacy["schema"]=2
	for id in legacy["heroes"]:
		legacy["heroes"][id]["weapon_cards"]=[1,0,0,1]
		legacy["heroes"][id]["equipped_rarity"]=3
		legacy["heroes"][id]["evolution"]["character_cards"]=2
	legacy["coins"]=123; legacy["boss_wins"]=[1,2]
	var migrated := CampaignSave.migrate(legacy)
	assert(not migrated.is_empty() and migrated["coins"]==123 and migrated["heroes"]["swordsman"]["weapon_stage"]==5)
	assert(migrated["heroes"]["swordsman"]["evolution"]["card_units"]==4 and CampaignEconomy.completions(migrated,2)==1)
	assert(CampaignSave.validate(migrated).is_empty())
	legacy["heroes"]["swordsman"]["weapon_cards"]=[-1,0,0,0]
	assert(CampaignSave.migrate(legacy).is_empty())
	print("campaign_rewards_v1_test: PASS"); quit(0)
