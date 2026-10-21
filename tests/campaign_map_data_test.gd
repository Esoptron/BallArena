extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a := CampaignProgression.new_account()
	var before := a.duplicate(true)
	assert(CampaignMapData.validation_errors().is_empty())
	var entries := CampaignMapData.entries(a)
	assert(entries.size()==20 and entries[0]["state"]=="current" and entries[0]["can_enter"])
	for index in range(1,5): assert(entries[index]["state"]=="locked" and not entries[index]["can_enter"])
	for index in range(5,20): assert(entries[index]["state"]=="unavailable" and not entries[index]["can_enter"])
	assert(entries[4]["chest_type"]=="gold" and entries[9]["chest_type"]=="diamond" and entries[14]["chest_type"]=="gold")
	for entry in entries:
		var node := preload("res://scenes/campaign/level_node.tscn").instantiate()
		root.add_child(node); node.configure(entry,CampaignMapData.config()["chest_skins"])
		assert(node.get_node("BossSlot/Question").visible and node.get_node("BossSlot/Texture").texture==null)
		assert(node.disabled==not entry["can_enter"])
		node.free()
	assert(a==before)
	a["unlocked_level"]=5; a["completions"]={"1":1,"5":1}
	entries=CampaignMapData.entries(a)
	assert(entries[0]["state"]=="completed" and entries[1]["state"]=="open" and entries[4]["state"]=="current")
	assert(entries[4]["chest_type"]=="bronze")
	assert(CampaignRun.start(a,2,"swordsman",101))
	entries=CampaignMapData.entries(a)
	assert(entries[1]["can_enter"] and not entries[0]["can_enter"] and not entries[4]["can_enter"])
	assert(CampaignMapData.current_level(a)==2)
	assert(CampaignMapData.end_position(entries).x>CampaignMapData.position_of(entries[19]).x)
	await process_frame; await process_frame
	print("campaign_map_data_test: PASS"); quit(0)
