class_name CampaignProgression
extends RefCounted
## Pure account/profile calculations. Never mutate CharacterCatalog templates.
static var _data: Dictionary = {}
const PLAYABLE: Array[String] = ["swordsman", "knifeman", "katana", "vampire", "club"]

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/campaign/data/progression.json"))
	return _data

static func new_account() -> Dictionary:
	var heroes: Dictionary = {}
	for id in PLAYABLE:
		heroes[id] = {"owned": id == "swordsman", "ranks": {}, "ability_rank": 0,
			"weapon_cards": [1, 0, 0, 0], "equipped_rarity": 0,
			"evolution": {"stage": 0, "personal_trial_won": false, "character_cards": 0}}
	return {"schema": 1, "coins": 0, "xp": 0, "heroes": heroes, "selected_hero": "swordsman",
		"unlocked_level": 1, "boss_wins": [], "next_bonus": {}, "receipts": [],
		"features": {"ally_slot_available": false, "ally_slot_owned": false, "future_ally": ""}, "active_run": {}}

static func rank(account: Dictionary, id: String, skill: String) -> int:
	return int(account.get("heroes", {}).get(id, {}).get("ranks", {}).get(skill, 0))

static func xp_cost(account: Dictionary, id: String, skill: String) -> int:
	if not PLAYABLE.has(id) or not data()["players"][id]["xp_skills"].has(skill):
		return -1
	var current := rank(account, id, skill)
	if skill == "recovery" and current >= 10:
		return -1
	if skill == "spin" and float(data()["players"][id]["spin_fraction"]) + current * float(data()["spin_rank_fraction"]) >= float(data()["spin_max_fraction"]) - 0.000001:
		return -1
	return ceili(float(data()["xp_costs"][skill]) * pow(float(data()["xp_cost_growth"]), mini(current, 80)) * (1.0 + current * 0.05))

static func coin_cost(account: Dictionary, id: String) -> int:
	if not PLAYABLE.has(id):
		return -1
	var settings: Dictionary = data()["players"][id]
	var current := int(account["heroes"][id]["ability_rank"])
	if float(settings["chance"]) + current * float(settings["chance_step"]) >= float(settings["chance_cap"]) - 0.000001:
		return -1
	return ceili(float(data()["coin_cost_base"]) * pow(float(data()["coin_cost_growth"]), current))

static func stats(id: String, account: Dictionary, bonuses: Dictionary = {}) -> Dictionary:
	assert(PLAYABLE.has(id), "Unknown playable campaign hero.")
	var settings: Dictionary = data()["players"][id]
	var original := CharacterCatalog.character(StringName(id))
	var weapon: AbilityDefinition = original.abilities[0]
	var parameters := weapon.parameters
	var hero: Dictionary = account["heroes"][id]
	var rarity := clampi(int(hero["equipped_rarity"]), 0, 3)
	var full_length := 0.0
	if id == "vampire":
		for tip in [Vector2(447, 903), Vector2(712, 923)]:
			full_length = maxf(full_length, (tip - Vector2(626, 513)).length() * 70.0 * original.diameter_multiplier / 566.0)
	elif id == "club":
		full_length = float(parameters["blade_length"]) * float(parameters["weapon_scale"])
	else:
		full_length = float(parameters["blade_length"]) * original.diameter_multiplier
	var base_hp := float(settings["hp"]) + rank(account, id, "hp") * 2.0
	var trained_chance := minf(float(settings["chance_cap"]), float(settings["chance"]) + int(hero["ability_rank"]) * float(settings["chance_step"]))
	var runtime_cap := 0.5 if id == "vampire" else 1.0
	var chance := minf(runtime_cap, trained_chance + float(bonuses.get("chance", 0.0)))
	var spin_fraction := minf(float(data()["spin_max_fraction"]), float(settings.get("spin_fraction", 0.0)) + rank(account, id, "spin") * float(data()["spin_rank_fraction"]))
	return {"id": id, "name": settings["name"], "base_hp": base_hp,
		"max_hp": base_hp * (1.0 + float(bonuses.get("hp", 0.0))),
		"speed": original.movement_speed * (1.0 + rank(account, id, "speed") * 0.03 + float(bonuses.get("speed", 0.0))),
		"spin": float(parameters.get("spin_speed", 0.0)) * spin_fraction * (1.0 + float(bonuses.get("spin", 0.0))),
		"damage": (float(settings["damage"]) + rank(account, id, "damage") * float(settings["damage_rank_gain"])) * (1.0 + float(bonuses.get("damage", 0.0))),
		"hit_growth": (float(settings["hit_growth"]) + rank(account, id, "hit_growth") * float(settings["hit_growth_rank_gain"])) * (1.0 + float(bonuses.get("damage", 0.0))),
		"healing": float(settings.get("healing", 0.0)) + rank(account, id, "healing") * float(settings.get("healing_rank_gain", 0.0)),
		"heal_growth": float(settings.get("heal_growth", 0.0)) + rank(account, id, "heal_growth") * float(settings.get("heal_growth_rank_gain", 0.0)),
		"chance": chance, "chance_cap": runtime_cap, "training_cap": settings["chance_cap"],
		"chance_growth": float(settings.get("chance_growth", 0.0)) + rank(account, id, "chance_growth") * float(settings.get("chance_growth_rank_gain", 0.0)),
		"recovery": minf(float(data()["recovery_max"]), float(data()["recovery_start"]) + rank(account, id, "recovery") * float(data()["recovery_step"])),
		"rarity": rarity, "length_factor": 1.0 if id == "vampire" else float(data()["rarity_factors"][rarity]),
		"weapon_length": full_length * (1.0 if id == "vampire" else float(data()["rarity_factors"][rarity])),
		"full_length": full_length, "diameter": 70.0 * original.diameter_multiplier,
		"body_weight": original.weight_class, "weapon_weight": weapon.weapon_weight_class,
		"mass": preload("res://scripts/combat/weight_classes.gd").factor(original.weight_class),
		"cooldown": float(parameters.get("hit_cooldown", parameters.get("recovery_time", 0.0))),
		"duration": float(parameters.get("bite_duration", parameters.get("berserk_duration", parameters.get("shield_duration", 0.0)))),
		"bleed_damage": float(settings.get("bleed_damage", 0.0))}

static func buy_hero(account: Dictionary, id: String) -> bool:
	if not PLAYABLE.has(id) or bool(account["heroes"][id]["owned"]):
		return false
	var price := int(data()["prices"][id])
	if int(account["coins"]) < price:
		return false
	account["coins"] -= price
	account["heroes"][id]["owned"] = true
	return true

static func upgrade(account: Dictionary, id: String, skill: String) -> bool:
	if not PLAYABLE.has(id) or not bool(account["heroes"][id]["owned"]):
		return false
	var price := coin_cost(account, id) if skill == "ability" else xp_cost(account, id, skill)
	var wallet := "coins" if skill == "ability" else "xp"
	if price < 0 or int(account[wallet]) < price:
		return false
	account[wallet] -= price
	if skill == "ability":
		account["heroes"][id]["ability_rank"] += 1
	else:
		account["heroes"][id]["ranks"][skill] = rank(account, id, skill) + 1
	return true

static func merge(account: Dictionary, id: String, tier: int) -> bool:
	if not PLAYABLE.has(id) or id == "vampire" or tier < 0 or tier >= 3 or not bool(account["heroes"][id]["owned"]):
		return false
	var hero: Dictionary = account["heroes"][id]
	var cards: Array = hero["weapon_cards"]
	if int(cards[tier]) < 3:
		return false
	cards[tier] -= 3
	cards[tier + 1] += 1
	for candidate in range(3, -1, -1):
		if int(cards[candidate]) > 0:
			hero["equipped_rarity"] = candidate
			break
	return true
