extends Button
## Art-only facade over the same read-only campaign entry as the established map.
const ART := preload("res://scripts/campaign/map/art/assets.gd")
var entry: Dictionary = {}

func image(parent: Node, asset: String, at: Vector2, extent: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = ART.texture(asset)
	picture.position = at; picture.size = extent
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
	size = Vector2(300,328)
	for key in ["normal","pressed","hover","disabled","focus"]: add_theme_stylebox_override(key,StyleBoxEmpty.new())
	disabled = not entry["can_enter"]
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW
	var geometry: Dictionary=ART.layout()["node"]
	var base := image(self,"level_base",Vector2.ZERO,Vector2(geometry["extent"][0],geometry["extent"][1]))
	base.name="BaseArt"
	var inset := ART.rect(geometry["portrait_inset"])
	var slot := TextureRect.new()
	slot.position=inset.position; slot.size=inset.size
	slot.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; slot.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(slot)
	slot.name = "BossTexture"; slot.texture = null
	var texture_path: String = entry.get("boss_icon_texture","")
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path): slot.texture = load(texture_path)
	var question := label("?",inset.position,inset.size,76,Color("f4efdb"))
	question.name = "Question"; question.visible = slot.texture==null
	var number_box := ART.rect(geometry["number"])
	label(str(int(entry["level_number"])),number_box.position,number_box.size,49,Color("fff5da"))
	var chest_box := ART.rect(geometry["chest"])
	var chest := image(self,"chest_"+entry["chest_type"],chest_box.position,chest_box.size)
	chest.name = "Chest"
	var status_box := ART.rect(geometry["status"])
	# Locked entries stay recognisable: retain their materials and dim the boss slot.
	if disabled:
		question.modulate = Color("a0b0bd")
		label("ЗАКРЫТ",status_box.position,status_box.size,18,Color("bdc8d4"))
	elif entry["state"]=="current":
		label("ТЕКУЩИЙ",status_box.position,status_box.size,18,Color("ffe5a0"))
	else:
		label("ПОБЕД: %d"%entry["completions"],status_box.position,status_box.size,18,Color("b6e9c3"))
	tooltip_text = entry["name"]+" · "+("доступен" if not disabled else "сначала пройдите предыдущие уровни")
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

func _draw() -> void:
	if not disabled and (is_hovered() or has_focus()): draw_arc(Vector2(150,275),100,0,TAU,48,Color("ffd78c"),3,true)
