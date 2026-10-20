class_name CampaignEconomy
extends RefCounted
## Exact reward accounting: cards in halves; money/XP in quarters, including defeat.
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty(): _data=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/campaign/data/economy.json"))
	assert(_data["empty_character_pool_policy"]=="reserve_by_rarity","Unsupported empty rarity policy; do not silently reroll.")
	assert(_data["excess_weapon_policy"]=="reserve_weapon_cards","Unsupported weapon overflow policy; do not silently replace rewards.")
	return _data

static func chance(rng: RandomNumberGenerator, probability: float) -> bool:
	# Inclusive randf() can return 1. Use exact basis points, including 0%/100%.
	return rng.randi_range(0,9999)<roundi(probability*10000)

static func completions(account: Dictionary, level: int) -> int:
	return int(account.get("completions",{}).get(str(level),0))

static func chest_type(level: int, wins: int) -> String:
	if wins>0: return "common"
	for kind in ["epic","rare"]:
		if level%int(data()["special_chest_intervals"][kind])==0: return kind
	return "common"

static func reward_half_units(wins: int) -> int:
	var factors: Array = data()["repeat_factors_half_units"]
	return int(factors[mini(wins,factors.size()-1)])

static func wave_gold(level: int, wave: int, authored: int = 0) -> int:
	var table: Array = data()["gold_by_level"]
	if level>table.size(): return authored
	var total := int(table[level-1])
	var normal := floori(float(total)*float(data()["ordinary_wave_weight"])/(9*float(data()["ordinary_wave_weight"])+float(data()["boss_wave_weight"])))
	return total-9*normal if wave==10 else normal

static func empty_loot() -> Dictionary:
	return {"gold_units":0,"xp_units":0,"weapons":{},"characters":{},"reserved_characters":{},"reserved_weapons":0,"waves":0}

static func wallet_units(account: Dictionary, wallet: String) -> int:
	return int(account[wallet])*int(data()["resource_scale"])+int(account.get(wallet+"_quarters",0))

static func credit(account: Dictionary, wallet: String, units: int) -> void:
	var total := wallet_units(account,wallet)+units
	account[wallet]=floori(float(total)/int(data()["resource_scale"]))
	account[wallet+"_quarters"]=total%int(data()["resource_scale"])

static func text(units: int, scale: int = 2) -> String:
	var value := "%.2f"%(float(units)/scale)
	return value.trim_suffix("0").trim_suffix("0").trim_suffix(".")

static func rarity(id: String) -> String:
	return String(data()["hero_catalog"].get(id,{}).get("rarity",""))

static func prices(id: String) -> Dictionary:
	return data()["hero_prices"].get(rarity(id),{})

static func character_target(rng: RandomNumberGenerator) -> Dictionary:
	var weights: Dictionary = data()["character_rarity_weights"]
	var total := 0
	for value in weights.values(): total+=int(value)
	var roll := rng.randi_range(0,total-1)
	var selected := ""
	for kind in weights:
		roll-=int(weights[kind])
		if roll<0: selected=kind; break
	var pool: Array[String]=[]
	for id in CampaignProgression.playable_ids():
		if rarity(id)==selected: pool.append(id)
	return {"rarity":selected,"id":"" if pool.is_empty() else pool[rng.randi_range(0,pool.size()-1)]}

static func weapon_target(account: Dictionary, active: String, rng: RandomNumberGenerator) -> String:
	var stage := int(account["heroes"][active].get("weapon_stage",0))
	var active_chance := float(data()["weapon_active_chances"][stage])
	var pool: Array[String]=[]
	var active_eligible := false
	for id in CampaignProgression.playable_ids():
		if not data()["hero_catalog"].get(id,{}).get("weapon_drop",false): continue
		if int(account["heroes"][id].get("weapon_stage",0))>=data()["weapon_length_factors"].size()-1: continue
		if id==active: active_eligible=true
		else: pool.append(id)
	if chance(rng,active_chance) and active_eligible: return active
	# An empty residual pool is kept in reserve, never rerolled into the active hero.
	return "" if pool.is_empty() else pool[rng.randi_range(0,pool.size()-1)]

static func roll_wave(account: Dictionary, run: Dictionary, reward: Dictionary) -> void:
	var loot: Dictionary=run["loot"]
	var half_units := int(run["reward_half_units"])
	loot["gold_units"]+=int(wave_gold(run["level"],run["battle"],int(reward.get("coins",0)))*half_units*int(data()["resource_scale"])/2)
	loot["xp_units"]+=int(int(reward.get("xp",0))*half_units*int(data()["resource_scale"])/2)
	loot["waves"]+=1
	# Local per-wave RNG cannot perturb combat RNG or temporary upgrade offers.
	var rng := RandomNumberGenerator.new()
	rng.seed=int(run["seed"]) ^ int(run["battle"])*15485863 ^ int(run["serial"])*32452843
	var chest: Dictionary=data()["chests"][run["chest"]]
	var character_drop := chance(rng,float(chest["character_chance"]))
	var weapon_drop := chance(rng,float(chest["weapon_chance"]))
	if character_drop:
		var target := character_target(rng)
		var key := "characters" if not target["id"].is_empty() else "reserved_characters"
		var id: String=target["id"] if key=="characters" else target["rarity"]
		loot[key][id]=int(loot[key].get(id,0))+half_units
	if weapon_drop:
		var id := weapon_target(account,run["hero"],rng)
		if id.is_empty(): loot["reserved_weapons"]+=half_units
		else: loot["weapons"][id]=int(loot["weapons"].get(id,0))+half_units
