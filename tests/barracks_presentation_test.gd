extends SceneTree
const MODEL := preload("res://scripts/campaign/barracks/presentation.gd")
func _initialize() -> void:
	var account := CampaignProgression.new_account()
	var snapshot := account.duplicate(true)
	for id in CampaignProgression.playable_ids():
		assert(MODEL.main_stats(id,account).size()==6)
		assert(MODEL.details(id,account).size()>=12)
		for skill in CampaignProgression.data()["players"][id]["xp_skills"]:
			var future := account.duplicate(true)
			future["heroes"][id]["ranks"][skill]=1
			assert(MODEL.next_stats(account,id,skill)==CampaignProgression.stats(id,future))
		assert(MODEL.reason(account,id,40,"coins")!="")
	assert(account==snapshot)
	assert(MODEL.value("ability",CampaignProgression.stats("vampire",account))=="5.00%")
	print("barracks_presentation_test: PASS"); quit(0)
