extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 4: await process_frame
func run() -> void:
	root.size = Vector2i(844,390)
	var layer := CanvasLayer.new(); root.add_child(layer)
	var view := preload("res://scenes/campaign/level_map.tscn").instantiate()
	layer.add_child(view); await settle()
	assert(view.level_nodes.size()==20 and view.scroller.maximum>2000)
	var before: Dictionary=view.account.duplicate(true)
	var sticky: Rect2=view.get_node("MarginContainer/VBoxContainer/StickyHUD").get_global_rect()
	view.scroller.jump(200)
	assert(is_equal_approx(view.middle.position.x,-200))
	assert(is_equal_approx(view.upper.position.x,-50))
	assert(is_equal_approx(view.lower.position.x,-110))
	assert(view.get_node("MarginContainer/VBoxContainer/StickyHUD").get_global_rect()==sticky)
	view.scroller.jump(999999); assert(view.scroller.offset==view.scroller.maximum and view.right_button.disabled)
	assert(view.terminal.is_processing() and view.terminal.get_node("ComingSoon").text=="Скоро выйдет")
	view.scroller.jump(-100); assert(view.scroller.offset==0 and view.left_button.disabled)
	assert(not view.terminal.is_processing())
	var calls := [0]; view.level_requested.connect(func(_number: int) -> void: calls[0]+=1)
	view._activate(20); view._activate(2); assert(calls[0]==0)
	view._activate(1); assert(calls[0]==1)
	# Dispatch through the viewport too: a drag begun on a button must not launch it.
	var button_center: Vector2 = view.level_nodes[0].get_global_rect().get_center()
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index=MOUSE_BUTTON_LEFT; mouse_down.pressed=true; mouse_down.position=button_center
	Input.parse_input_event(mouse_down); await process_frame
	var motion := InputEventMouseMotion.new(); motion.position=button_center-Vector2(70,0)
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion); await process_frame
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index=MOUSE_BUTTON_LEFT; mouse_up.position=motion.position
	Input.parse_input_event(mouse_up); await settle()
	assert(calls[0]==1 and not view.level_nodes[0].button_pressed)
	view.scroller.jump(0)
	var start: Vector2=view.surface.get_global_rect().get_center()
	var down := InputEventScreenTouch.new(); down.index=0; down.position=start; down.pressed=true
	view.scroller._input(down)
	var drag := InputEventScreenDrag.new(); drag.index=0; drag.position=start-Vector2(150,0)
	view.scroller._input(drag)
	assert(view.scroller.dragging and view.scroller.offset==150)
	var up := InputEventScreenTouch.new(); up.index=0; up.position=drag.position; up.pressed=false
	view.scroller._input(up); view._activate(1); assert(calls[0]==1)
	view.scroller.jump(view.scroller.maximum*0.4)
	var center: float=view.center_on_map()
	root.size=Vector2i(1280,720); await settle()
	assert(absf(view.center_on_map()-center)<1)
	assert(view.account==before)
	layer.free(); await settle()
	print("campaign_map_navigation_test: PASS"); quit(0)
