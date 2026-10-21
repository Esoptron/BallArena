extends Button
## Art-only facade over the same read-only campaign entry as the established map.
const ROOT := "res://assets/campaign/map_art/"
var entry: Dictionary = {}

func image(parent: Node, asset: String, at: Vector2, extent: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = load(ROOT+asset+".svg")
	picture.position = at; picture.size = extent
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func label(text_value: String, at: Vector2, extent: Vector2, size_value: int, colour: Color) -> Label:
	var result := Label.new(); result.text = text_value
	result.position = at; result.size = extent; result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size",size_value)
	result.add_theme_color_override("font_color",colour)
	result.add_theme_color_override("font_outline_color",Color("101725"))
	result.add_theme_constant_override("outline_size",7)
	add_child(result); return result

func _ready() -> void:
	size = Vector2(260,265)
	for key in ["normal","pressed","hover","disabled","focus"]: add_theme_stylebox_override(key,StyleBoxEmpty.new())
	disabled = not entry["can_enter"]
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW
	image(self,"island",Vector2(0,175),Vector2(260,280))
	image(self,"platform",Vector2(10,170),Vector2(240,112))
	image(self,"boss_frame",Vector2(57,72),Vector2(132,132))
	var slot := image(self,"boss_frame",Vector2(71,86),Vector2(104,104))
	slot.name = "BossTexture"; slot.texture = null
	var texture_path: String = entry.get("boss_icon_texture","")
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path): slot.texture = load(texture_path)
	var question := label("?",Vector2(73,83),Vector2(100,112),84,Color("f4efdb"))
	question.name = "Question"; question.visible = slot.texture==null
	image(self,"number_sign",Vector2(38,3),Vector2(168,72))
	label(str(int(entry["level_number"])),Vector2(50,9),Vector2(140,60),49,Color("fff5da"))
	image(self,"star",Vector2(87,-37),Vector2(72,72))
	var chest := image(self,"chest_"+entry["chest_type"],Vector2(176,136),Vector2(104,98))
	chest.name = "Chest"
	# Locked entries stay recognisable: retain their materials and dim the boss slot.
	if disabled:
		question.modulate = Color("a0b0bd")
		label("ЗАКРЫТ",Vector2(27,246),Vector2(190,26),18,Color("bdc8d4"))
	elif entry["state"]=="current":
		label("ТЕКУЩИЙ",Vector2(27,246),Vector2(190,26),18,Color("ffe5a0"))
	else:
		label("ПОБЕД: %d"%entry["completions"],Vector2(27,246),Vector2(190,26),18,Color("b6e9c3"))
	tooltip_text = entry["name"]+" · "+("доступен" if not disabled else "сначала пройдите предыдущие уровни")
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

func _draw() -> void:
	if not disabled and (is_hovered() or has_focus()): draw_arc(Vector2(124,222),99,0,TAU,48,Color("ffd78c"),3,true)
