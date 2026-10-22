extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 8: await process_frame
func run() -> void:
	root.size=Vector2i(844,390)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var view := preload("res://scenes/campaign/level_map.tscn").instantiate()
	layer.add_child(view); await settle()
	var before: Dictionary=view.account.duplicate(true)
	assert(view.level_nodes.size()==20 and view.entries.size()==20 and view.route.points.size()==20)
	var art := preload("res://scripts/campaign/map/art/assets.gd")
	for index in 20:
		var node: Button=view.level_nodes[index]
		var number := index+1
		var kind := "diamond" if number%10==0 else ("gold" if number%5==0 else "bronze")
		assert(node.get_node("Number").text==str(number))
		assert(node.get_node("BaseArt").texture==art.texture("level_base"))
		assert(node.get_node("Chest").texture==art.texture("chest_"+kind))
		assert(node.get_node("Question").visible and node.get_node("BossTexture").texture==null)
		assert(node.size==view.level_nodes[0].size)
		if number>5: assert(node.disabled and node.entry["is_unavailable"])
	assert(view.terminal.position.x>view.level_nodes[19].position.x+300)
	assert(not view.terminal.visible and not view.terminal.is_processing())
	view.scroller.jump(view.scroller.maximum)
	assert(view.terminal.visible and view.terminal.is_processing())
	assert(view.terminal.get_node("ComingSoon").text=="Скоро выйдет")
	assert(float(view.terminal.fog_material.get_shader_parameter("density"))>0.9)
	var previous: float=view.terminal.clock
	await settle(); assert(view.terminal.clock>previous)
	var calls := [0]; view.level_requested.connect(func(_number: int) -> void: calls[0]+=1)
	for number in range(6,21): view._activate(number)
	assert(calls[0]==0 and view.account==before)
	view.scroller.jump(0); assert(not view.terminal.visible and not view.terminal.is_processing())
	previous=view.terminal.clock; await settle(); assert(view.terminal.clock==previous)
	assert(view.header.size.x<=844 and view.footer.size.x<=844)
	layer.free(); await settle()
	print("campaign_painted_rollout_test: PASS"); quit(0)
