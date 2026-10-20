class_name CampaignCards
extends RefCounted
const DEFINITIONS := {
	"spin": ["Быстрый клинок", "+5% к вращению", "common"],
	"hp": ["Крепкое тело", "+5% к максимальному HP", "common"],
	"speed": ["Лёгкий шаг", "+5% к скорости", "common"],
	"damage": ["Острая грань", "+5% к прямому урону", "common"],
	"chance": ["Особый приём", "+1 п.п. к способности / порогу охоты", "common"],
	"heal": ["Перевязка", "Восстановить 20% максимального HP", "common"],
	"vitality": ["Второе дыхание", "+15% максимального HP и лечение 15%", "common"],
	"ice": ["Ледяное оружие", "+5% урона; замедление вращения 10% на 2 с", "rare"],
	"fire": ["Огненное оружие", "+5% урона; ожог 5% HP за 3 с", "rare"],
	"shatter": ["Раскалывающий удар", "+5% урона; столкновение оружия наносит 10% урона", "rare"],
	"legend": ["Пробуждение", "+10 п.п. к способности / порогу охоты", "legendary"]}

static func eligible(id: String, run: Dictionary, stats: Dictionary, after_boss: bool) -> bool:
	if id == "spin" and run["hero"] == "vampire": return false
	if id == "shatter" and run["hero"] == "vampire": return false
	if not after_boss and id in ["ice","fire","shatter"] and float(run["bonuses"].get(id,0)) > 0: return false
	if id == "heal" and (after_boss or int(run["hp"])<=0 or int(run["hp"]) >= int(run["peak"])): return false
	if not after_boss and id == "legend" and float(run["bonuses"].get("legend",0)) > 0: return false
	if id in ["chance","legend"] and float(stats["chance"]) >= float(stats["chance_cap"])-0.000001: return false
	return true

static func offer(run: Dictionary, stats: Dictionary, rng: RandomNumberGenerator, after_boss: bool = false) -> Array[String]:
	var result: Array[String] = []
	for slot in 3:
		var roll := rng.randf()
		var rarity := "legendary" if roll < 0.01 else ("rare" if roll < 0.15 else "common")
		var pool: Array[String] = []
		for id in DEFINITIONS:
			if DEFINITIONS[id][2] == rarity and not result.has(id) and eligible(id,run,stats,after_boss): pool.append(id)
		if pool.is_empty():
			for id in DEFINITIONS:
				if DEFINITIONS[id][2] == "common" and not result.has(id) and eligible(id,run,stats,after_boss): pool.append(id)
		assert(not pool.is_empty())
		result.append(pool[rng.randi_range(0,pool.size()-1)])
	return result

static func bonus(id: String) -> Dictionary:
	match id:
		"spin", "hp", "speed", "damage": return {id:0.05}
		"chance": return {"chance":0.01}
		"vitality": return {"hp":0.15}
		"ice", "fire", "shatter": return {id:1.0,"damage":0.05}
		"legend": return {"chance":0.1,"legend":1.0}
	return {}

static func apply(run: Dictionary, account: Dictionary, id: String) -> void:
	var old := CampaignProgression.stats(run["hero"],account,run["bonuses"])
	for key in bonus(id): run["bonuses"][key]=float(run["bonuses"].get(key,0))+float(bonus(id)[key])
	var current := CampaignProgression.stats(run["hero"],account,run["bonuses"])
	var delta := CampaignUnits.pack(current["max_hp"]-old["max_hp"])
	var alive := int(run["hp"])>0
	if alive: run["hp"] += delta
	run["peak"] += delta
	if alive and id in ["heal","vitality"]:
		run["hp"] = mini(run["peak"],run["hp"]+roundi(run["peak"]*(0.2 if id=="heal" else 0.15)))
