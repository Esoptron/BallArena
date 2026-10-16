extends Control
## Screen-space cards beside a landscape arena, populated by abilities rather than hero IDs.
const LAYOUT := preload("res://scripts/screen_layout.gd")
const NAMES := preload("res://scripts/ui/character_text.gd").NAMES
var arena: BallArena
var camera: Camera2D
var cards: Array[PanelContainer] = []
var labels: Array[Label] = []
var actors: Array[ArenaBall] = []
var _elapsed := 0.0
var _refresh_pending := false
var _layout_screen := Vector2(-1,-1)
var _layout_transform := Transform2D()
var _layout_zoom := Vector2.ZERO
var _layout_arena_size := Vector2.ZERO
var speed_box: VBoxContainer
var speed_labels: Array[Label] = []

static func required_height(width: float) -> float:
	return 172.0 if width < 600.0 else 90.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	actors = [arena.get_node("Balls/BlueBall"), arena.get_node("Balls/RedBall")]
	for index in 2:
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101827")
		style.border_color = Color("35598a") if index == 0 else Color("7c3544")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		add_child(card)
		cards.append(card)
		card.minimum_size_changed.connect(_invalidate_layout)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)
		var title := Label.new()
		title.text = ("ТВОЙ · " if index == 0 else "ПРОТИВНИК · ") + NAMES.get(String(actors[index].character_id), actors[index].character_definition.display_name)
		if arena.fighters.size() > 2:
			title.text = "УЧАСТНИКИ" if arena.battle_format == &"ffa" else ("СИНИЕ" if index == 0 else "КРАСНЫЕ")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", Color("83b2ff") if index == 0 else Color("ff8491"))
		box.add_child(title)
		var values := Label.new()
		values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		values.add_theme_font_size_override("font_size", 13 if arena.fighters.size() > 2 else 15)
		values.add_theme_color_override("font_color", Color("e9effc"))
		box.add_child(values)
		labels.append(values)
	speed_box = VBoxContainer.new()
	speed_box.set_as_top_level(true)
	speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_box.add_theme_constant_override("separation", 2)
	add_child(speed_box)
	for index in 2:
		var speed := Label.new()
		speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		speed.add_theme_color_override("font_color", Color("83b2ff") if index == 0 else Color("ff8491"))
		speed.add_theme_color_override("font_outline_color", Color("080c14"))
		speed.add_theme_constant_override("outline_size", 3)
		speed_box.add_child(speed)
		speed_labels.append(speed)
	arena.director.event_recorded.connect(_on_event)
	refresh()

func _invalidate_layout() -> void:
	# Wrapped text can change minimum height after container sorting.
	_layout_screen = Vector2(-1, -1)

func _process(delta: float) -> void:
	layout()
	_elapsed += delta
	if _refresh_pending or _elapsed >= 0.1:
		_elapsed = 0.0
		refresh()

func _on_event(event: Dictionary) -> void:
	if event.get("kind") == "hit":
		# Mass battles share one screen update; preserve the immediate duel API.
		if arena.fighters.size() > 2:
			_refresh_pending = true
		else:
			refresh()

func refresh() -> void:
	_refresh_pending = false
	if arena.fighters.size() > 2:
		_refresh_group()
		return
	for index in actors.size():
		speed_labels[index].text = str(roundi(actors[index].actual_movement_speed()))
		var rows := PackedStringArray()
		for child in actors[index].get_children():
			if child is CombatAbility and child.is_enabled():
				for stat in child.progression_stats():
					rows.append(format_stat(stat))
		labels[index].text = "Нет усилений за попадание" if rows.is_empty() else "\n".join(rows)

func format_stat(stat: Dictionary) -> String:
	var value := float(stat["value"])
	var gain := maxf(0.0, value - float(stat["base"]))
	match stat["format"]:
		"percent": return "%s  %.0f%%  (+%.0f п.п.)" % [stat["label"], value * 100.0, gain * 100.0]
		"rotation": return "%s  %.1f об/с  (+%.1f)" % [stat["label"], value / TAU, gain / TAU]
		"speed": return "%s  %.0f ед/с  (+%.0f)" % [stat["label"], value, gain]
	return "%s  %.0f  (+%.0f)" % [stat["label"], value, gain]

func layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var transform := get_viewport().get_canvas_transform() * arena.global_transform
	if screen == _layout_screen and transform == _layout_transform and camera.zoom == _layout_zoom and arena.arena_size == _layout_arena_size:
		return
	_layout_screen = screen
	_layout_transform = transform
	_layout_zoom = camera.zoom
	_layout_arena_size = arena.arena_size
	var bottom := transform * arena.arena_size
	var top_left := transform * Vector2.ZERO
	var narrow := screen.x < 600.0
	speed_box.global_position = Vector2(bottom.x - 78.0, top_left.y + 12.0)
	speed_box.size = Vector2(60, 50)
	for label in speed_labels:
		label.add_theme_font_size_override("font_size", 14 if narrow else 18)
	if LAYOUT.landscape(screen):
		position = Vector2.ZERO
		size = screen
		var card_width := LAYOUT.side_width(screen)
		for index in 2:
			cards[index].position = Vector2(LAYOUT.EDGE if index == 0 else screen.x - LAYOUT.EDGE - card_width, maxf(LAYOUT.BATTLE_TOP, (top_left.y + bottom.y) * 0.5 - 96.0))
			cards[index].size = Vector2(card_width, 192)
		return
	var width := minf(screen.x - 32.0, maxf(bottom.x - top_left.x, 560.0))
	position = Vector2((screen.x - width) * 0.5, bottom.y + maxf(26.0, 36.0 * camera.zoom.x + 8.0))
	size = Vector2(width, required_height(screen.x))
	for index in 2:
		cards[index].position = Vector2(0, index * 90.0) if narrow else Vector2(index * (width + 12.0) * 0.5, 0)
		cards[index].size = Vector2(width, 82.0) if narrow else Vector2((width - 12.0) * 0.5, 90.0)


func _refresh_group() -> void:
	for index in 2:
		var team: StringName = &"blue" if index == 0 else &"red"
		var members: Array[ArenaBall] = []
		var total := 0
		var alive := 0
		var hp := 0
		var speed := 0.0
		for fighter in arena.fighters:
			if arena.battle_format != &"ffa" and fighter.team_id != team: continue
			members.append(fighter)
			total += 1
			if fighter.current_health > 0:
				alive += 1
				hp += fighter.current_health
				speed += fighter.actual_movement_speed()
		speed_labels[index].text = str(roundi(speed/maxi(1,alive)))
		labels[index].text = "В бою: %d / %d\nЗдоровье: %d" % [alive,total,hp]
		if arena.battle_format != &"ffa" and members.size() == 1:
			var lines := PackedStringArray(["В бою: %d / %d · HP: %d" % [alive,total,hp]])
			for ability in members[0].get_children():
				if ability is CombatAbility and ability.is_enabled():
					for stat in ability.progression_stats(): lines.append(format_stat(stat))
			labels[index].text = "\n".join(lines)
		if arena.battle_format == &"ffa" and index == 1:
			labels[index].text = "Каждый за себя\nПобеждает последний герой"
