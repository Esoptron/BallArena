class_name CampaignSave
extends RefCounted
## Versioned envelope + checksum. A valid previous generation is always recoverable.
const VERSION := 3
static func default_path() -> String:
	# Development experiments never touch the primary project's user progress.
	return "res://builds/campaign-work/player-save.json" if OS.has_feature("editor") else "user://campaign-v2.json"

static func write(account: Dictionary, path: String = "") -> Error:
	if path.is_empty(): path=default_path()
	if not validate(account).is_empty(): return ERR_INVALID_DATA
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error!=OK: return error
	var payload := JSON.stringify(account)
	var envelope := {"format":VERSION,"checksum":payload.sha256_text(),"payload":payload}
	var temp := absolute+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope)); file.flush(); file.close()
	if _read(temp).is_empty(): return ERR_FILE_CORRUPT
	# Move the previous generation aside before publishing; a crash in between
	# is recovered from .bak, never interpreted as a brand new account.
	if FileAccess.file_exists(absolute):
		if not _read(absolute).is_empty():
			error=DirAccess.copy_absolute(absolute,absolute+".bak")
			if error!=OK: return error
		error=DirAccess.remove_absolute(absolute)
		if error!=OK: return error
	return DirAccess.rename_absolute(temp,absolute)

static func load_account(path: String = "") -> Dictionary:
	if path.is_empty(): path=default_path()
	var absolute := ProjectSettings.globalize_path(path)
	var exists := FileAccess.file_exists(absolute)
	if exists:
		var envelope: Variant=_parse(FileAccess.get_file_as_string(absolute))
		if envelope is Dictionary and int(envelope.get("format",envelope.get("schema",1)))>VERSION:
			return {"account":{},"warning":"Сохранение создано более новой версией. Автоматическое понижение версии отключено."}
		if envelope is Dictionary and envelope.get("payload") is String:
			var payload: Variant=_parse(envelope["payload"])
			if payload is Dictionary and int(payload.get("schema",1))>VERSION:
				return {"account":{},"warning":"Данные созданы более новой версией. Автоматическое понижение версии отключено."}
	var main := _read(absolute)
	if not main.is_empty():
		if _preserve_legacy(absolute)!=OK: return {"account":{},"warning":"Не удалось создать копию старого прогресса. Миграция заблокирована."}
		return {"account":main,"warning":""}
	var backup := _read(absolute+".bak")
	if exists:
		var preserved := absolute+".corrupt-"+str(Time.get_unix_time_from_system()).replace(".","-")
		var error := DirAccess.copy_absolute(absolute,preserved)
		if error!=OK: return {"account":{},"warning":"Не удалось сохранить повреждённый файл. Автоматическая перезапись заблокирована."}
	if not backup.is_empty():
		if _preserve_legacy(absolute+".bak")!=OK: return {"account":{},"warning":"Не удалось сохранить исходную резервную копию. Миграция заблокирована."}
		return {"account":backup,"warning":"Прогресс восстановлен из предыдущего сохранения. Повреждённый файл сохранён отдельно."}
	# A fully written temporary file may be the first generation after a crash.
	var temp := _read(absolute+".tmp")
	if not temp.is_empty():
		if _preserve_legacy(absolute+".tmp")!=OK: return {"account":{},"warning":"Не удалось сохранить исходный временный файл. Миграция заблокирована."}
		return {"account":temp,"warning":"Найдено завершённое временное сохранение после прерванной записи."}
	if exists or FileAccess.file_exists(absolute+".bak"):
		return {"account":{},"warning":"Сохранение повреждено. Файлы сохранены; автоматическое обнуление отключено."}
	return {"account":CampaignProgression.new_account(),"warning":""}

static func _preserve_legacy(path: String) -> Error:
	var raw: Variant=_parse(FileAccess.get_file_as_string(path))
	if raw is Dictionary and raw.get("payload") is String: raw=_parse(raw["payload"])
	if raw is Dictionary and int(raw.get("schema",1))<VERSION and not FileAccess.file_exists(path+".pre-v3"):
		return DirAccess.copy_absolute(path,path+".pre-v3")
	return OK

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size()>4*1024*1024: return {}
	var parsed: Variant=_parse(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {}
	var account: Variant=parsed
	if parsed.has("format"):
		if int(parsed["format"])>VERSION or not parsed.get("payload") is String or not parsed.get("checksum") is String: return {}
		if parsed["payload"].sha256_text()!=parsed["checksum"]: return {}
		account=_parse(parsed["payload"])
	if not account is Dictionary: return {}
	return migrate(account)

static func _parse(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text)==OK else null

static func migrate(source: Dictionary) -> Dictionary:
	if not _integer(source.get("schema",1),1,VERSION): return {}
	if int(source.get("schema",1))>VERSION: return {}
	var legacy := int(source.get("schema",1))<VERSION
	var result := _with_defaults(CampaignProgression.new_account(),source)
	if not result["heroes"] is Dictionary: return {}
	for key in ["features","completions","active_run"]:
		if not result[key] is Dictionary: return {}
	if not result["boss_wins"] is Array: return {}
	for id in CampaignProgression.playable_ids():
		var hero: Dictionary=CampaignProgression.new_account()["heroes"][id]
		if result["heroes"].has(id):
			if not result["heroes"][id] is Dictionary: return {}
			hero.merge(result["heroes"][id],true)
		if legacy and not _migrate_hero(hero): return {}
		result["heroes"][id]=hero
	if legacy:
		# Old saves only recorded whether a boss had ever been beaten, not how often.
		for level in result["boss_wins"]: result["completions"][str(int(level))]=1
		var completed_runs := {}
		if not result["receipts"] is Array: return {}
		for receipt in result["receipts"]:
			if not receipt is String: return {}
			var parts: PackedStringArray=receipt.split(":")
			if parts.size()!=3 or not parts[0].is_valid_float() or not parts[1].is_valid_float() or not parts[2].is_valid_float(): continue
			if float(parts[2])==10.0:
				var level_key := str(int(float(parts[1])))
				var serial_key := str(int(float(parts[0])))
				if not completed_runs.has(level_key): completed_runs[level_key]={}
				completed_runs[level_key][serial_key]=true
		for level_key in completed_runs: result["completions"][level_key]=maxi(int(result["completions"].get(level_key,0)),completed_runs[level_key].size())
		result["features"]["ally_slot_available"]=true
		if not result["active_run"].is_empty():
			var run: Dictionary=result["active_run"]
			if not run.get("profile") is Dictionary: return {}
			for id in run["profile"]:
				if not run["profile"][id] is Dictionary or not _migrate_hero(run["profile"][id]): return {}
			run["loot"]=CampaignEconomy.empty_loot()
			run["chest"]=CampaignEconomy.chest_type(int(run.get("level",1)),CampaignEconomy.completions(result,int(run.get("level",1))))
			run["reward_half_units"]=CampaignEconomy.reward_half_units(CampaignEconomy.completions(result,int(run.get("level",1))))
			run["legacy_paid_waves"]=int(run.get("battle",1))-(0 if run.get("status")=="reward" else 1)
			run["legacy_boss_settled"]=int(run.get("battle",1))==10 and run.get("status")=="reward"
	result["schema"]=VERSION
	if not validate(result).is_empty(): return {}
	for receipt in result["receipts"]:
		var serial: String=receipt.get_slice(":",0)
		if serial.is_valid_int(): result["run_serial"]=maxi(int(result.get("run_serial",0)),int(serial))
	if not result["active_run"].is_empty():
		var run: Dictionary=result["active_run"]
		# In-flight simulation restarts from the saved pre-battle HP/seed. Settled
		# rewards remain in 'reward' and cannot be earned a second time.
		if run["status"]=="fighting": run["status"]="ready"
		result["run_serial"]=maxi(int(result.get("run_serial",0)),int(run["serial"]))
	return result

static func _migrate_hero(hero: Dictionary) -> bool:
	var old: Variant=hero.get("weapon_cards")
	# Missing heroes already carry new-account defaults.
	if old is Array and old.size()==7 and hero.has("weapon_stage"): return true
	if not old is Array or old.size()!=4: return false
	var cards := [0,0,0,0,0,0,0]
	var mapping: Array=CampaignEconomy.data()["migration_legacy_stages"]
	for tier in 4:
		if not _integer(old[tier],0,1000000): return false
		cards[int(mapping[tier])]+=int(old[tier])*2
	var equipped := -1
	for tier in cards.size():
		if cards[tier]>=2: equipped=tier
	if equipped<0: return false
	var evolution: Variant=hero.get("evolution",{})
	if not evolution is Dictionary or not _integer(evolution.get("character_cards",0),0,1000000): return false
	hero["legacy_inventory"]={"weapon_cards":old.duplicate(),"equipped_rarity":hero.get("equipped_rarity",0),"evolution":evolution.duplicate(true)}
	hero["weapon_cards"]=cards; hero["weapon_stage"]=equipped; hero["unlock_card_units"]=0
	evolution["card_units"]=int(evolution.get("character_cards",0))*2
	evolution.erase("character_cards"); hero.erase("equipped_rarity")
	return true

static func _with_defaults(defaults: Dictionary, source: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for key in source:
		result[key]=_with_defaults(result[key],source[key]) if result.get(key) is Dictionary and source[key] is Dictionary else source[key]
	return result

static func _integer(value: Variant, lower: int, upper: int = 9000000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=lower and value<=upper

static func validate(a: Dictionary) -> String:
	if not _integer(a.get("schema"),VERSION,VERSION): return "Invalid account version"
	for key in ["coins","xp","crystals","unlocked_level","reserved_weapons"]:
		if not _integer(a.get(key),0): return "Invalid "+key
	for key in ["coins_quarters","xp_quarters"]:
		if not _integer(a.get(key),0,3): return "Invalid fractional wallet"
	if not a.get("completions") is Dictionary or not a.get("reserved_characters") is Dictionary or not a.get("last_result") is Dictionary: return "Invalid economy metadata"
	for level in a["completions"]:
		if not str(level).is_valid_int() or int(level)<1 or not _integer(a["completions"][level],0): return "Invalid completion count"
	for kind in a["reserved_characters"]:
		if not CampaignEconomy.data()["character_rarity_weights"].has(kind) or not _integer(a["reserved_characters"][kind],0): return "Invalid reserved character"
	var report: Dictionary=a["last_result"]
	if not report.is_empty():
		if not report.get("won") is bool or not _integer(report.get("level"),1,5) or not _integer(report.get("serial"),1): return "Invalid result identity"
		if not CampaignEconomy.data()["chests"].has(report.get("chest","")) or not _loot_valid(report.get("earned")) or not _loot_valid(report.get("awarded")): return "Invalid result rewards"
	if not _integer(a.get("run_serial",0),0): return "Invalid run serial"
	if int(a["unlocked_level"])<1 or int(a["unlocked_level"])>5: return "Invalid level"
	if not a.get("heroes") is Dictionary: return "Invalid heroes"
	for id in CampaignProgression.playable_ids():
		if not a["heroes"].get(id) is Dictionary: return "Missing hero"
		var h: Dictionary=a["heroes"][id]
		if not h.get("owned") is bool or not h.get("ranks") is Dictionary or not _integer(h.get("ability_rank"),0,1000): return "Invalid hero ranks"
		for skill in h["ranks"]:
			if not CampaignProgression.data()["players"][id]["xp_skills"].has(skill) or not _integer(h["ranks"][skill],0,1000): return "Invalid skill"
		if not h.get("weapon_cards") is Array or h["weapon_cards"].size()!=7 or not _integer(h.get("weapon_stage"),0,6): return "Invalid inventory"
		for count in h["weapon_cards"]:
			if not _integer(count,0,1000000): return "Invalid weapon count"
		var equipped := -1
		for tier in h["weapon_cards"].size():
			if h["weapon_cards"][tier]>=2: equipped=tier
		if equipped!=int(h["weapon_stage"]): return "Invalid equipped weapon stage"
		if not _integer(h.get("unlock_card_units"),0,1) or (h["owned"] and int(h["unlock_card_units"])!=0): return "Invalid unlock cards"
		if not h.get("evolution") is Dictionary: return "Invalid evolution"
		var evolution: Dictionary=h["evolution"]
		if not _integer(evolution.get("stage"),0,100) or not _integer(evolution.get("card_units"),0,1000000) or not evolution.get("personal_trial_won") is bool: return "Invalid evolution metadata"
	if not CampaignProgression.playable_ids().has(a.get("selected_hero","")): return "Invalid selected hero"
	if not a["heroes"][a["selected_hero"]]["owned"]: return "Selected hero is locked"
	for key in ["features","active_run","next_bonus"]:
		if not a.get(key) is Dictionary: return "Invalid "+key
	for flag in ["ally_slot_available","ally_slot_owned"]:
		if not a["features"].get(flag) is bool: return "Invalid ally flag"
	if not a["features"].get("future_ally","") is String: return "Invalid future ally"
	for key in ["receipts","boss_wins"]:
		if not a.get(key) is Array: return "Invalid "+key
	for receipt in a["receipts"]:
		if not receipt is String or receipt.length()>100: return "Invalid receipt"
	for win in a["boss_wins"]:
		if not _integer(win,1,5): return "Invalid boss win"
	for level in a["next_bonus"]:
		if not str(level) in ["1","2","3","4","5","6"] or not _bonus_valid(a["next_bonus"][level]): return "Invalid starting bonus"
	var run: Dictionary=a["active_run"]
	if not run.is_empty():
		if not _integer(run.get("serial"),1) or not _integer(run.get("level"),1,5) or not _integer(run.get("battle"),1,10): return "Invalid run identity"
		if not _integer(run.get("seed"),0,9223372036854775807) or not _integer(run.get("hp"),1) or not _integer(run.get("peak"),int(run["hp"])): return "Invalid run health/seed"
		if not CampaignProgression.playable_ids().has(run.get("hero","")) or not a["heroes"][run["hero"]]["owned"]: return "Invalid run hero"
		if not run.get("status","") in ["ready","fighting","reward"] or not _bonus_valid(run.get("bonuses")): return "Invalid run status"
		if not run.get("profile") is Dictionary or not run.get("offer") is Array: return "Invalid run profile/offer"
		if not CampaignEconomy.data()["chests"].has(run.get("chest","")) or not _integer(run.get("reward_half_units"),1,2): return "Invalid run economy"
		if not _loot_valid(run.get("loot")): return "Invalid run loot"
		var paid: Variant=run.get("legacy_paid_waves",0)
		if not _integer(paid,0,10) or not run.get("legacy_boss_settled",false) is bool: return "Invalid legacy settlement"
		var completed := int(run["battle"])-(0 if run["status"]=="reward" else 1)
		if int(run["loot"]["waves"])+int(paid)!=completed: return "Invalid wave ledger"
		var shadow := a.duplicate(true); shadow["active_run"]={}; shadow["heroes"]=run["profile"]; shadow["selected_hero"]=run["hero"]
		if not validate(shadow).is_empty(): return "Invalid frozen run profile"
		var offers: Array=run["offer"]
		if run["status"]=="reward" and offers.size()!=3: return "Invalid pending reward"
		var unique := {}
		for card in offers:
			if not card is String or not CampaignCards.DEFINITIONS.has(card) or unique.has(card): return "Invalid reward card"
			unique[card]=true
	return ""

static func _loot_valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["gold_units","xp_units","reserved_weapons","waves"]:
		if not _integer(value.get(key),0,10 if key=="waves" else 9000000000000): return false
	for key in ["weapons","characters","reserved_characters"]:
		if not value.get(key) is Dictionary: return false
		for id in value[key]:
			if key=="reserved_characters":
				if not CampaignEconomy.data()["character_rarity_weights"].has(id): return false
			elif not CampaignProgression.playable_ids().has(id): return false
			if not _integer(value[key][id],0,1000000): return false
	return true

static func _bonus_valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if not key in ["spin","hp","speed","damage","chance","ice","fire","shatter","legend"]: return false
		if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])) or value[key]<0 or value[key]>20: return false
	return true
