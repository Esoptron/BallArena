extends Node
const MATCH := preload("res://scenes/main.tscn")
var menu: Control
var front_menu: Control
var battle: Node2D
var hud: CanvasLayer
var selected_player: StringName = &"swordsman"
var selected_opponent: StringName = &"vampire"
var winner_label: Label
var replay: Button
var match_finished: bool = false
var return_screen: String = "home"
var last_roster: Array[Dictionary] = []
var last_format: StringName = &"teams"
var last_title: String = "Дуэль"

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	add_child(layer)
	menu = Control.new()
	menu.set_script(preload("res://scripts/character_selection.gd"))
	menu.lazy_ui = true
	layer.add_child(menu)
	menu.battle_requested.connect(start_battle)
	menu.back_requested.connect(_close_duel)
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	front_menu = Control.new()
	front_menu.set_script(preload("res://scripts/front_menu.gd"))
	layer.add_child(front_menu)
	front_menu.battle_requested.connect(start_roster_battle)
	front_menu.duel_requested.connect(open_duel)
	front_menu.quit_requested.connect(func() -> void: get_tree().quit())

func open_duel() -> void:
	menu.ensure_ui()
	front_menu.hide()
	front_menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.process_mode = Node.PROCESS_MODE_INHERIT
	menu.show()
	return_screen = "duel"

func _close_duel() -> void:
	menu.hide()
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	front_menu.process_mode = Node.PROCESS_MODE_INHERIT
	front_menu.show()
	front_menu.show_page("free")

func start_battle(player_id: StringName, opponent_id: StringName) -> void:
	selected_player = player_id
	selected_opponent = opponent_id
	return_screen = "duel"
	last_roster.clear()
	last_title = "Дуэль"
	_create_battle()

func start_roster_battle(roster: Array[Dictionary], format: StringName, title: String) -> void:
	if roster.size() < 2 or roster.size() > 20: return
	last_roster = roster.duplicate(true)
	last_format = format
	last_title = title
	return_screen = front_menu.page
	_create_battle()

func _create_battle() -> void:
	for screen in [menu,front_menu]:
		screen.hide()
		screen.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(battle):
		remove_child(battle)
		battle.queue_free()
	if is_instance_valid(hud):
		remove_child(hud)
		hud.queue_free()
	Engine.time_scale = 1.0
	battle = MATCH.instantiate()
	var arena := battle.get_node("Arena") as BallArena
	if last_roster.is_empty():
		arena.blue_character_id = selected_player
		arena.red_character_id = selected_opponent
	else:
		arena.battle_roster = last_roster.duplicate(true)
		arena.battle_format = last_format
	arena.randomize_spawns = true
	add_child(battle)
	match_finished = false
	_build_hud()
	arena.director.match_finished.connect(_on_battle_finished)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "BattleHUD"
	add_child(hud)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = 8 if preload("res://scripts/screen_layout.gd").landscape(get_viewport().get_visible_rect().size) else 12
	bar.add_theme_constant_override("separation",8)
	hud.add_child(bar)
	var back: Button = menu._button("← Меню",return_color())
	back.custom_minimum_size.y = 44
	back.add_theme_font_size_override("font_size",15)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(return_to_menu)
	bar.add_child(back)
	winner_label = Label.new()
	winner_label.text = last_title
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.clip_text = true
	winner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	winner_label.add_theme_font_size_override("font_size",16)
	bar.add_child(winner_label)
	replay = menu._button("Заново ↻",return_color())
	replay.custom_minimum_size.y = 44
	replay.add_theme_font_size_override("font_size",15)
	replay.size_flags_horizontal = Control.SIZE_SHRINK_END
	replay.pressed.connect(_create_battle)
	bar.add_child(replay)

func return_color() -> Color:
	return Color("83b2ff")

func _on_battle_finished(team: StringName) -> void:
	if match_finished: return
	match_finished = true
	if team == &"": winner_label.text = "НИЧЬЯ"
	elif last_format == &"ffa" and not last_roster.is_empty():
		var arena := battle.get_node("Arena") as BallArena
		for fighter in arena.fighters:
			if fighter.current_health > 0:
				winner_label.text = front_menu.NAMES.get(String(fighter.character_id),"Победитель")
				winner_label.add_theme_color_override("font_color",fighter.ball_color)
	else:
		if last_title == "Свободный бой": winner_label.text = "СИНИЕ ПОБЕДИЛИ" if team == &"blue" else "КРАСНЫЕ ПОБЕДИЛИ"
		else: winner_label.text = "ПОБЕДА" if team == &"blue" else "ПОРАЖЕНИЕ"
	if get_viewport().get_visible_rect().size.x < 600: winner_label.add_theme_font_size_override("font_size",12)
	if last_roster.is_empty() or last_format != &"ffa":
		winner_label.add_theme_color_override("font_color",Color("83b2ff") if team == &"blue" else Color("ff8491"))

func return_to_menu() -> void:
	if is_instance_valid(battle):
		remove_child(battle)
		battle.queue_free()
		battle = null
	if is_instance_valid(hud):
		remove_child(hud)
		hud.queue_free()
		hud = null
	Engine.time_scale = 1.0
	if return_screen == "duel": open_duel()
	else:
		menu.hide()
		menu.process_mode = Node.PROCESS_MODE_DISABLED
		front_menu.process_mode = Node.PROCESS_MODE_INHERIT
		front_menu.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"): return
	if is_instance_valid(battle): return_to_menu()
	elif menu.visible:
		menu.hide()
		menu.process_mode = Node.PROCESS_MODE_DISABLED
		front_menu.process_mode = Node.PROCESS_MODE_INHERIT
		front_menu.show()
		front_menu.show_page("free")
	else: front_menu.show_page("home")
