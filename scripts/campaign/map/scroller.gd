extends Node
## Pixel-space scrolling independent of the map's design scale and sticky HUD.
signal changed(offset: float)
var surface: Control
var settings: Dictionary = {}
var offset := 0.0
var maximum := 0.0
var target := 0.0
var velocity := 0.0
var dragging := false
var _pressed := false
var _touch := -1
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _start_offset := 0.0
var _last_time := 0
var _touch_frame := -100
var _block_click_frame := -100

func _ready() -> void:
	set_process(false)

func set_bounds(value: float) -> void:
	maximum = maxf(0,value)
	target = clampf(target,0,maximum)
	jump(offset)

func jump(value: float) -> void:
	offset = clampf(value,0,maximum); target = offset; velocity = 0
	changed.emit(offset)

func go_to(value: float) -> void:
	target = clampf(value,0,maximum); velocity = 0
	set_process(true)

func nudge(direction: int) -> void:
	go_to(target + direction * surface.size.x * float(settings["arrow_page_fraction"]))

func suppress_click() -> bool:
	return dragging or Engine.get_process_frames() <= _block_click_frame

func _begin(point: Vector2, touch: int) -> void:
	_pressed = true; _touch = touch; dragging = false
	_start = point; _last = point; _start_offset = offset; _last_time = Time.get_ticks_usec()
	velocity = 0; target = offset; set_process(false)

func _move(point: Vector2) -> void:
	if not _pressed: return
	if not dragging and point.distance_to(_start) >= float(settings["drag_threshold"]): dragging = true
	if not dragging: return
	var now := Time.get_ticks_usec()
	var seconds := maxf(0.008, float(now-_last_time)/1000000.0)
	velocity = clampf(-(point.x-_last.x)/seconds,-float(settings["max_velocity"]),float(settings["max_velocity"]))
	_last = point; _last_time = now
	offset = clampf(_start_offset-(point.x-_start.x),0,maximum); target = offset
	changed.emit(offset)

func _end() -> void:
	if dragging:
		_block_click_frame = Engine.get_process_frames()+1
		set_process(true)
	_pressed = false; dragging = false; _touch = -1

func _input(event: InputEvent) -> void:
	if not is_instance_valid(surface) or not surface.is_visible_in_tree(): return
	var bounds := surface.get_global_rect()
	if event is InputEventScreenTouch:
		_touch_frame = Engine.get_process_frames()
		if event.pressed and not _pressed and bounds.has_point(event.position): _begin(event.position,event.index)
		elif not event.pressed and _pressed and event.index == _touch: _end()
	elif event is InputEventScreenDrag:
		if _pressed and event.index == _touch: _move(event.position)
	elif event is InputEventMouseButton:
		# Godot can synthesize mouse events for touches; do not apply the same swipe twice.
		if Engine.get_process_frames() <= _touch_frame+2: return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _pressed and bounds.has_point(event.position): _begin(event.position,-1)
			elif not event.pressed and _pressed and _touch == -1: _end()
		elif event.pressed and bounds.has_point(event.position):
			if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_RIGHT]: nudge(1)
			elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT]: nudge(-1)
	elif event is InputEventMouseMotion and _pressed and _touch == -1:
		_move(event.position)

func _process(delta: float) -> void:
	if _pressed: return
	if absf(velocity)>2:
		var next := clampf(offset+velocity*delta,0,maximum)
		if is_equal_approx(next,offset): velocity = 0
		offset = next; target = next
		velocity *= exp(-float(settings["inertia_decay"])*delta)
	else:
		velocity = 0
		offset = lerpf(offset,target,1-exp(-float(settings["smoothing"])*delta))
		if absf(offset-target)<0.2: offset = target; set_process(false)
	changed.emit(offset)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pressed = false; dragging = false; _touch = -1; velocity = 0
		target = offset; set_process(false)
