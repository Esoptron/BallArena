extends Control
signal battle_requested(roster: Array[Dictionary], format: StringName, title: String)
signal duel_requested
signal quit_requested
const LEVEL := preload("res://levels/level_01.tres")
const NAMES := preload("res://scripts/ui/character_text.gd").NAMES
const STYLES := preload("res://scripts/ui/menu_styles.gd")
const BLUE := Color("83b2ff")
const GOLD := Color("e2b46d")
const TEXT := Color("eef3ff")
const MUTED := Color("9aa9c0")
var page: String = "home"
var content: VBoxContainer
var title_label: Label
var buttons: Dictionary = {}
var free_counts: Dictionary = {}
var status_label: Label
var free_start: Button
var format: StringName = &"teams"
var last_roster: Array[Dictionary] = []
var sticky_footer: PanelContainer
var selector: Control
var free_selections: Array[StringName] = [&"swordsman",&"vampire"]
var scroll: ScrollContainer
const LAYOUT := preload("res://scripts/screen_layout.gd")
var header: BoxContainer
var brand: Label
var home_grid: GridContainer
var padding: MarginContainer
var heading_font: FontVariation

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading_font = FontVariation.new()
	heading_font.base_font = ThemeDB.fallback_font
	heading_font.variation_embolden = 0.7
	var skin := Theme.new()
	skin.default_font_size = 16
	skin.set_color("font_color","Label",TEXT)
	skin.set_color("font_color","Button",TEXT)
	theme = skin
	get_viewport().size_changed.connect(_resize)
	show_page("home")

func _style(accent: Color, filled: bool = false) -> StyleBoxFlat:
	return STYLES.box(Color("193564") if filled else Color("131f32"), accent if filled else Color("34445e"), 14, 18, 14)

func button(text: String, action: Callable, accent: Color = BLUE, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 58
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_size_override("font_size",18)
	result.add_theme_stylebox_override("normal",_style(accent,primary))
	result.add_theme_stylebox_override("hover",_style(accent,true))
	result.add_theme_stylebox_override("pressed",_style(accent.darkened(0.3),true))
	var focus := _style(accent)
	focus.bg_color = Color.TRANSPARENT
	result.add_theme_stylebox_override("focus",focus)
	result.pressed.connect(action)
	return result

func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	return result

func card(parent: Node, accent: Color = BLUE) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",_style(accent))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	return box

func show_page(next: String) -> void:
	if next not in ["home", "modes", "free", "settings"]:
		return
	page = next
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	sticky_footer = null
	selector = null
	free_start = null
	status_label = null
	title_label = null
	home_grid = null
	var background := ColorRect.new()
	background.color = Color("090f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var decor := Control.new()
	decor.set_script(preload("res://scripts/menu_backdrop.gd"))
	decor.hero_scene = page == "home"
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(decor)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	padding = MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left","right"]: padding.add_theme_constant_override("margin_"+side,16)
	for side in ["top","bottom"]: padding.add_theme_constant_override("margin_"+side,20)
	scroll.add_child(padding)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	padding.add_child(center)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	center.add_child(content)
	header = BoxContainer.new()
	header.vertical = true
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	brand = label("B A L L A R E N A",18,GOLD)
	header.add_child(brand)
	if page != "home":
		var back := button("← Главное меню",show_page.bind("home"))
		back.custom_minimum_size.y = 48
		header.add_child(back)
		buttons["back"] = back
	match page:
		"home": _home()
		"modes": _modes()
		"free": _free()
		"settings": _settings()
	_resize()

func _heading(text: String, description: String) -> void:
	title_label = label(text,44)
	content.add_child(title_label)
	if not description.is_empty(): content.add_child(label(description,16,MUTED))

func _home() -> void:
	header.hide()
	brand.reparent(self, false)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading("Арена ждёт.", "")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", heading_font)
	var subtitle := label("Выберите действие, чтобы начать игру",15,Color("8caed6"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	home_grid = GridContainer.new()
	home_grid.columns = 1
	home_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(home_grid)
	for entry in [["free","Свободный бой","play"],["modes","Выбор режима","modes"],["settings","Настройки","settings"],["exit","Выход","exit"]]:
		var action: Callable = show_page.bind(entry[0])
		if entry[0] == "exit": action = func() -> void: quit_requested.emit()
		var item := Button.new()
		item.set_script(preload("res://scripts/menu_action_button.gd"))
		item.text = entry[1]
		item.add_theme_font_override("font", heading_font)
		item.icon_kind = entry[2]
		item.primary = entry[0] == "free"
		item.danger = entry[0] == "exit"
		item.custom_minimum_size.y = 58 if item.primary else 50
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item.pressed.connect(action)
		home_grid.add_child(item)
		buttons[entry[0]] = item

func _modes() -> void:
	_heading("Выбор режима","")
	var play := button("Основная кампания",func() -> void: battle_requested.emit(LEVEL.roster(),&"teams","Кампания · 01"),GOLD,true)
	content.add_child(play)
	buttons["campaign"] = play
	buttons["level_01"] = play

func _settings() -> void:
	_heading("Настройки","Этот раздел готов для будущих параметров игры.")
	var box := card(content)
	box.add_child(label("Скоро",28,GOLD))
	box.add_child(label("Звук, графика и другие настройки появятся здесь в следующем обновлении.",18,MUTED))

func _free() -> void:
	_heading("Свободный бой","")
	selector = Control.new()
	selector.set_script(preload("res://scripts/mobile_battle_setup.gd"))
	selector.counts = free_counts
	selector.selections = free_selections.duplicate()
	selector.mode = format
	content.add_child(selector)
	selector.selection_changed.connect(func(side: int,id: StringName) -> void: free_selections[side] = id)
	selector.mode_changed.connect(func(value: StringName) -> void: format = value)
	selector.roster_requested.connect(_roster_ready)
	free_start = selector.start_button
	selector.column.remove_child(free_start)
	sticky_footer = PanelContainer.new()
	sticky_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sticky_footer.offset_top = -76
	sticky_footer.offset_bottom = -12
	var footer_style := _style(BLUE)
	footer_style.bg_color = Color("090f1b")
	footer_style.set_border_width_all(0)
	footer_style.content_margin_left = 0
	footer_style.content_margin_right = 0
	footer_style.content_margin_top = 4
	footer_style.content_margin_bottom = 4
	sticky_footer.add_theme_stylebox_override("panel",footer_style)
	add_child(sticky_footer)
	sticky_footer.add_child(free_start)
	scroll.offset_bottom = -88
	status_label = selector.status_label
	buttons["start_free"] = free_start

func _roster_ready(roster: Array[Dictionary], battle_format: StringName, title: String) -> void:
	last_roster = roster.duplicate(true)
	battle_requested.emit(roster,battle_format,title)

func _set_count(value: float,id: String,side: int) -> void:
	if is_instance_valid(selector): selector.set_count(id,side,int(value))

func _validate_free() -> void:
	if is_instance_valid(selector): selector.refresh()

func _start_free() -> void:
	if is_instance_valid(selector): selector.start_battle()

func _resize() -> void:
	if not is_inside_tree() or not is_instance_valid(content): return
	var screen := get_viewport_rect().size
	var wide := LAYOUT.landscape(screen)
	var limit := (1000.0 if page == "free" else 680.0) if wide else 460.0
	if page == "home": limit = 404.0
	var width := clampf(screen.x - 32.0, 240.0, limit)
	content.custom_minimum_size.x = width
	content.add_theme_constant_override("separation", 8 if wide else 14)
	for side in ["top", "bottom"]: padding.add_theme_constant_override("margin_" + side, 12 if wide else 20)
	header.vertical = not wide
	brand.text = "Свободный бой" if wide and page == "free" else "B A L L A R E N A"
	if buttons.has("back"):
		buttons["back"].text = "← Меню" if wide else "← Главное меню"
		buttons["back"].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_EXPAND_FILL
	if is_instance_valid(home_grid):
		home_grid.columns = 1
		brand.position = Vector2(36 if wide else 20, 22)
		brand.size = Vector2(260, 26)
		brand.add_theme_font_size_override("font_size", 14)
		title_label.add_theme_color_override("font_color", Color("e5efff"))
	if is_instance_valid(selector):
		if selector.modes.get_parent() != (header if wide else selector.column):
			selector.modes.reparent(header if wide else selector.column, false)
			if not wide: selector.column.move_child(selector.modes, 0)
		selector.modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.set_landscape(wide)
	if is_instance_valid(sticky_footer):
		var inset := (screen.x - width) * 0.5
		sticky_footer.offset_left = inset
		sticky_footer.offset_right = -inset
		sticky_footer.offset_top = -64 if wide else -76
		sticky_footer.offset_bottom = -8 if wide else -12
		free_start.custom_minimum_size.y = 48 if wide else 56
		scroll.offset_bottom = -68 if wide else -88
	if is_instance_valid(title_label):
		title_label.visible = not (wide and page == "free")
		title_label.add_theme_font_size_override("font_size", (40 if width < 340 else 46) if page == "home" else (28 if width < 340 else 32))
