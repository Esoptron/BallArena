extends Control
## Data-driven painted campaign map, with the original three-node study optional.
signal home_requested
signal back_requested
signal shop_requested
signal barracks_requested
signal bestiary_requested
signal level_requested(number: int)
signal result_requested
signal resume_requested
signal abandon_requested
signal retry_requested
const HUD := preload("res://scripts/campaign/map/art/hud.gd")
const SCENERY := preload("res://scripts/campaign/map/art/scenery.gd")
const POSITIONS := [Vector2(220,108),Vector2(650,175),Vector2(1080,90)]
const NUMBERS := [1,2,5]
@export var preview_mode := false
var account: Dictionary = {}
var initial_center := -1.0
var warning := ""
var entries: Array[Dictionary] = []
var level_nodes: Array[Button] = []
var surface: Control
var art_root: Control
var upper: Node2D
var middle: Node2D
var lower: Node2D
var scroller: Node
var parallax: RefCounted
var route: Node2D
var terminal: Control
var header: HBoxContainer
var footer: HBoxContainer
var left_button: Button
var right_button: Button
var first_button: Button
var last_button: Button
var _zoom := 1.0
var _previous_width := 0.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if account.is_empty(): account=CampaignProgression.new_account()
	var all := CampaignMapData.entries(account)
	if preview_mode:
		for index in NUMBERS.size():
			var entry: Dictionary=all[NUMBERS[index]-1].duplicate(true)
			entry["painted_position"]=[POSITIONS[index].x,POSITIONS[index].y]; entries.append(entry)
	else: entries=all
	art_root=Control.new(); art_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_root.mouse_filter=Control.MOUSE_FILTER_IGNORE; art_root.clip_contents=true; add_child(art_root)
	upper=SCENERY.new(); art_root.add_child(upper)
	middle=Node2D.new(); art_root.add_child(middle)
	route=preload("res://scripts/campaign/map/art/route.gd").new()
	for entry in entries: route.points.append(CampaignMapData.painted_position_of(entry))
	middle.add_child(route)
	for entry in entries:
		var node := preload("res://scripts/campaign/map/art/level_node.gd").new()
		node.name=entry["id"]; node.entry=entry
		node.position=CampaignMapData.painted_position_of(entry)-Vector2(150,0)
		node.pressed.connect(_activate.bind(int(entry["level_number"]))); middle.add_child(node); level_nodes.append(node)
	lower=SCENERY.new(); lower.asset="foreground"; art_root.add_child(lower)
	# Texture-only foreground must not occlude UI input or live in the middle layer.
	var embers := preload("res://scripts/campaign/map/art/embers.gd").new(); lower.add_child(embers)
	if not preview_mode:
		terminal=preload("res://scripts/campaign/map/art/fog.gd").new(); terminal.name="TerminalFog"
		terminal.position=CampaignMapData.painted_end_position(entries)
		terminal.size=Vector2(CampaignMapData.config()["painted"]["terminal_width"],CampaignMapData.config()["painted"]["design_height"])
		terminal.z_index=4; middle.add_child(terminal)
	parallax=preload("res://scripts/campaign/map/parallax.gd").new()
	parallax.upper=upper; parallax.middle=middle; parallax.lower=lower
	parallax.ratios=CampaignMapData.config()["parallax"]
	surface=Control.new(); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.offset_top=68; surface.offset_bottom=-69; surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	scroller=preload("res://scripts/campaign/map/scroller.gd").new()
	scroller.surface=surface; scroller.settings=CampaignMapData.config()["scroll"]
	scroller.changed.connect(_scroll_changed); add_child(scroller)
	_build_hud(); resized.connect(_layout); _layout.call_deferred()

func _build_hud() -> void:
	header=HBoxContainer.new(); header.name="ArtHUD"
	header.z_index=30
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left=8; header.offset_right=-8; header.offset_top=4; header.offset_bottom=66
	header.add_theme_constant_override("separation",12); add_child(header)
	var home := HUD.button(header,"home","",Vector2(64,64),home_requested.emit); home.tooltip_text="Главное меню"
	HUD.resource(header,"energy","—","Энергия пока не реализована и не расходуется.")
	HUD.resource(header,"coin",CampaignEconomy.text(CampaignEconomy.wallet_units(account,"coins"),4),"Монеты из вашего сохранения")
	HUD.resource(header,"diamond",str(account["crystals"]),"Кристаллы из вашего сохранения")
	HUD.button(header,"shop","МАГАЗИН",Vector2(134,64),shop_requested.emit)
	footer=HBoxContainer.new(); footer.name="ArtNavigation"
	footer.z_index=30
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=12; footer.offset_right=-12; footer.offset_top=-66; footer.offset_bottom=-4
	footer.add_theme_constant_override("separation",8); add_child(footer)
	first_button=HUD.button(footer,"jump","",Vector2(62,52),func() -> void: scroller.go_to(0))
	left_button=HUD.button(footer,"arrow","",Vector2(62,52),func() -> void: scroller.nudge(-1))
	HUD.button(footer,"nav_plate","Казарма",Vector2(110,48),barracks_requested.emit)
	var run: Dictionary=account["active_run"]
	if preview_mode: HUD.button(footer,"nav_plate","К карте",Vector2(118,48),back_requested.emit)
	elif not run.is_empty():
		HUD.button(footer,"nav_plate","Продолжить",Vector2(130,48),resume_requested.emit)
		HUD.button(footer,"nav_plate","× Поход",Vector2(100,48),abandon_requested.emit)
	else: HUD.button(footer,"nav_plate","К уровню %d"%CampaignMapData.current_level(account),Vector2(130,48),func() -> void: focus_current(true))
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; footer.add_child(spacer)
	HUD.button(footer,"nav_plate","Бестиарий",Vector2(130,48),bestiary_requested.emit)
	if not preview_mode and run.is_empty() and not account["last_result"].is_empty(): HUD.button(footer,"nav_plate","Итог",Vector2(80,48),result_requested.emit)
	right_button=HUD.button(footer,"arrow","",Vector2(62,52),func() -> void: scroller.nudge(1),true)
	last_button=HUD.button(footer,"jump","",Vector2(62,52),func() -> void: scroller.go_to(scroller.maximum),true)
	if preview_mode:
		var caption := HUD.label(self,"ПРОБА · УРОВНИ 1 / 2 / 5",11,Color("d4e6ef"))
		caption.position=Vector2(12,72); caption.z_index=30
	if not warning.is_empty(): _build_warning()

func _build_warning() -> void:
	var row := HBoxContainer.new(); row.z_index=30
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_left=12; row.offset_right=-12; row.offset_top=78; row.offset_bottom=145
	var message := HUD.label(row,warning,14,Color("ffe5b3"))
	message.size_flags_horizontal=Control.SIZE_EXPAND_FILL; message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	HUD.button(row,"nav_plate","Сохранить",Vector2(140,48),retry_requested.emit)
	add_child(row)

func _layout() -> void:
	if scroller==null or size.y<1: return
	var center := center_on_map() if _previous_width>0 else initial_center
	_zoom=size.y/float(CampaignMapData.config()["painted"]["design_height"])
	var extent := maxf(size.x+180.0,1600*_zoom)
	if is_instance_valid(terminal): extent=(terminal.position.x+terminal.size.x)*_zoom
	scroller.set_bounds(extent-size.x)
	_previous_width=size.x
	if center>=0: scroller.jump(center*_zoom-size.x*0.5)
	else: focus_current(false)

func center_on_map() -> float:
	return (scroller.offset+_previous_width*0.5)/_zoom if scroller!=null and _previous_width>0 else -1.0

func _scroll_changed(offset: float) -> void:
	parallax.apply(offset,_zoom,0)
	for pair in [[upper,"upper"],[lower,"lower"]]:
		var x := offset*float(parallax.ratios[pair[1]])/_zoom
		pair[0].set_view(x,x+size.x/_zoom)
	var left := offset/_zoom; var right := (offset+size.x)/_zoom
	route.set_view(left,right)
	if is_instance_valid(terminal): terminal.set_animation_visible(terminal.position.x<right and terminal.position.x+terminal.size.x>left)
	for button: Button in [first_button,left_button]:
		button.disabled=offset<=0.2; button.modulate=Color("777f8b") if button.disabled else Color.WHITE
	for button: Button in [right_button,last_button]:
		button.disabled=offset>=float(scroller.maximum)-0.2; button.modulate=Color("777f8b") if button.disabled else Color.WHITE

func focus_current(smooth: bool) -> void:
	var x := CampaignMapData.painted_position_of(entries[0]).x
	for entry in entries:
		if int(entry["level_number"])==CampaignMapData.current_level(account): x=CampaignMapData.painted_position_of(entry).x
	var destination := x*_zoom-size.x*0.5
	if smooth: scroller.go_to(destination)
	else: scroller.jump(destination)

func _activate(number: int) -> void:
	if scroller.suppress_click(): return
	for node in level_nodes:
		if int(node.entry["level_number"])==number and node.entry["can_enter"]: level_requested.emit(number)
