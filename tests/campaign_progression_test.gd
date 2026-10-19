extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var account := CampaignProgression.new_account()
	var original := BalanceSnapshot.describe(&"swordsman", {})
	var sword := CampaignProgression.stats("swordsman", account)
	check(sword["max_hp"] == 20.0 and sword["damage"] == 3.0 and sword["spin"] == 6.0 and sword["weapon_length"] == 40.0, "Campaign sword retains its profile with the revised weapon tempo.")
	check(sword["speed"]==320.0,"Campaign movement returns to the original readable speed.")
	var spear := CampaignCatalog.enemy("spearman")["definition"] as CharacterDefinition
	check(spear.movement_speed==290.0 and is_equal_approx(spear.abilities[0].parameters["spin_speed"],4.95),"Enemy movement and weapon rotation use independent tempo controls.")
	var knives := CampaignProfiles.hero("knifeman",account)["definition"] as CharacterDefinition
	check(is_equal_approx(knives.abilities[0].parameters["spin_speed"],4.8) and knives.abilities[0].parameters["spin_gain"]==4.5 and knives.abilities[0].parameters["max_spin_speed"]==48.0,"Knife starting rotation, hit growth and cap scale together.")
	check(not CampaignProgression.buy_hero(account, "ordinary"), "Unarmed training ball must not be sold.")
	account["xp"] = 1000
	account["coins"] = 1000
	check(CampaignProgression.buy_hero(account, "knifeman"), "Shop must spend coins and unlock a hero.")
	var old_price := CampaignProgression.xp_cost(account, "knifeman", "hp")
	check(CampaignProgression.upgrade(account, "knifeman", "hp"), "Shared XP can train a newly acquired hero.")
	check(CampaignProgression.rank(account, "swordsman", "hp") == 0 and CampaignProgression.stats("knifeman", account)["max_hp"] == 17.0, "Individual improvements must not upgrade the whole account.")
	check(CampaignProgression.xp_cost(account, "knifeman", "hp") > old_price, "Rank cost must increase.")
	var merge_account := CampaignProgression.new_account()
	merge_account["heroes"]["swordsman"]["weapon_cards"][0] = 27
	for tier in 3:
		while int(merge_account["heroes"]["swordsman"]["weapon_cards"][tier]) >= 3:
			check(CampaignProgression.merge(merge_account, "swordsman", tier), "A valid triple must merge.")
	check(merge_account["heroes"]["swordsman"]["weapon_cards"] == [0, 0, 0, 1], "27 ordinary cards must become exactly one legendary weapon.")
	check(CampaignProgression.stats("swordsman", merge_account)["weapon_length"] == 80.0, "Legendary must restore full geometry length.")
	check(CampaignProgression.stats("swordsman", merge_account)["damage"] == 3.0, "Rarity must not multiply damage.")
	var fang_range: float = CampaignProgression.stats("vampire", account)["weapon_length"]
	for tier in 4:
		account["heroes"]["vampire"]["equipped_rarity"] = tier
		check(is_equal_approx(CampaignProgression.stats("vampire", account)["weapon_length"], fang_range), "Latest user exception: vampire range stays unchanged at every rarity.")
	check(CampaignProgression.stats("swordsman", account, {"chance": 0.1})["chance"] > 0.1, "Legendary temporary chance must not be clipped by the permanent training cap.")
	for id in CampaignProgression.playable_ids():
		var compiled := CampaignProfiles.hero(id, account)
		check(CharacterCatalog.validation_errors(compiled["definition"]).is_empty(), "Every compiled campaign profile must satisfy the existing combat contract: " + id)
	check(BalanceSnapshot.describe(&"swordsman", {}) == original, "Campaign calculations must never mutate free-battle templates.")
	var pair := Node2D.new()
	root.add_child(pair)
	var vampire := CampaignProfiles.create_actor(CampaignProfiles.hero("vampire", account), pair)
	var victim := CampaignProfiles.create_actor(CampaignProfiles.hero("swordsman", account), pair)
	vampire.opponent = victim
	victim.opponent = vampire
	vampire.set_physics_process(false)
	victim.set_physics_process(false)
	for actor in [vampire, victim]:
		for ability in actor.combat_components:
			ability.set_physics_process(false)
	var bite := vampire.get_node("Vampire") as VampireFangs
	check(bite.try_bite(victim), "Campaign bite fixture must start.")
	for tick in 15:
		bite._bite_tick()
	check(victim.current_health == 16000 and vampire.current_health == 22000, "Fifteen distributed ticks must total 4 damage and 2 healing after the balance pilot.")
	check(bite.get("campaign_damage") == 4750 and bite.get("campaign_healing") == 2300, "Growth must apply once per completed bite, not fifteen times.")
	vampire.heal(5000)
	vampire.take_damage(12000, victim)
	check(vampire.current_health == 15000 and vampire.campaign_effective_max == 27000, "Vampire peak max persists after receiving damage.")
	vampire.heal(roundi(vampire.campaign_effective_max * 0.05))
	check(vampire.current_health == 16350 and CampaignUnits.text(vampire.current_health) == "16.35", "Recovery must use dynamic 27 HP maximum and preserve fractions.")
	bite.reset_runtime()
	vampire.current_health = 20000
	vampire.take_damage(19000, victim)
	check(bite.hunt_pending, "Campaign hunt threshold includes exactly 1 HP at the starting 5% threshold.")
	victim.current_health = 20000
	check(victim.heal(1000) == 0, "Non-vampire campaign healing must respect the calculated maximum.")
	victim.add_campaign_effect("ice", vampire, 0.15, 0.2)
	victim._advance_campaign_effects(0.2)
	victim._advance_campaign_effects(0.01)
	check(victim.rotation_multiplier == 1.0, "Expired slows must restore the multiplier without a permanent residual.")
	var veteran_account := account.duplicate(true)
	veteran_account["heroes"]["katana"]["ranks"]["damage"]=250
	var veteran := CampaignProfiles.create_actor(CampaignProfiles.hero("katana",veteran_account),pair)
	victim.current_health=1000000
	var blade := veteran.get_node("Katana") as SwordAbility
	var before := blade.current_damage
	check(blade.try_hit(victim) and blade.current_damage>before,"Permanent damage beyond old free-battle caps must never decrease after the first hit.")
	pair.queue_free()
	await process_frame
	print("PASS: isolated campaign progression, fixed-point HP, merge, bite totals, hunt and status expiry" if failures.is_empty() else "FAIL: campaign progression")
	quit(0 if failures.is_empty() else 1)
