extends RefCounted
## Read-only presentation adapter. Next values run the same progression compiler;
## no duplicate prices, rank formula, combat state or account mutations live here.
const NAMES := {"hp":"Макс. HP","damage":"Урон","spin":"Вращение","speed":"Скорость","hit_growth":"Прирост урона","healing":"Лечение за укус","heal_growth":"Прирост лечения","chance_growth":"Рост шанса крови","recovery":"Восстановление","ability":"Особая способность"}
const ICONS := {"hp":"hp","damage":"damage","spin":"spin","speed":"speed","hit_growth":"hit_growth","healing":"healing","heal_growth":"healing","chance_growth":"evolution","recovery":"healing","ability":"ability"}
const DESCRIPTIONS := {
	"swordsman":"Каждое попадание усиливает меч. Берсерк ускоряет вращение и сокращает кулдаун.",
	"knifeman":"Два кинжала быстро набирают вращение. Контратака может прервать укус вампира.",
	"katana":"Длинное лёгкое лезвие. Кровотечения от критических ударов складываются до конца боя.",
	"vampire":"Укус удерживает жертву три секунды и забирает здоровье. При малом HP начинается охота.",
	"club":"Тяжёлое оружие отбрасывает врагов. Удар о стену может нанести дополнительный урон."}
const WEAPONS := {"swordsman":"Стальной меч","knifeman":"Парные кинжалы","katana":"Катана","vampire":"Клыки вампира","club":"Тяжёлая дубина"}

static func weight(value: int) -> String:
	return ["Лёгкий","Легче среднего","Средний","Тяжелее среднего","Тяжёлый"][value]

static func ability_name(id: String) -> String:
	return {"swordsman":"Шанс берсерка","knifeman":"Контратака за тик","katana":"Шанс кровотечения","vampire":"Охота ниже HP","club":"Шанс удара о стену"}[id]

static func value(skill: String, stats: Dictionary) -> String:
	var key: String={"hp":"max_hp","ability":"chance"}.get(skill,skill)
	var amount := float(stats[key])
	if skill in ["recovery","chance_growth","ability"]: return "%.2f%%"%(amount*100)
	if skill=="spin": return "%.2f рад/с"%amount
	return "%.2f"%amount

static func next_stats(account: Dictionary, id: String, skill: String) -> Dictionary:
	var future := account.duplicate(true)
	if skill=="ability": future["heroes"][id]["ability_rank"]+=1
	else: future["heroes"][id]["ranks"][skill]=CampaignProgression.rank(account,id,skill)+1
	return CampaignProgression.stats(id,future)

static func reason(account: Dictionary, id: String, price: int, currency: String) -> String:
	if not account["active_run"].is_empty(): return "Прокачка доступна вне похода"
	if not account["heroes"][id]["owned"]: return "Сначала откройте героя"
	if price<0: return "Достигнут предел прокачки"
	if int(account[currency])<price: return "Нужно %d %s"%[price,"XP" if currency=="xp" else "монет"]
	return ""

static func main_stats(id: String, account: Dictionary) -> Array[Dictionary]:
	var s := CampaignProgression.stats(id,account)
	return [
		{"icon":"hp","name":"Макс. HP","value":value("hp",s)},
		{"icon":"damage","name":"Прямой урон","value":value("damage",s)},
		{"icon":"speed","name":"Скорость","value":value("speed",s)},
		{"icon":"spin" if id!="vampire" else "ability","name":"Вращение" if id!="vampire" else "Длительность укуса","value":value("spin",s) if id!="vampire" else "%.1f с"%s["duration"]},
		{"icon":"damage","name":"Длина оружия","value":"%.0f%% · %.2f ед."%[s["length_factor"]*100,s["weapon_length"]]},
		{"icon":"ability","name":ability_name(id),"value":value("ability",s),"max":s["training_cap"],"amount":s["chance"]}]

static func details(id: String, account: Dictionary) -> Array:
	var s := CampaignProgression.stats(id,account)
	var definition: CharacterDefinition=CampaignProfiles.hero(id,account)["definition"]
	var p: Dictionary=definition.abilities[0].parameters
	var rows := [["Масса тела","%.2f"%s["mass"]],["Вес тела",weight(s["body_weight"])],["Вес оружия",weight(s["weapon_weight"])],
		["Диаметр тела","%.2f ед."%s["diameter"]],["Длина / базовая длина","%.2f / %.2f ед."%[s["weapon_length"],s["full_length"]]],
		["Вращение","%.2f рад/с · %.2f об/с"%[s["spin"],s["spin"]/TAU]],
		["Кулдаун","%.2f с"%s["cooldown"]],["Урон за попадание","+%.2f"%s["hit_growth"]],
		["Предел урона в бою","%.2f"%s["damage_cap"] if s["damage_cap"]>0 else "Без ограничения"],
		["Восстановление после боя","%.2f%%"%(s["recovery"]*100)],
		["Длительность способности","%.2f с"%s["duration"]]]
	match id:
		"swordsman": rows.append_array([["Вращение в берсерке","×%.1f"%p["berserk_spin_multiplier"]],["Кулдаун в берсерке","%.2f с"%p["berserk_hit_cooldown"]],["Замедление меча после удара","×%.2f · %.1f с"%[p["post_hit_speed_ratio"],p["post_hit_slow_duration"]]],["Рост скорости за удар","+%.2f; предел %.2f"%[p["speed_gain"],p["max_speed"]]]])
		"knifeman": rows.append_array([["Прирост вращения","+%.2f рад/с"%p["spin_gain"]],["Предел вращения в бою","%.2f рад/с"%p["max_spin_speed"]],["Урон контратаки","%.0f%% текущего HP"%(p["capture_counter_hp_fraction"]*100)]])
		"katana": rows.append_array([["Рост шанса крови за удар","%.2f%%"%(s["chance_growth"]*100)],["Кровотечение за эффект","%.2f HP / с"%s["bleed_damage"]],["Длительность кровотечения","До конца боя; эффекты складываются"]])
		"vampire": rows.append_array([["Лечение за укус","%.2f HP"%s["healing"]],["Тиков за укус",str(p["bite_units"])],["Рост лечения за укус","+%.2f HP"%s["heal_growth"]],["Порог охоты","%.2f HP"%(s["base_hp"]*s["chance"])],["Задержка охоты","%.1f с"%p["hunt_delay"]],["Ускорение охоты","+%.0f%%"%(p["hunt_speed_bonus"]*100)],["Охота","Один раз за бой"]])
		"club": rows.append_array([["Урон от стены","%.0f%% макс. HP"%(p["wall_burst_fraction"]*100)],["Окно удара о стену","%.2f с"%p["wall_burst_window"]],["Щит при входящем ударе","%.1f%% · %.1f с"%[p["shield_chance"]*100,p["shield_duration"]]]])
	return rows
