extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 5: await process_frame
func run() -> void:
	root.size=Vector2i(844,390)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var view := preload("res://scenes/campaign/level_map_art_preview.tscn").instantiate()
	view.account=CampaignProgression.new_account(); view.account["unlocked_level"]=5
	var before: Dictionary=view.account.duplicate(true)
	layer.add_child(view); await settle()
	assert(view.level_nodes.size()==3)
	var art := preload("res://scripts/campaign/map/art/assets.gd")
	assert(art.texture("level_base").get_height()<=768)
	assert(art.texture("chest_bronze").get_width()<=512)
	assert(art.texture("foreground").get_width()<=1024)
	assert(art.texture("ui").get_width()<=1024)
	for icon in art.layout()["ui_regions"]:
		var atlas := art.texture(icon) as AtlasTexture
		assert(atlas!=null and atlas.filter_clip and Rect2(Vector2.ZERO,atlas.atlas.get_size()).encloses(atlas.region))
		assert(art.texture(icon)==atlas)
	for index in 3:
		var node: Button=view.level_nodes[index]
		assert(node.get_node("Question").visible and node.get_node("BossTexture").texture==null)
		assert(node.get_node("Chest").texture.resource_path.ends_with("chest-gold-v2.png" if index==2 else "chest-bronze-v2.png"))
		assert(node.size==view.level_nodes[0].size)
		assert(node.get_node("BaseArt").size==Vector2(300,400))
		assert(node.get_node("Chest").size==Vector2(110,110))
	var calls: Array[int]=[]
	view.level_requested.connect(func(number: int) -> void: calls.append(number))
	view._activate(5); assert(calls==[5])
	var header_rect: Rect2=view.header.get_global_rect()
	view.scroller.jump(120)
	assert(is_equal_approx(view.middle.position.x,-120))
	assert(is_equal_approx(view.upper.position.x,-30) and is_equal_approx(view.lower.position.x,-66))
	assert(view.header.get_global_rect()==header_rect)
	# Adjacent scenery tiles touch; mirrored borders use the same source edge.
	for group in [view.upper,view.lower]:
		for index in range(group.tiles.size()-1):
			var tile: Sprite2D=group.tiles[index]
			var next: Sprite2D=group.tiles[index+1]
			assert(is_equal_approx(tile.position.x+tile.texture.get_width()*tile.scale.x,next.position.x))
			assert(tile.flip_h!=next.flip_h)
	var start: Vector2=view.surface.get_global_rect().get_center()
	var down := InputEventScreenTouch.new(); down.pressed=true; down.position=start
	view.scroller._input(down)
	var drag := InputEventScreenDrag.new(); drag.position=start-Vector2(45,0)
	view.scroller._input(drag)
	var up := InputEventScreenTouch.new(); up.position=drag.position
	view.scroller._input(up); view._activate(1); assert(calls==[5])
	assert(view.account==before)
	layer.free(); await settle()
	# Original data and components are still the default; no art migration.
	var original := CampaignMapData.entries(before)
	assert(original.size()==20 and original[5]["is_unavailable"])
	print("campaign_map_art_test: PASS"); quit(0)
