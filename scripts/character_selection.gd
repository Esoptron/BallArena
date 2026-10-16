extends Control
signal battle_requested(player_id: StringName, opponent_id: StringName)
signal back_requested
const TEXTS := preload("res://scripts/ui/character_text.gd")
const PORTRAITS := preload("res://scripts/ui/portrait_preview.gd")
const STYLES := preload("res://scripts/ui/menu_styles.gd")
const BLUE := Color("5d9dff")
const RED := Color("ff6977")
const INK := Color("101827")
const TEXT := Color("e9effc")
const MUTED := Color("93a3bd")
const NAMES := TEXTS.NAMES
const DESCRIPTIONS := TEXTS.DESCRIPTIONS
var lazy_ui: bool = false
var _catalog_ids: Array[String] = []
var selections: Array[StringName] = [&"swordsman", &"vampire"]
var panels: Array[Dictionary] = []
var cards: BoxContainer
var content: VBoxContainer
var scroll: ScrollContainer
var start_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	self.theme = theme
	if not lazy_ui: ensure_ui()

func ensure_ui() -> void:
	if cards != null: return
	_catalog_ids = CharacterCatalog.ids()
	_build()
	get_viewport().size_changed.connect(_resize)
	_resize()
	for side in 2:
		select_character(side, selections[side])

func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 18) -> StyleBoxFlat:
	return STYLES.box(color, border, radius, 18, 14)

func _label(text: String, size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_constant_override("line_spacing", 0)
	label.add_theme_constant_override("paragraph_spacing", 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(text: String, accent: Color) -> Button:
	return STYLES.battle_button(text, accent)

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("090f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	content.add_child(_label("B A L L A R E N A", 18, Color("bbcbed")))
	content.add_child(_button("← Свободный бой",BLUE))
	content.get_child(content.get_child_count()-1).pressed.connect(func() -> void: back_requested.emit())
	content.add_child(_label("ВЫБОР ПЕРСОНАЖЕЙ", 12, Color("d6ad65")))
	content.add_child(_label("Кто выйдет на арену?", 34))
	content.add_child(_label("Выбери своего героя и соперника. Дальше они сражаются сами.", 16, MUTED))
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 20)
	content.add_child(cards)
	for side in 2:
		_build_side(side)
	content.add_child(_label("VS", 18, Color("d6ad65")))
	start_button = _button("НАЧАТЬ БОЙ  →", Color("83b2ff"))
	start_button.custom_minimum_size.y = 62
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.add_theme_stylebox_override("normal", _style(Color("305ca9"), Color("6f9fef"), 14))
	start_button.pressed.connect(func() -> void: battle_requested.emit(selections[0], selections[1]))
	content.add_child(start_button)
	content.add_child(_label("Случайные стартовые позиции · Можно выбрать одинаковых героев", 13, MUTED))

func _build_side(side: int) -> void:
	var accent := BLUE if side == 0 else RED
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(INK, accent.darkened(0.58), 22))
	cards.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(_label("ТВОЙ ПЕРСОНАЖ" if side == 0 else "ПРОТИВНИК", 13, accent))
	var portrait := SubViewportContainer.new()
	portrait.custom_minimum_size = Vector2(0, 200 if _catalog_ids.size() >= 5 else 240)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.stretch = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 200 if _catalog_ids.size() >= 5 else 240)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	portrait.add_child(viewport)
	var title := _label("", 27)
	column.add_child(title)
	var description := _label("", 15, MUTED)
	column.add_child(description)
	var stats := _label("", 14, accent.lightened(0.3))
	column.add_child(stats)
	var choices := GridContainer.new()
	choices.columns = 2 if _catalog_ids.size() > 3 else 3
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 8)
	column.add_child(choices)
	var buttons := {}
	for id in _catalog_ids:
		var choice := _button(NAMES.get(id, CharacterCatalog.character(id).display_name), accent)
		choice.custom_minimum_size.y = 44
		choice.add_theme_font_size_override("font_size", 14)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := choice.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			style.content_margin_left = 8
			style.content_margin_right = 8
			choice.add_theme_stylebox_override(state, style)
		choice.pressed.connect(select_character.bind(side, StringName(id)))
		choices.add_child(choice)
		buttons[id] = choice
	panels.append({"panel": panel, "viewport": viewport, "portrait": portrait, "title": title,
		"description": description, "stats": stats, "buttons": buttons, "fighter": null})
	portrait.resized.connect(_position_portrait.bind(side))

func select_character(side: int, id: StringName) -> void:
	if side < 0 or side >= panels.size() or not _catalog_ids.has(String(id)):
		return
	selections[side] = id
	var info: Dictionary = panels[side]
	var profile := CharacterCatalog.character(id)
	info["title"].text = NAMES.get(String(id), profile.display_name)
	info["description"].text = DESCRIPTIONS.get(String(id), "Новый герой арены")
	info["stats"].text = "%d HP    ·    Вес: %s" % [profile.starting_health, TEXTS.weight_name(profile.weight_class)]
	var accent := BLUE if side == 0 else RED
	for key in info["buttons"]:
		var button: Button = info["buttons"][key]
		var chosen: bool = key == String(id)
		var choice_style := _style(accent.darkened(0.73) if chosen else Color("182337"), accent if chosen else Color("2a3b56"), 12)
		choice_style.content_margin_left = 8
		choice_style.content_margin_right = 8
		button.add_theme_stylebox_override("normal", choice_style)
		button.add_theme_color_override("font_color", accent.lightened(0.25) if chosen else MUTED)
	if is_instance_valid(info["fighter"]):
		info["fighter"].queue_free()
	var fighter := PORTRAITS.create(info["viewport"], profile, side)
	fighter.scale = Vector2.ONE * (1.0 if _catalog_ids.size() >= 5 else 1.2)
	fighter.get_node("Sword").rotation = -PI * 0.5
	if fighter.has_node("Katana"):
		fighter.get_node("Katana").rotation = -PI * 0.25
	if fighter.has_node("Knives"):
		fighter.get_node("Knives").rotation = 0.0
	info["fighter"] = fighter
	_position_portrait(side)

func _position_portrait(side: int) -> void:
	if side >= panels.size():
		return
	var info: Dictionary = panels[side]
	if is_instance_valid(info["fighter"]):
		info["fighter"].position = Vector2(info["portrait"].size.x * 0.5, 154.0 if _catalog_ids.size() >= 5 else 182.0)

func _resize() -> void:
	if cards == null:
		return
	# Grid switches to two rows in portrait windows and on phones.
	var screen := get_viewport_rect().size
	var narrow := screen.x < 760.0 or screen.y > screen.x
	if cards.get_meta("narrow", false) != narrow:
		cards.set_meta("narrow", narrow)
		var replacement: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
		replacement.set_meta("narrow", narrow)
		replacement.add_theme_constant_override("separation", 20)
		var index := cards.get_index()
		content.remove_child(cards)
		for child in cards.get_children():
			cards.remove_child(child)
			replacement.add_child(child)
		cards.queue_free()
		content.add_child(replacement)
		content.move_child(replacement, index)
		# The field stores BoxContainer because orientation changes at runtime.
		cards = replacement
