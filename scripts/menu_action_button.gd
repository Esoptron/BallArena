extends Button
## Lightweight concept button: vector geometry, no textures, blur or continuous animation.
var icon_kind := "play"
var primary := false
var danger := false
var caption: Label

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	caption = Label.new()
	caption.text = text
	caption.add_theme_font_override("font", get_theme_font("font"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 52
	caption.offset_right = -42
	caption.add_theme_font_size_override("font_size", 23 if primary else 20)
	caption.add_theme_color_override("font_color", Color("f0f6ff") if not danger else Color("a5b8d5"))
	add_child(caption)
	for event in [mouse_entered, mouse_exited, focus_entered, focus_exited]: event.connect(queue_redraw)
	resized.connect(queue_redraw)

func rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in 4:
		var center: Vector2 = [rect.position + Vector2(radius,radius), Vector2(rect.end.x-radius,rect.position.y+radius), rect.end-Vector2(radius,radius),Vector2(rect.position.x+radius,rect.end.y-radius)][corner]
		for step in 9:
			var angle := PI + corner*PI*0.5 + step*PI/16.0
			points.append(center + Vector2.from_angle(angle)*radius)
	return points

func _draw() -> void:
	var rect := Rect2(Vector2(2,2),size-Vector2(4,4))
	var rim := Color("48baff") if primary else Color("315d98")
	if danger: rim = Color("493950")
	var active := is_hovered() or has_focus()
	if active: rim = rim.lightened(0.25)
	if primary:
		for layer in range(3,0,-1):
			var glow := rounded(rect.grow(layer*1.5),13+layer*1.5)
			glow.append(glow[0])
			draw_polyline(glow,Color(0.06,0.47,1.0,0.055),3,true)
	var outline := rounded(rect,13)
	var colors := PackedColorArray()
	var top := Color("1266dd") if primary else Color("112a4c")
	var bottom := Color("083fa9") if primary else Color("0b192e")
	if danger:
		top = Color("151d30")
		bottom = Color("10192a")
	if active:
		top = top.lightened(0.08)
		bottom = bottom.lightened(0.08)
	if button_pressed:
		top = top.darkened(0.15)
		bottom = bottom.darkened(0.15)
	for point in outline: colors.append(top.lerp(bottom,clampf(point.y/size.y,0,1)))
	draw_polygon(outline,colors)
	outline.append(outline[0])
	draw_polyline(outline,rim,2 if primary else 1.2,true)
	var center := Vector2(40,size.y*0.5)
	var ink := Color("edf7ff") if not danger else Color("ed5b69")
	match icon_kind:
		"play":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-7,-11),center+Vector2(11,0),center+Vector2(-7,11)]),ink)
		"modes":
			for x in 2:
				for y in 2: draw_style_box(_tile(ink),Rect2(center+Vector2(-10+x*12,-10+y*12),Vector2(9,9)))
		"settings":
			var gear := PackedVector2Array()
			for index in 32:
				gear.append(center + Vector2.from_angle(index*TAU/32)*(12 if index%4 in [1,2] else 9))
			draw_colored_polygon(gear,ink)
			draw_circle(center,4.2,Color("10213a"))
		"exit":
			draw_polyline(PackedVector2Array([center+Vector2(2,-10),center+Vector2(10,-10),center+Vector2(10,10),center+Vector2(2,10)]),ink,2.5,true)
			draw_line(center+Vector2(-10,0),center+Vector2(3,0),ink,2.5,true)
			draw_polyline(PackedVector2Array([center+Vector2(-1,-5),center+Vector2(4,0),center+Vector2(-1,5)]),ink,2.5,true)
	var arrow := Vector2(size.x-30,size.y*0.5)
	draw_polyline(PackedVector2Array([arrow+Vector2(-3,-6),arrow+Vector2(3,0),arrow+Vector2(-3,6)]),Color("ebf3ff") if not danger else Color("7892b9"),2,true)

func _tile(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style
