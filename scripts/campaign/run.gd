class_name CampaignRun
extends RefCounted
## Transactions are explicit: ready -> fighting -> reward -> ready / completed.
static func start(account: Dictionary, level: int, hero: String, seed_value: int) -> bool:
	if not account.get("active_run",{}).is_empty() or level < 1 or level > mini(5,int(account["unlocked_level"])): return false
	if not CampaignProgression.playable_ids().has(hero) or not account["heroes"][hero]["owned"]: return false
	var bonuses: Dictionary = account["next_bonus"].get(str(level),{}).duplicate(true)
	var stats := CampaignProgression.stats(hero,account,bonuses)
	var hp := CampaignUnits.pack(stats["max_hp"])
	var ally := {}
	var ally_id: String=account.get("selected_ally","")
	if not ally_id.is_empty():
		if not account["features"]["ally_slot_owned"] or not account["heroes"].has(ally_id) or not account["heroes"][ally_id]["owned"]: return false
		var ally_hp := CampaignUnits.pack(CampaignProgression.stats(ally_id,account)["max_hp"])
		ally={"hero":ally_id,"hp":ally_hp,"peak":ally_hp}
	account["run_serial"] = int(account.get("run_serial",0))+1
	account["active_run"]={"serial":account["run_serial"],"level":level,"battle":1,"hero":hero,"seed":seed_value,
		"hp":hp,"peak":hp,"bonuses":bonuses,"status":"ready","offer":[],"profile":account["heroes"].duplicate(true),
		"ally":ally,
		"chest":CampaignEconomy.chest_type(level,CampaignEconomy.completions(account,level)),
		"reward_half_units":CampaignEconomy.reward_half_units(CampaignEconomy.completions(account,level)),"loot":CampaignEconomy.empty_loot()}
	account["next_bonus"].erase(str(level))
	return true

static func profile_account(account: Dictionary) -> Dictionary:
	var result := account.duplicate(true)
	if not account.get("active_run",{}).is_empty(): result["heroes"]=account["active_run"]["profile"].duplicate(true)
	return result

static func begin(account: Dictionary) -> bool:
	var run: Dictionary = account.get("active_run",{})
	if run.get("status","") != "ready": return false
	if int(run["loot"]["waves"])+int(run.get("legacy_paid_waves",0))!=int(run["battle"])-1: return false
	run["status"]="fighting"
	return true

static func settle(account: Dictionary, won: bool, hp: int, peak: int, _reward: Dictionary, ally_state: Dictionary = {}) -> bool:
	var run: Dictionary = account.get("active_run",{})
	if run.get("status","") != "fighting": return false
	if int(run["loot"]["waves"])+int(run.get("legacy_paid_waves",0))!=int(run["battle"])-1: return false
	if not won:
		_close(account,false)
		account["active_run"]={}
		return true
	var ally: Dictionary=run.get("ally",{})
	if hp<0 or peak<=0: return false
	if int(run["hp"])==0 and hp>0: return false
	if ally.is_empty():
		if hp==0: return false
	else:
		if not CampaignSave._integer(ally_state.get("hp"),0) or not CampaignSave._integer(ally_state.get("peak"),1): return false
		if int(ally_state["peak"])<int(ally_state["hp"]) or (hp==0 and int(ally_state["hp"])==0): return false
		if int(ally["hp"])==0 and int(ally_state["hp"])>0: return false
	var receipt := "%d:%d:%d" % [run["serial"],run["level"],run["battle"]]
	if account["receipts"].has(receipt): return false
	# Only the authoritative authored wave supplies XP; callers cannot mint rewards.
	var authored := CampaignLevels.encounter(int(run["level"]),int(run["battle"]))["reward"] as Dictionary
	CampaignEconomy.roll_wave(account,run,authored)
	account["receipts"].append(receipt)
	if account["receipts"].size() > 512: account["receipts"].pop_front()
	var snapshot := profile_account(account)
	var stats := CampaignProgression.stats(run["hero"],snapshot,run["bonuses"])
	run["peak"] = maxi(peak,CampaignUnits.pack(stats["max_hp"]))
	run["hp"] = mini(run["peak"],hp+roundi(run["peak"]*float(stats["recovery"]))) if hp>0 else 0
	if not ally.is_empty():
		var ally_stats := CampaignProgression.stats(ally["hero"],snapshot)
		ally["peak"]=maxi(int(ally_state["peak"]),CampaignUnits.pack(ally_stats["max_hp"]))
		ally["hp"]=mini(int(ally["peak"]),int(ally_state["hp"])+roundi(int(ally["peak"])*float(ally_stats["recovery"]))) if int(ally_state["hp"])>0 else 0
	var rng := RandomNumberGenerator.new(); rng.seed=int(run["seed"]) ^ int(run["battle"])*7919
	var after_boss := int(run["battle"])==10
	var offer_stats := CampaignProgression.stats(run["hero"],snapshot) if after_boss else stats
	run["offer"] = CampaignCards.offer(run,offer_stats,rng,after_boss)
	run["status"]="reward"
	if int(run["battle"]) == 10:
		_close(account,true)
		if not account["boss_wins"].has(int(run["level"])): account["boss_wins"].append(int(run["level"]))
		account["unlocked_level"]=maxi(account["unlocked_level"],mini(5,int(run["level"])+1))
		if int(run["level"])==5: account["features"]["ally_slot_available"]=true
	return true

static func _close(account: Dictionary, won: bool) -> void:
	var run: Dictionary=account["active_run"]
	var loot: Dictionary=run["loot"]
	var awarded: Dictionary=loot.duplicate(true)
	if not won:
		awarded["gold_units"]=int(loot["gold_units"])/int(CampaignEconomy.data()["defeat_gold_divisor"])
		awarded["weapons"]={}; awarded["characters"]={}; awarded["reserved_characters"]={}; awarded["reserved_weapons"]=0
	CampaignEconomy.credit(account,"coins",int(awarded["gold_units"]))
	CampaignEconomy.credit(account,"xp",int(awarded["xp_units"]))
	if won:
		for id in loot["weapons"]: account["heroes"][id]["weapon_cards"][0]+=int(loot["weapons"][id])
		for id in loot["characters"]: CampaignProgression.add_character_cards(account,id,int(loot["characters"][id]))
		for kind in loot["reserved_characters"]: account["reserved_characters"][kind]=int(account["reserved_characters"].get(kind,0))+int(loot["reserved_characters"][kind])
		account["reserved_weapons"]+=int(loot["reserved_weapons"])
		account["completions"][str(int(run["level"]))]=CampaignEconomy.completions(account,int(run["level"]))+1
	account["last_result"]={"won":won,"level":run["level"],"serial":run["serial"],"chest":run["chest"],"earned":loot.duplicate(true),"awarded":awarded}

static func abandon(account: Dictionary) -> bool:
	var run: Dictionary=account.get("active_run",{})
	if run.is_empty(): return false
	if not (run.get("status")=="reward" and int(run["battle"])==10): _close(account,false)
	account["active_run"]={}
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
