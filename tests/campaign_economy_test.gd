extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var account := CampaignProgression.new_account()
	account["coins"]=5000; account["xp"]=100000
	for id in CampaignProgression.playable_ids():
		if id!="swordsman": assert(CampaignProgression.buy_hero(account,id))
		assert(not CampaignProgression.buy_hero(account,id))
		for skill in CampaignProgression.data()["players"][id]["xp_skills"]:
			var before := CampaignProgression.stats(id,account)
			var price := CampaignProgression.xp_cost(account,id,skill)
			var wallet: int=account["xp"]
			assert(CampaignProgression.upgrade(account,id,skill))
			assert(account["xp"]==wallet-price)
			var after := CampaignProgression.stats(id,account)
			var key: String={"hp":"max_hp"}.get(skill,skill)
			assert(after[key]>before[key])
	for i in 9: assert(CampaignProgression.upgrade(account,"swordsman","recovery"))
	assert(is_equal_approx(CampaignProgression.stats("swordsman",account)["recovery"],0.25))
	assert(not CampaignProgression.upgrade(account,"swordsman","recovery"))
	account["heroes"]["swordsman"]["ranks"]["spin"]=11
	assert(CampaignProgression.stats("swordsman",account)["spin"]>8.0)
	account["heroes"]["club"]["weapon_cards"]=[27,0,0,0]
	for i in 9: assert(CampaignProgression.merge(account,"club",0))
	for i in 3: assert(CampaignProgression.merge(account,"club",1))
	assert(CampaignProgression.merge(account,"club",2))
	assert(is_equal_approx(CampaignProgression.stats("club",account)["weapon_length"],120))
	assert(CampaignSave.validate(account).is_empty())
	var reach: float=CampaignProgression.stats("vampire",account)["weapon_length"]
	account["heroes"]["vampire"]["weapon_cards"]=[3,0,0,0]
	assert(CampaignProgression.merge(account,"vampire",0))
	assert(CampaignProgression.stats("vampire",account)["rarity"]==1)
	assert(CampaignProgression.stats("vampire",account)["weapon_length"]==reach)
	print("campaign_economy_test: PASS"); quit(0)
