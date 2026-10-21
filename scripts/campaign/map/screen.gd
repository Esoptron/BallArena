extends Control
signal home_requested
signal shop_requested
signal barracks_requested
signal bestiary_requested
signal result_requested
signal resume_requested
signal abandon_requested
signal retry_requested
signal level_requested(number: int)
const STYLES := preload("res://scripts/ui/menu_styles.gd")
const LEVEL := preload("res://scenes/campaign/level_node.tscn")
const DECOR := preload("res://scripts/campaign/map/decor.gd")
const BLUE := Color("89b9ef")
const GOLD := Color("edb16a")
var account: Dictionary = {}
var initial_center := -1.0
var warning := ""
var entries: Array[Dictionary] = []
var level_nodes: Array[Button] = []
var surface: Control
var upper: Node2D
var middle: Node2D
var lower: Node2D
var route: Node2D
var terminal: Control
var scroller: Node
var parallax: RefCounted
var left_button: Button
var right_button: Button
var _zoom := 1.0
var _y := 0.0
var _old_width := 0.0
var _laid_out := false

func _ready() -> void:
	if account.is_empty(): account = CampaignProgression.new_account()
	entries = CampaignMapData.entries(account)
	_build_hud()
	_build_map()
	surface.resized.connect(_layout)
	_layout.call_deferred()

func _label(text: String, font_size: int = 16, colour: Color = Color("eef1f6")) -> Label:
	var label := Label.new(); label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := STYLES.battle_button(text,BLUE)
	button.add_theme_font_size_override("font_size",16)
	button.custom_minimum_size = Vector2(52,52)
	button.pressed.connect(action); parent.add_child(button)
	return button

func _chip(parent: Node, text: String, colour: Color, tip: String = "") -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",STYLES.box(Color("162131"),Color("344154"),11,12,8))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.tooltip_text = tip
	var label := _label(text,16,colour); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label); parent.add_child(panel)

func _build_hud() -> void:
	var background := ColorRect.new(); background.color = Color("0b111c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin := MarginContainer.new(); margin.name = "MarginContainer"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var column := VBoxContainer.new(); column.name = "VBoxContainer"
	column.add_theme_constant_override("separation",8); margin.add_child(column)
	var header := HBoxContainer.new(); header.name = "StickyHUD"
	header.add_theme_constant_override("separation",8); column.add_child(header)
	var home := _button(header,"⌂",home_requested.emit); home.tooltip_text = "Главное меню"
	home.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var title := VBoxContainer.new(); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_child(_label("КАМПАНИЯ",16,GOLD))
	title.add_child(_label(CampaignProgression.data()["players"][account["selected_hero"]]["name"],13,BLUE)); header.add_child(title)
	_chip(header,"Энергия —",Color("8bc8c1"),"Система энергии пока не настроена. Вход в бой не расходует ресурсы.")
	_chip(header,"● "+CampaignEconomy.text(CampaignEconomy.wallet_units(account,"coins"),4),GOLD,"Монеты")
	_chip(header,"◆ %d"%account["crystals"],BLUE,"Кристаллы")
	_button(header,"Магазин",shop_requested.emit)
	if not warning.is_empty():
		var bar := HBoxContainer.new(); column.add_child(bar)
		var label := _label(warning,14,GOLD); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(label)
		_button(bar,"Сохранить ещё раз",retry_requested.emit)
	surface = Control.new(); surface.name = "MapViewport"
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.custom_minimum_size = Vector2(0,90); surface.clip_contents = true
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(surface)
	var footer := HBoxContainer.new(); footer.name = "StickyNavigation"
	footer.add_theme_constant_override("separation",8); column.add_child(footer)
	left_button = _button(footer,"‹",func() -> void: scroller.nudge(-1))
	left_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_button(footer,"Казарма",barracks_requested.emit)
	var run: Dictionary = account["active_run"]
	if run.is_empty():
		_button(footer,"К уровню %d"%CampaignMapData.current_level(account),func() -> void: focus_current(true))
	else:
		_button(footer,"Продолжить %d–%d"%[run["level"],run["battle"]],resume_requested.emit)
		_button(footer,"× Поход",abandon_requested.emit)
	_button(footer,"Бестиарий",bestiary_requested.emit)
	if run.is_empty() and not account["last_result"].is_empty(): _button(footer,"Итог",result_requested.emit)
	right_button = _button(footer,"›",func() -> void: scroller.nudge(1))
	right_button.size_flags_horizontal = Control.SIZE_SHRINK_END

func _build_map() -> void:
	upper = DECOR.new(); upper.name = "UpperBackground"; upper.kind = "upper"; surface.add_child(upper)
	middle = Node2D.new(); middle.name = "MiddleLevels"; surface.add_child(middle)
	route = preload("res://scripts/campaign/map/route.gd").new()
	route.entries = entries; middle.add_child(route)
	for entry in entries:
		var node := LEVEL.instantiate() as Button
		node.name = String(entry["id"])
		node.position = CampaignMapData.position_of(entry)-Vector2(80,148)
		middle.add_child(node); node.configure(entry,CampaignMapData.config()["chest_skins"])
		node.pressed.connect(_activate.bind(int(entry["level_number"])))
		level_nodes.append(node)
	terminal = preload("res://scripts/campaign/map/fog.gd").new()
	terminal.name = "TerminalFog"; terminal.position = CampaignMapData.end_position(entries)
	terminal.size = Vector2(CampaignMapData.config()["terminal"]["width"],CampaignMapData.config()["design_height"])
	middle.add_child(terminal)
	lower = DECOR.new(); lower.name = "LowerForeground"; lower.kind = "lower"; surface.add_child(lower)
	parallax = preload("res://scripts/campaign/map/parallax.gd").new()
	parallax.upper = upper; parallax.middle = middle; parallax.lower = lower
	parallax.ratios = CampaignMapData.config()["parallax"]
	scroller = preload("res://scripts/campaign/map/scroller.gd").new()
	scroller.surface = surface; scroller.settings = CampaignMapData.config()["scroll"]
	scroller.changed.connect(_scroll_changed); add_child(scroller)

func _layout() -> void:
	if scroller == null or surface.size.x < 1 or surface.size.y < 1: return
	var center := center_on_map() if _laid_out else initial_center
	_zoom = minf(float(CampaignMapData.config()["max_scale"]),surface.size.y/float(CampaignMapData.config()["design_height"]))
	_y = (surface.size.y-float(CampaignMapData.config()["design_height"])*_zoom)*0.5
	var width := terminal.position.x+terminal.size.x+56
	scroller.set_bounds(width*_zoom-surface.size.x)
	_old_width = surface.size.x
	_laid_out = true
	if center >= 0: scroller.jump(center*_zoom-surface.size.x*0.5)
	else: focus_current(false)

func center_on_map() -> float:
	return (float(scroller.offset)+_old_width*0.5)/_zoom if scroller != null and _laid_out else -1.0

func focus_current(smooth: bool) -> void:
	var x := 0.0
	for entry in entries:
		if int(entry["level_number"]) == CampaignMapData.current_level(account): x = CampaignMapData.position_of(entry).x
	var destination := x*_zoom-surface.size.x*0.5
	if smooth: scroller.go_to(destination)
	else: scroller.jump(destination)

func _activate(number: int) -> void:
	if scroller.suppress_click(): return
	for entry in entries:
		if int(entry["level_number"]) == number and entry["can_enter"]:
			level_requested.emit(number)
			return

func _scroll_changed(offset: float) -> void:
	parallax.apply(offset,_zoom,_y)
	var left := offset/_zoom
	var right := (offset+surface.size.x)/_zoom
	var theme: Dictionary = entries[0]["zone_theme"]
	for entry in entries:
		if CampaignMapData.position_of(entry).x <= (left+right)*0.5: theme = entry["zone_theme"]
	var top := -_y/_zoom; var bottom := (surface.size.y-_y)/_zoom
	for pair in [[upper,"upper"],[lower,"lower"]]:
		var ratio := float(parallax.ratios[pair[1]])
		pair[0].set_view(offset*ratio/_zoom,(offset*ratio+surface.size.x)/_zoom,top,bottom,theme)
	route.set_view(left,right)
	for index in level_nodes.size():
		var x := CampaignMapData.position_of(entries[index]).x
		level_nodes[index].set_animation_visible(x+90 >= left and x-90 <= right)
	terminal.set_animation_visible(terminal.position.x < right and terminal.position.x+terminal.size.x > left)
	left_button.disabled = offset <= 0.2
	right_button.disabled = offset >= float(scroller.maximum)-0.2
