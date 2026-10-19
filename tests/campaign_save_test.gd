extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://builds/campaign-work/save-test-%d.json"%Time.get_ticks_usec()
	var a := CampaignProgression.new_account(); a["coins"]=100; a["xp"]=150
	assert(CampaignSave.write(a,path)==OK)
	a["coins"]=80; assert(CampaignRun.start(a,1,"swordsman",123)); assert(CampaignRun.begin(a))
	assert(CampaignSave.write(a,path)==OK)
	var loaded := CampaignSave.load_account(path)["account"] as Dictionary
	assert(loaded["coins"]==80 and loaded["active_run"]["status"]=="ready")
	assert(CampaignRun.begin(loaded)); assert(CampaignRun.settle(loaded,true,10000,20000,{"coins":10,"xp":5}))
	assert(CampaignSave.write(loaded,path)==OK)
	var reward := CampaignSave.load_account(path)["account"] as Dictionary
	assert(reward["active_run"]["status"]=="reward" and reward["coins"]==90)
	assert(not CampaignRun.settle(reward,true,10000,20000,{"coins":10,"xp":5}))
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string("broken"); file.close()
	var recovered := CampaignSave.load_account(path)
	assert(not recovered["warning"].is_empty() and recovered["account"]["coins"]==80)
	var old := CampaignProgression.new_account(); old["coins"]=333; old.erase("features")
	assert(CampaignSave.migrate(old)["coins"]==333)
	file=FileAccess.open(path,FileAccess.WRITE); file.store_string('{"format":99}'); file.close()
	assert(CampaignSave.load_account(path)["account"].is_empty())
	a["heroes"]["swordsman"]["ranks"]["hp"]="bad"
	assert(CampaignSave.write(a,path)==ERR_INVALID_DATA)
	print("campaign_save_test: PASS"); quit(0)
