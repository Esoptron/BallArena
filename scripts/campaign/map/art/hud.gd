extends RefCounted
const ART := preload("res://scripts/campaign/map/art/assets.gd")

static func label(parent: Node, text: String, size: int = 22, colour: Color = Color("fff1cd")) -> Label:
	var result := Label.new(); result.text=text
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",colour)
	result.add_theme_color_override("font_outline_color",Color("0b1725"))
	result.add_theme_constant_override("outline_size",5)
	result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(result); return result

static func button(parent: Node, asset: String, text: String, extent: Vector2, action: Callable, mirrored: bool = false) -> Button:
	var result := Button.new(); result.custom_minimum_size=extent
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]: result.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var art := TextureRect.new(); art.texture=ART.texture(asset)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_SCALE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); art.flip_h=mirrored
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE; result.add_child(art)
	var title := label(result,text,20 if asset!="shop" else 24)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if asset=="shop": title.offset_left=30; title.offset_top=10; title.add_theme_font_size_override("font_size",18)
	result.pressed.connect(action)
	result.mouse_entered.connect(func() -> void: art.modulate=Color(1.15,1.12,1.05))
	result.mouse_exited.connect(func() -> void: art.modulate=Color.WHITE)
	result.button_down.connect(func() -> void: art.modulate=Color("b8c0c6"))
	result.button_up.connect(func() -> void: art.modulate=Color.WHITE)
	parent.add_child(result); return result

static func resource(parent: Node, icon: String, value: String, hint: String) -> PanelContainer:
	var result := PanelContainer.new(); result.custom_minimum_size=Vector2(130,52)
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL; result.tooltip_text=hint
	var style := StyleBoxTexture.new(); style.texture=ART.texture("resource_bar")
	style.texture_margin_left=14; style.texture_margin_right=14
	style.texture_margin_top=14; style.texture_margin_bottom=14
	style.content_margin_left=4; style.content_margin_right=8
	result.add_theme_stylebox_override("panel",style)
	var row := HBoxContainer.new(); row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var image := TextureRect.new(); image.texture=ART.texture(icon)
	image.custom_minimum_size=Vector2(44,48); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(image)
	var number := label(row,value,23); number.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.add_child(row); parent.add_child(result); return result
