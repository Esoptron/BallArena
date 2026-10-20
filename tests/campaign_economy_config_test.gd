extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var total := 0
	for level in range(1,11):
		var sum := 0
		for wave in range(1,11): sum+=CampaignEconomy.wave_gold(level,wave)
		assert(sum==CampaignEconomy.data()["gold_by_level"][level-1]); total+=sum
	assert(total==3000)
	assert(CampaignEconomy.chest_type(10,0)=="epic")
	assert(CampaignEconomy.chest_type(5,0)=="rare")
	for wins in range(1,5): assert(CampaignEconomy.chest_type(10,wins)=="common")
	assert(CampaignEconomy.reward_half_units(0)==2 and CampaignEconomy.reward_half_units(1)==2 and CampaignEconomy.reward_half_units(2)==1)
	assert(CampaignEconomy.rarity("katana")=="rare" and CampaignEconomy.prices("club")["coins"]==20000 and CampaignEconomy.prices("club")["crystals"]==100)
	assert(CampaignEconomy.text(1)=="0.5" and CampaignEconomy.text(2)=="1")
	var account := {"coins":0}
	CampaignEconomy.credit(account,"coins",1); assert(CampaignEconomy.wallet_units(account,"coins")==1)
	CampaignEconomy.credit(account,"coins",3); assert(account["coins"]==1 and account["coins_quarters"]==0)
	print("campaign_economy_config_test: PASS"); quit(0)
