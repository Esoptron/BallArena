extends Control
signal roster_requested(roster: Array[Dictionary], format: StringName, title: String)
signal selection_changed(side: int, id: StringName)
signal mode_changed(format: StringName)
const TEXTS := preload("res://scripts/ui/character_text.gd")
const PORTRAITS := preload("res://scripts/ui/portrait_preview.gd")
const STYLES := preload("res://scripts/ui/menu_styles.gd")
const FLAME := preload("res://scripts/copy_flame.gd")
const BLUE := Color("83b2ff")
const RED := Color("ff8491")
var counts: Dictionary = {}
var selections: Array[StringName] = [&"swordsman",&"vampire"]
var mode: StringName = &"teams"
var ids: Array[String] = []
var panels: Array[Dictionary] = []
var mode_buttons: Array[Button] = []
var start_button: Button
var status_label: Label
var column: VBoxContainer
var modes: HBoxContainer
var cards: BoxContainer
var landscape_layout := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	ids = CharacterCatalog.ids()
	get_viewport().size_changed.connect(_refresh_preview_resolutions)
	for id in ids:
		if not counts.has(id): counts[id] = [0,0]
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation",10)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(column)
	column.resized.connect(_height_changed)
	modes = HBoxContainer.new()
	modes.add_theme_constant_override("separation",8)
	column.add_child(modes)
	for index in 2:
		var button := _button("Две команды" if index == 0 else "Каждый за себя",set_mode.bind(&"teams" if index == 0 else &"ffa"))
		button.add_theme_font_size_override("font_size",14)
		modes.add_child(button)
		mode_buttons.append(button)
	cards = BoxContainer.new()
	cards.vertical = true
	cards.add_theme_constant_override("separation", 10)
	column.add_child(cards)
	for side in 2: _build_side(side)
	status_label = _label("",13,Color("9aa9c0"))
	column.add_child(status_label)
	start_button = _button("НАЧАТЬ БОЙ  →",start_battle)
	start_button.custom_minimum_size.y = 56
	column.add_child(start_button)
	for side in 2: select_character(side,selections[side],false)
	refresh()

func _height_changed() -> void:
	custom_minimum_size.y = column.size.y

func _style(accent: Color = Color("34445e"), fill: Color = Color("131f32")) -> StyleBoxFlat:
	return STYLES.box(fill, accent, 14, 12, 8)

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(48,48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",17)
	button.add_theme_stylebox_override("normal",_style())
	button.add_theme_stylebox_override("hover",_style(BLUE,Color("203857")))
	button.add_theme_stylebox_override("pressed",_style(BLUE,Color("193564")))
	var focus := _style(BLUE,Color.TRANSPARENT)
	button.add_theme_stylebox_override("focus",focus)
	button.pressed.connect(action)
	return button

func _label(text: String, size: int, color: Color = Color("eef3ff")) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label

func _build_side(side: int) -> void:
	var accent := BLUE if side == 0 else RED
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",_style(accent.darkened(0.55),Color("101827")))
	cards.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation",5)
	panel.add_child(box)
	var heading := _label("",12,accent)
	box.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	box.add_child(row)
	var previous := _button("‹",cycle.bind(side,-1))
	previous.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	previous.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(previous)
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size.y = 110
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.clip_contents = true
	row.add_child(stage)
	var portrait := TextureRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(portrait)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240,110)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	portrait.add_child(viewport)
	portrait.texture = viewport.get_texture()
	var badge := Control.new()
	badge.set_script(FLAME)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-54,0)
	badge.size = Vector2(54,62)
	stage.add_child(badge)
	var next := _button("›",cycle.bind(side,1))
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(next)
	var title := _label("",19)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var stats := _label("",12,accent)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	var description := _label("",12,Color("9aa9c0"))
	description.max_lines_visible = 1
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(description)
	var quantity := HBoxContainer.new()
	quantity.add_theme_constant_override("separation",8)
	box.add_child(quantity)
	var minus := _button("−",change_count.bind(side,-1))
	minus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quantity.add_child(minus)
	var quantity_label := _label("Копии персонажа",13,Color("9aa9c0"))
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity.add_child(quantity_label)
	var plus := _button("+",change_count.bind(side,1))
	plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quantity.add_child(plus)
	var summary := _label("",11,Color("9aa9c0"))
	box.add_child(summary)
	panels.append({"box":box,"panel":panel,"heading":heading,"stage":stage,"portrait":portrait,"viewport":viewport,"badge":badge,
		"title":title,"stats":stats,"description":description,"summary":summary,"minus":minus,"plus":plus,
		"fighter":null,"outgoing":null,"tween":null,"touch_index":-1,"drag":0.0,"drag_y":0.0})
	stage.resized.connect(_position_portrait.bind(side))
	stage.gui_input.connect(_swipe_input.bind(side))

func cycle(side: int, direction: int) -> void:
	if side < 0 or side >= panels.size() or ids.is_empty():
		return
	var index := ids.find(String(selections[side]))
	select_character(side,StringName(ids[posmod(index+direction,ids.size())]),true,direction)

func select_character(side: int, id: StringName, animate: bool = true, direction: int = 1) -> void:
	if side < 0 or side >= panels.size() or not ids.has(String(id)):
		return
	selections[side] = id
	selection_changed.emit(side,id)
	var info: Dictionary = panels[side]
	_update_preview_resolution(info)
	if info["tween"] != null and info["tween"].is_valid(): info["tween"].kill()
	if is_instance_valid(info["outgoing"]): info["outgoing"].queue_free()
	var old: ArenaBall = info["fighter"]
	var profile := CharacterCatalog.character(id)
	var fighter := PORTRAITS.create(info["viewport"], profile, side)
	_portrait_style(fighter, id)

	if fighter.has_node("Knives"): fighter.get_node("Knives").rotation = 0.0
	info["fighter"] = fighter
	info["title"].text = TEXTS.NAMES.get(String(id),profile.display_name)
	info["description"].text = TEXTS.DESCRIPTIONS.get(String(id),"")
	info["stats"].text = "%d HP · %s" % [profile.starting_health,TEXTS.weight_name(profile.weight_class)]
	_position_portrait(side)
	if animate:
		info["outgoing"] = old
		var center := fighter.position
		fighter.position.x += direction*36.0
		fighter.modulate.a = 0.0
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(fighter,"position",center,0.20)
		tween.tween_property(fighter,"modulate:a",1.0,0.20)
		if is_instance_valid(old):
			tween.tween_property(old,"position:x",center.x-direction*36.0,0.16)
			tween.tween_property(old,"modulate:a",0.0,0.16)
			tween.chain().tween_callback(old.queue_free)
		info["tween"] = tween
	else:
		if is_instance_valid(old): old.queue_free()
		info["outgoing"] = null
	refresh()

func _position_portrait(side: int) -> void:
	if side >= panels.size(): return
	var info: Dictionary = panels[side]
	_update_preview_resolution(info)
	if info["tween"] != null and info["tween"].is_valid():
		info["tween"].kill()
		info["tween"] = null
		if is_instance_valid(info["outgoing"]): info["outgoing"].queue_free()
		if is_instance_valid(info["fighter"]): info["fighter"].modulate.a = 1.0
	if is_instance_valid(info["fighter"]):
		var fighter: ArenaBall = info["fighter"]
		var stage_width: float = info["stage"].size.x
		fighter.position = Vector2(stage_width*.5,60 if landscape_layout else 76)
		if fighter.character_id == &"club" and stage_width > 0:
			# Fit the enlarged weapon in phone cards without cropping its head.
			var club := fighter.get_node("Club") as ClubAbility
			var reach := fighter.visual_diameter()*.5+(13*fighter.diameter/70+club.blade_length)*club.weapon_scale
			var projection := absf(cos(club.rotation))*reach+club.weapon_radius()+3
			fighter.position.x += 6
			var fit := (stage_width*.5+4)/projection
			fighter.scale = Vector2.ONE*minf(.76 if landscape_layout else .74,fit)
	info["badge"].position = Vector2(info["stage"].size.x-54,0)

func _refresh_preview_resolutions() -> void:
	for info in panels: _update_preview_resolution(info)

func _update_preview_resolution(info: Dictionary) -> void:
	# Render only the two menu portraits at display density. Keep world coordinates
	# and the nearest-filtered pixel style; never upscale a tiny logical buffer.
	var stage_size: Vector2 = info["stage"].size
	if stage_size.x <= 0 or stage_size.y <= 0: return
	var logical_size := get_viewport_rect().size
	if logical_size.x <= 0 or logical_size.y <= 0:
		return
	var physical_size := Vector2(get_window().size)
	var density := clampf(maxf(physical_size.x/logical_size.x,physical_size.y/logical_size.y),2.0,3.0)
	var viewport: SubViewport = info["viewport"]
	var buffer_size := Vector2i((stage_size*density).ceil())
	if viewport.size != buffer_size:
		viewport.size = buffer_size
	var transform := Transform2D.IDENTITY.scaled(Vector2.ONE*density)
	if viewport.canvas_transform != transform:
		viewport.canvas_transform = transform

func set_landscape(value: bool) -> void:
	if landscape_layout == value: return
	landscape_layout = value
	cards.vertical = not value
	status_label.visible = not value
	for side in 2:
		var info: Dictionary = panels[side]
		info["box"].add_theme_constant_override("separation", 3 if value else 5)
		info["stage"].custom_minimum_size.y = 96 if value else 110
		info["description"].visible = not value
		info["summary"].max_lines_visible = 1 if value else -1
		info["summary"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if value else TextServer.OVERRUN_NO_TRIMMING
		if is_instance_valid(info["fighter"]): _portrait_style(info["fighter"], selections[side])
		_position_portrait(side)

func _portrait_style(fighter: ArenaBall, id: StringName) -> void:
	var portrait_scale := 0.60 if id == &"katana" else (0.72 if id == &"swordsman" else (0.88 if id == &"knifeman" else 0.78))
	if landscape_layout: portrait_scale = 0.70 if id == &"katana" else (0.78 if id == &"swordsman" else (0.98 if id == &"knifeman" else 0.84))
	if id == &"club": portrait_scale = 0.76 if landscape_layout else 0.74
	fighter.scale = Vector2.ONE * portrait_scale
	var angle := -PI * (0.86 if landscape_layout else 0.75)
	fighter.get_node("Sword").rotation = angle
	if fighter.has_node("Katana"): fighter.get_node("Katana").rotation = angle
	if fighter.has_node("Club"): fighter.get_node("Club").rotation = -PI*0.90

func _swipe_input(event: InputEvent, side: int) -> void:
	var info: Dictionary = panels[side]
	if event is InputEventScreenTouch:
		if event.pressed:
			if info["touch_index"] != -1: return
			info["touch_index"] = event.index
			info["drag"] = 0.0
			info["drag_y"] = 0.0
		elif info["touch_index"] == event.index: _finish_swipe(side)
	elif event is InputEventScreenDrag and event.index == info["touch_index"]:
		info["drag"] += event.relative.x
		info["drag_y"] += event.relative.y
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			info["touch_index"] = -2
			info["drag"] = 0.0
			info["drag_y"] = 0.0
		elif info["touch_index"] == -2: _finish_swipe(side)
	elif event is InputEventMouseMotion and info["touch_index"] == -2:
		info["drag"] += event.relative.x
		info["drag_y"] += event.relative.y

func _finish_swipe(side: int) -> void:
	var info: Dictionary = panels[side]
	if absf(info["drag"]) >= 30 and absf(info["drag"]) > absf(info["drag_y"]): cycle(side,1 if info["drag"] < 0 else -1)
	info["touch_index"] = -1
	info["drag"] = 0.0
	info["drag_y"] = 0.0

func set_mode(value: StringName) -> void:
	if value not in [&"teams",&"ffa"]: return
	mode = value
	mode_changed.emit(mode)
	refresh()

func total_count() -> int:
	var total := 0
	for pair in counts.values(): total += pair[0]+pair[1]
	return total

func battle_roster() -> Array[Dictionary]:
	# Explicit copies replace the preview on that side, never add to it.
	var roster: Array[Dictionary] = []
	var side_totals := [0,0]
	for side in 2:
		for id in ids:
			for copy in counts[id][side]:
				roster.append({"character":id,"team":"blue" if side == 0 else "red"})
				side_totals[side] += 1
	# FFA needs no opposing team once two explicit fighters have been added.
	if mode == &"ffa" and roster.size() >= 2: return roster
	for side in 2:
		if side_totals[side] == 0:
			roster.append({"character":String(selections[side]),"team":"blue" if side == 0 else "red"})
	return roster

func set_count(id: String, side: int, amount: int) -> void:
	if not counts.has(id) or side < 0 or side > 1: return
	var other_total := 0
	for pair in counts.values(): other_total += pair[1-side]
	var reserved := 1 if mode == &"teams" and other_total == 0 else 0
	var available := maxi(0,20-reserved-total_count()+int(counts[id][side]))
	counts[id][side] = clampi(amount,0,available)
	refresh()

func change_count(side: int, delta: int) -> void:
	if side < 0 or side >= selections.size():
		return
	var id := String(selections[side])
	set_count(id,side,int(counts[id][side])+delta)

func refresh() -> void:
	if not is_instance_valid(start_button): return
	var roster := battle_roster()
	var total := roster.size()
	var teams := [0,0]
	for pair in counts.values():
		teams[0] += pair[0]
		teams[1] += pair[1]
	var valid: bool = total >= 2 and total <= 20
	start_button.disabled = not valid
	var problem := "Освободи место для соперника" if total > 20 else "Нужно хотя бы два героя"
	start_button.text = "НАЧАТЬ БОЙ · %d/20" % total if valid else problem
	start_button.add_theme_stylebox_override("normal",_style(BLUE,Color("193564")))
	for index in 2:
		mode_buttons[index].add_theme_stylebox_override("normal",_style(BLUE if (mode == &"teams") == (index == 0) else Color("34445e"),Color("193564") if (mode == &"teams") == (index == 0) else Color("131f32")))
		var info: Dictionary = panels[index]
		var id := String(selections[index])
		info["heading"].text = ("СИНИЕ" if index == 0 else "КРАСНЫЕ") if mode == &"teams" else "СОСТАВ %d" % (index+1)
		info["badge"].set_count(counts[id][index])
		info["badge"].visible = counts[id][index] > 0
		info["minus"].disabled = counts[id][index] <= 0
		info["plus"].disabled = total >= 20 and not (mode == &"teams" and teams[index] == 0)
		var pieces := PackedStringArray()
		for hero in ids:
			if counts[hero][index] > 0: pieces.append("%s ×%d" % [TEXTS.NAMES.get(hero,hero),counts[hero][index]])
		info["summary"].text = "В бой: %s" % TEXTS.NAMES.get(id,id) if pieces.is_empty() and (mode == &"teams" or total_count() < 2) else ("Состав пуст" if pieces.is_empty() else " · ".join(pieces))
	status_label.text = "%d / 20 участников" % total
	if not valid: status_label.text += " · " + problem

func start_battle() -> void:
	refresh()
	if start_button.disabled: return
	roster_requested.emit(battle_roster(),mode,"Свободный бой")
