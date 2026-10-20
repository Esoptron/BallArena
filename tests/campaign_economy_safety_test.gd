extends SceneTree
class FailingController extends "res://scripts/campaign/controller.gd":
	var reject := false
	func _commit_account(candidate: Dictionary) -> bool:
		if reject: save_warning="Тест: запись недоступна"; return false
		return super._commit_account(candidate)
func _initialize() -> void: call_deferred("run")
func legacy_account() -> Dictionary:
	var a := CampaignProgression.new_account(); a["schema"]=2
	for id in a["heroes"]:
		var h: Dictionary=a["heroes"][id]
		h["weapon_cards"]=[1,1,1,1]; h["equipped_rarity"]=3
		h.erase("weapon_stage"); h.erase("unlock_card_units")
		h["evolution"]={"stage":0,"personal_trial_won":false,"character_cards":2}
	return a
func raw_save(path: String, value: Dictionary) -> void:
	var payload := JSON.stringify(value)
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify({"format":2,"payload":payload,"checksum":payload.sha256_text()})); f.close()
func run() -> void:
	var path := "res://builds/campaign-work/economy-safety-%d.json"%Time.get_ticks_usec()
	var legacy := legacy_account(); legacy["coins"]=77; legacy["xp"]=99; legacy["boss_wins"]=[1]
	legacy["receipts"]=["1:1:10","2.0:1.0:10.0"]
	raw_save(path,legacy)
	var before := FileAccess.get_file_as_bytes(path)
	var loaded := CampaignSave.load_account(path)["account"] as Dictionary
	assert(not loaded.is_empty() and loaded["coins"]==77 and loaded["xp"]==99)
	assert(CampaignEconomy.completions(loaded,1)==2)
	assert(FileAccess.get_file_as_bytes(path)==before and FileAccess.get_file_as_bytes(path+".pre-v%d"%CampaignSave.VERSION)==before)
	assert(loaded["heroes"]["swordsman"]["weapon_cards"]==[2,0,2,2,0,2,0])
	assert(CampaignSave.write(loaded,path)==OK)
	assert(CampaignSave.load_account(path)["account"]["heroes"]["swordsman"]["legacy_inventory"]["weapon_cards"].size()==4)
	# Legacy ready/fighting/reward runs retain paid waves without granting them twice.
	for status in ["ready","fighting","reward"]:
		var old := legacy_account()
		old["active_run"]={"serial":10,"level":1,"battle":3,"hero":"swordsman","seed":55,"hp":20000,"peak":20000,"bonuses":{},"status":status,"offer":["spin","hp","damage"] if status=="reward" else [],"profile":old["heroes"].duplicate(true)}
		var migrated := CampaignSave.migrate(old)
		assert(not migrated.is_empty())
		assert(migrated["active_run"]["legacy_paid_waves"]==(3 if status=="reward" else 2))
		assert(migrated["active_run"]["loot"]["gold_units"]==0)
		assert(CampaignSave.validate(migrated).is_empty())
	var a := CampaignProgression.new_account(); a["crystals"]=100
	assert(CampaignProgression.buy_hero(a,"club","crystals") and a["crystals"]==0)
	assert(not CampaignProgression.buy_hero(a,"club","coins"))
	a["coins"]=99999; assert(not CampaignProgression.buy_ally(a,"coins"))
	a["coins"]=100000; assert(CampaignProgression.buy_ally(a,"coins") and a["coins"]==0)
	a["crystals"]=999; assert(not CampaignProgression.buy_ally(a,"crystals") and a["crystals"]==999)
	assert(not CampaignEvolutions.progress(a,"swordsman")["ability_defined"])
	var controller := FailingController.new(); controller.save_path=path+"-controller"
	root.add_child(controller)
	assert(CampaignRun.start(controller.account,1,"swordsman",567))
	for wave in 9:
		assert(CampaignRun.begin(controller.account))
		assert(CampaignRun.settle(controller.account,true,20000,20000,{}))
		assert(CampaignRun.choose(controller.account,0))
	controller._resume(); assert(controller.page=="battle")
	var snapshot: Dictionary=controller.account.duplicate(true)
	controller.reject=true; controller._finished(true,20000,20000)
	await process_frame; await process_frame
	assert(controller.page=="settlement_error" and controller.account==snapshot)
	assert(not controller.pending_settlement.is_empty() and controller.pending_settlement["coins"]==120)
	controller.reject=false; controller._retry_settlement()
	assert(controller.page=="reward" and controller.account["coins"]==120 and controller.pending_settlement.is_empty())
	controller._retry_settlement(); assert(controller.account["coins"]==120)
	assert(CampaignEconomy.completions(controller.account,1)==1)
	controller.free(); await process_frame; await process_frame
	# A fractional card survives disk round-trips and cannot be spent as a whole copy.
	a=CampaignProgression.new_account(); CampaignProgression.add_character_cards(a,"katana",1)
	a["heroes"]["club"]["weapon_cards"][0]=3
	assert(not CampaignProgression.merge(a,"club",0))
	assert(CampaignSave.write(a,path)==OK)
	a=CampaignSave.load_account(path)["account"]
	assert(not a["heroes"]["katana"]["owned"] and a["heroes"]["katana"]["unlock_card_units"]==1)
	CampaignProgression.add_character_cards(a,"katana",1); assert(a["heroes"]["katana"]["owned"])
	# Corrupt monetary/inventory payloads are rejected without deleting backups.
	for field in ["crystals","coins_quarters","reserved_weapons"]:
		var broken := a.duplicate(true); broken[field]=-1; assert(CampaignSave.write(broken,path)==ERR_INVALID_DATA)
	a["heroes"]["katana"]["weapon_stage"]=6; assert(CampaignSave.write(a,path)==ERR_INVALID_DATA)
	print("campaign_economy_safety_test: PASS"); quit(0)
