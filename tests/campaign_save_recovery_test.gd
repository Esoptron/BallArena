extends SceneTree
func _initialize() -> void: call_deferred("run")
func raw(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); assert(file!=null)
	file.store_string(text); file.close()
func run() -> void:
	var path := "res://builds/campaign-work/recovery-v3-%d"%Time.get_ticks_usec()
	# An interrupted first save is evidence of progress, not a new account.
	raw(path+".tmp","truncated")
	assert(CampaignSave.load_account(path)["account"].is_empty())
	assert(FileAccess.get_file_as_string(path+".tmp")=="truncated")
	var a := CampaignProgression.new_account(); a["coins"]=111
	assert(CampaignSave.write(a,path+"-temporary.tmp")==OK)
	var recovered := CampaignSave.load_account(path+"-temporary")
	assert(recovered["account"]["coins"]==111 and not recovered["warning"].is_empty())
	# Never downgrade a newer generation in backup or pending temporary storage.
	for suffix in [".bak",".tmp"]:
		var future_path: String=path+suffix.replace(".","-")
		assert(CampaignSave.write(a,future_path)==OK)
		raw(future_path+suffix,'{"format":99}')
		assert(CampaignSave.load_account(future_path)["account"].is_empty())
		assert(not CampaignSave._read(future_path).is_empty()) # The valid older file is intact.
	var oversized := path+"-oversize"
	var f := FileAccess.open(oversized,FileAccess.WRITE)
	f.seek(CampaignSave.MAX_FILE_BYTES); f.store_8(0); f.close()
	assert(CampaignSave._document(oversized)==null)
	assert(CampaignSave.load_account(oversized)["account"].is_empty())
	print("campaign_save_recovery_test: PASS"); quit(0)
