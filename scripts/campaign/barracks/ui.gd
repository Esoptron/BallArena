extends RefCounted
const ART := preload("res://scripts/campaign/barracks/art.gd")
const INK := Color("edf2ff")
const GOLD := Color("ffd586")
const MUTED := Color("a9b7cd")
const GREEN := Color("7aef86")

static func label(value: String, font_size: int = 16, colour: Color = INK) -> Label:
	var item := Label.new()
	item.text=value; item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",colour)
	item.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	item.add_theme_constant_override("shadow_offset_y",1)
	return item

static func paragraph(value: String, font_size: int = 15, colour: Color = MUTED) -> Label:
	var item := label(value,font_size,colour)
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return item

static func icon(key: String, extent: float = 36) -> TextureRect:
	var item := TextureRect.new()
	item.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.texture=ART.texture(key)
	item.custom_minimum_size=Vector2(extent,extent)
	item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return item

static func button(value: String, action: Callable, selected: bool = false) -> Button:
	var item := Button.new()
	item.text=value; item.custom_minimum_size.y=44
	item.add_theme_font_size_override("font_size",16)
	style_button(item,selected)
	item.pressed.connect(action)
	item.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	return item

static func style_button(item: Button, selected: bool) -> void:
	item.add_theme_stylebox_override("normal",ART.frame("selected" if selected else "button",10))
	item.add_theme_stylebox_override("hover",ART.frame("selected",10))
	item.add_theme_stylebox_override("pressed",ART.frame("selected",10))
	item.add_theme_stylebox_override("disabled",ART.frame("button",10))
	var focus := StyleBoxFlat.new(); focus.bg_color=Color.TRANSPARENT
	focus.set_border_width_all(2); focus.border_color=GOLD; focus.set_corner_radius_all(5)
	item.add_theme_stylebox_override("focus",focus)
	item.add_theme_color_override("font_color",GOLD if selected else INK)
	item.add_theme_color_override("font_disabled_color",Color("8995a9"))

static func panel(parent: Node, key: String = "panel", margin: int = 12) -> VBoxContainer:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override("panel",ART.frame(key,margin)); parent.add_child(wrap)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",8)
	wrap.add_child(box); return box

static func row(parent: Node, separation: int = 8) -> HBoxContainer:
	var item := HBoxContainer.new(); item.add_theme_constant_override("separation",separation)
	parent.add_child(item); return item

static func title(parent: Node, text_value: String, key: String) -> void:
	var line := row(parent)
	line.add_child(icon(key,30)); line.add_child(label(text_value,22,GOLD))

static func progress(parent: Node, value: float, maximum: float, colour: Color = GOLD) -> ProgressBar:
	var bar := ProgressBar.new(); bar.custom_minimum_size.y=8
	bar.show_percentage=false; bar.max_value=maxf(maximum,0.001); bar.value=value
	var bg := StyleBoxFlat.new(); bg.bg_color=Color("0a1322"); bg.set_corner_radius_all(3)
	var fill := bg.duplicate() as StyleBoxFlat; fill.bg_color=colour
	bar.add_theme_stylebox_override("background",bg); bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar); return bar

static func clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()

static func dialog(caption: String) -> AcceptDialog:
	var item := AcceptDialog.new(); item.title=caption; item.dialog_autowrap=true
	var theme := Theme.new()
	theme.set_stylebox("panel","AcceptDialog",ART.frame("panel",16))
	theme.set_stylebox("embedded_border","Window",ART.frame("steel",6))
	for state in ["normal","hover","pressed","focus"]: theme.set_stylebox(state,"Button",ART.frame("selected" if state!="normal" else "button",10))
	theme.set_font_size("font_size","Label",15); theme.set_color("font_color","Label",INK)
	theme.set_font_size("font_size","Button",16); item.theme=theme
	item.get_ok_button().custom_minimum_size=Vector2(120,44)
	item.get_ok_button().text="Понятно"
	return item

static func flash(item: CanvasItem) -> void:
	item.modulate=Color(1.35,1.2,0.75)
	item.create_tween().tween_property(item,"modulate",Color.WHITE,0.35)
