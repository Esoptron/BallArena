class_name CampaignRun
extends RefCounted
## Transactions are explicit: ready -> fighting -> reward -> ready / completed.
static func start(account: Dictionary, level: int, hero: String, seed_value: int) -> bool:
	if not account.get("active_run",{}).is_empty() or level < 1 or level > mini(5,int(account["unlocked_level"])): return false
	if not CampaignProgression.PLAYABLE.has(hero) or not account["heroes"][hero]["owned"]: return false
	account["run_serial"] = int(account.get("run_serial",0))+1
	var bonuses: Dictionary = account["next_bonus"].get(str(level),{}).duplicate(true)
	var stats := CampaignProgression.stats(hero,account,bonuses)
	var hp := CampaignUnits.pack(stats["max_hp"])
	account["active_run"]={"serial":account["run_serial"],"level":level,"battle":1,"hero":hero,"seed":seed_value,
		"hp":hp,"peak":hp,"bonuses":bonuses,"status":"ready","offer":[],"profile":account["heroes"].duplicate(true)}
	account["next_bonus"].erase(str(level))
	return true

static func profile_account(account: Dictionary) -> Dictionary:
	var result := account.duplicate(true)
	if not account.get("active_run",{}).is_empty(): result["heroes"]=account["active_run"]["profile"].duplicate(true)
	return result

static func begin(account: Dictionary) -> bool:
	var run: Dictionary = account.get("active_run",{})
	if run.get("status","") != "ready": return false
	run["status"]="fighting"
	return true

static func settle(account: Dictionary, won: bool, hp: int, peak: int, reward: Dictionary) -> bool:
	var run: Dictionary = account.get("active_run",{})
	if run.get("status","") != "fighting": return false
	if not won:
		account["active_run"]={}
		return true
	if hp <= 0 or peak <= 0: return false
	var receipt := "%s:%s:%s" % [run["serial"],run["level"],run["battle"]]
	if account["receipts"].has(receipt): return false
	account["coins"] += maxi(0,int(reward.get("coins",0)))
	account["xp"] += maxi(0,int(reward.get("xp",0)))
	account["receipts"].append(receipt)
	if account["receipts"].size() > 512: account["receipts"].pop_front()
	var snapshot := profile_account(account)
	var stats := CampaignProgression.stats(run["hero"],snapshot,run["bonuses"])
	run["peak"] = maxi(peak,CampaignUnits.pack(stats["max_hp"]))
	run["hp"] = mini(run["peak"],hp+roundi(run["peak"]*float(stats["recovery"])))
	var rng := RandomNumberGenerator.new(); rng.seed=int(run["seed"]) ^ int(run["battle"])*7919
	run["offer"] = CampaignCards.offer(run,stats,rng,int(run["battle"])==10)
	run["status"]="reward"
	if int(run["battle"]) == 10:
		if not account["boss_wins"].has(int(run["level"])): account["boss_wins"].append(int(run["level"]))
		account["unlocked_level"]=maxi(account["unlocked_level"],mini(5,int(run["level"])+1))
		if int(run["level"])==5: account["features"]["ally_slot_available"]=true
	return true

static func choose(account: Dictionary, index: int) -> bool:
	var run: Dictionary = account.get("active_run",{})
	if run.get("status","") != "reward" or index < 0 or index >= run["offer"].size(): return false
	var id: String = run["offer"][index]
	if int(run["battle"]) == 10:
		account["next_bonus"][str(int(run["level"])+1)]=CampaignCards.bonus(id)
		account["active_run"]={}
	else:
		CampaignCards.apply(run,profile_account(account),id)
		run["battle"]+=1
		run["offer"]=[]
		run["status"]="ready"
	return true
