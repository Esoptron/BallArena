extends Button
var entry: Dictionary = {}
var state := "locked"
var _clock := 0.0
var _elapsed := 0.0
var _pulse_enabled := false
var accent := Color("e0a25e")
var frame_style: StyleBoxFlat

func _ready() -> void:
	for style in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
	set_process(false)

func configure(value: Dictionary, skins: Dictionary) -> void:
	entry = value; state = entry["state"]
	disabled = not entry["can_enter"]
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	$Number.text = str(int(entry["level_number"]))
	var muted := state in ["locked","unavailable"]
	accent = Color("647387") if muted else (Color("78c6a0") if state == "completed" else Color("edac64"))
	frame_style = preload("res://scripts/ui/menu_styles.gd").box(Color("161d2a"),accent,11,0,0)
	$Number.add_theme_color_override("font_color",Color("8793a5") if muted else Color("fff2da"))
	$BossSlot/Question.add_theme_color_override("font_color",Color("657084") if muted else Color("e9ce9c"))
	$Status.text = {"open":"Открыт","current":"Вы здесь","locked":"Закрыт","unavailable":"В разработке","completed":"Пройден ✓"}[state]
	if int(entry["completions"]) > 0: $Status.text = "Побед: %d ✓" % entry["completions"]
	$Status.add_theme_color_override("font_color",accent)
	var path: String = entry.get("boss_icon_texture", "")
	$BossSlot/Texture.texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	$BossSlot/Question.visible = $BossSlot/Texture.texture == null
	$BossSlot/Texture.modulate = Color("707888") if muted else Color.WHITE
	$ChestSlot.configure(entry["chest_type"],skins[entry["chest_type"]],muted)
	$ChestSlot.visible = entry.get("show_chest",true)
	for child in $Markers.get_children(): child.free()
	for marker in entry.get("markers",[]):
		var label := Label.new(); label.text = str(marker); label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color",Color("f7be6b")); $Markers.add_child(label)
	tooltip_text = "%s\n%s · награды %d%%\nПобед: %d" % [entry["name"],CampaignEconomy.data()["chests"][entry["reward_type"]]["name"]+" сундук",entry["reward_percent"],entry["completions"]]
	if state == "unavailable": tooltip_text = "Уровень %d пока не создан" % entry["level_number"]
	elif state == "locked": tooltip_text = "Сначала пройдите уровень %d" % entry.get("unlock_requirement",0)
	set_animation_visible(true)
	queue_redraw()

func set_animation_visible(value: bool) -> void:
	_pulse_enabled = value and state == "current"
	set_process(_pulse_enabled)

func _process(delta: float) -> void:
	_clock += delta; _elapsed += delta
	if _elapsed < 1.0/24.0: return
	_elapsed = 0; queue_redraw()

func _draw() -> void:
	var dark := Color("161d2a")
	var stone := Color(entry.get("zone_theme",{}).get("stone","354459")) if state != "unavailable" else Color("262e3d")
	if state == "current":
		for ring in 3:
			draw_circle(Vector2(80,78),43+ring*5,Color(1,0.55,0.18,(0.035+0.012*sin(_clock*3.0))*(3-ring)))
	draw_colored_polygon(PackedVector2Array([Vector2(6,137),Vector2(20,126),Vector2(144,126),Vector2(155,138),Vector2(143,156),Vector2(19,156)]),dark)
	draw_colored_polygon(PackedVector2Array([Vector2(10,135),Vector2(24,124),Vector2(139,124),Vector2(150,135),Vector2(138,145),Vector2(22,145)]),stone)
	draw_line(Vector2(24,128),Vector2(135,128),accent.darkened(0.25),2,true)
	for x in [30,73,119]: draw_line(Vector2(x,147),Vector2(x+4,154),stone.lightened(0.15),2,true)
	var frame := Rect2(43,39,74,74)
	if frame_style != null: draw_style_box(frame_style,frame)
	draw_line(Vector2(53,45),Vector2(105,45),accent.lightened(0.15),2,true)
	if has_focus() or (not disabled and is_hovered()): draw_rect(Rect2(38,34,84,84),accent,false,2)
	if state in ["locked","unavailable"]:
		draw_arc(Vector2(80,119),5,PI,TAU,12,accent,2,true)
		draw_rect(Rect2(73,118,14,11),accent.darkened(0.1))
		draw_circle(Vector2(80,122),1.6,dark)
