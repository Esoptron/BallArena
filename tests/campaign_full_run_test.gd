extends SceneTree
## State/persistence coverage for all fifty transactions; not a combat simulator.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://builds/campaign-work/full-run-%d.json"%Time.get_ticks_usec()
	var a := CampaignProgression.new_account()
	for level in 5:
		assert(CampaignRun.start(a,level+1,"swordsman",5000+level))
		for battle in 10:
			assert(CampaignRun.begin(a))
			var run_state: Dictionary=a["active_run"]
			assert(CampaignRun.settle(a,true,run_state["hp"],run_state["peak"],CampaignLevels.encounter(level+1,battle+1)["reward"]))
			assert(CampaignSave.write(a,path)==OK,"%d–%d: %s"%[level+1,battle+1,CampaignSave.validate(a)])
			a=CampaignSave.load_account(path)["account"]
			assert(a["active_run"]["status"]=="reward")
			assert(CampaignRun.choose(a,0))
		assert(a["active_run"].is_empty())
	assert(a["coins"]==1000 and a["xp"]==845)
	assert(a["boss_wins"].size()==5 and a["unlocked_level"]==5)
	assert(a["features"]["ally_slot_available"] and a["next_bonus"].has("6"))
	assert(a["receipts"].size()==50)
	for level in range(1,6): assert(CampaignEconomy.completions(a,level)==1)
	assert(not CampaignRun.start(a,6,"swordsman",5))
	assert(CampaignProgression.rank(a,"swordsman","hp")==0)
	print("campaign_full_run_test: PASS"); quit(0)
