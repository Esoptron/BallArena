extends Control
## Deliberately isolated three-node art study. It never rewrites the 20-node map.
signal home_requested
signal back_requested
signal shop_requested
signal barracks_requested
signal bestiary_requested
signal level_requested(number: int)
const HUD := preload("res://scripts/campaign/map/art/hud.gd")
const SCENERY := preload("res://scripts/campaign/map/art/scenery.gd")
const POSITIONS := [Vector2(220,108),Vector2(650,175),Vector2(1080,90)]
const NUMBERS := [1,2,5]
var account: Dictionary = {}
var level_nodes: Array[Button] = []
var surface: Control
var art_root: Control
var upper: Node2D
var middle: Node2D
var lower: Node2D
var scroller: Node
var parallax: RefCounted
var header: HBoxContainer
var footer: HBoxContainer
var _zoom := 1.0
var _previous_width := 0.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if account.is_empty(): account=CampaignProgression.new_account()
	art_root=Control.new(); art_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_root.mouse_filter=Control.MOUSE_FILTER_IGNORE; art_root.clip_contents=true; add_child(art_root)
	upper=SCENERY.new(); art_root.add_child(upper)
	middle=Node2D.new(); art_root.add_child(middle)
	var route := preload("res://scripts/campaign/map/art/route.gd").new()
	for point: Vector2 in POSITIONS: route.points.append(point)
	middle.add_child(route)
	var all := CampaignMapData.entries(account)
	for index in NUMBERS.size():
		var node := preload("res://scripts/campaign/map/art/level_node.gd").new()
		node.entry=all[NUMBERS[index]-1].duplicate(true)
		node.position=POSITIONS[index]-Vector2(150,0)
		node.pressed.connect(_activate.bind(NUMBERS[index])); middle.add_child(node); level_nodes.append(node)
	lower=SCENERY.new(); lower.asset="foreground"; art_root.add_child(lower)
	# Texture-only foreground must not occlude UI input or live in the middle layer.
	var embers := preload("res://scripts/campaign/map/art/embers.gd").new(); lower.add_child(embers)
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
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left=8; header.offset_right=-8; header.offset_top=4; header.offset_bottom=66
	header.add_theme_constant_override("separation",12); add_child(header)
	var home := HUD.button(header,"home","",Vector2(64,64),home_requested.emit); home.tooltip_text="Главное меню"
	HUD.resource(header,"energy","—","Энергия пока не реализована и не расходуется.")
	HUD.resource(header,"coin",CampaignEconomy.text(CampaignEconomy.wallet_units(account,"coins"),4),"Монеты из вашего сохранения")
	HUD.resource(header,"diamond",str(account["crystals"]),"Кристаллы из вашего сохранения")
	HUD.button(header,"shop","МАГАЗИН",Vector2(134,64),shop_requested.emit)
	footer=HBoxContainer.new(); footer.name="ArtNavigation"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=12; footer.offset_right=-12; footer.offset_top=-66; footer.offset_bottom=-4
	footer.add_theme_constant_override("separation",8); add_child(footer)
	HUD.button(footer,"jump","",Vector2(62,52),func() -> void: scroller.go_to(0))
	HUD.button(footer,"arrow","",Vector2(62,52),func() -> void: scroller.nudge(-1))
	HUD.button(footer,"nav_plate","К карте",Vector2(118,48),back_requested.emit)
	HUD.button(footer,"nav_plate","Казарма",Vector2(118,48),barracks_requested.emit)
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; footer.add_child(spacer)
	HUD.button(footer,"nav_plate","Бестиарий",Vector2(130,48),bestiary_requested.emit)
	HUD.button(footer,"arrow","",Vector2(62,52),func() -> void: scroller.nudge(1),true)
	HUD.button(footer,"jump","",Vector2(62,52),func() -> void: scroller.go_to(scroller.maximum),true)
	var caption := HUD.label(self,"ХУДОЖЕСТВЕННАЯ ПРОБА · УРОВНИ 1 / 2 / 5",11,Color("d4e6ef"))
	caption.position=Vector2(12,72); caption.modulate.a=0.85

func _layout() -> void:
	if scroller==null or size.y<1: return
	var center := center_on_map()
	_zoom=size.y/600.0
	scroller.set_bounds(maxf(size.x+180.0,1600*_zoom)-size.x)
	_previous_width=size.x
	if center>=0: scroller.jump(center*_zoom-size.x*0.5)
	else: scroller.jump(0)

func center_on_map() -> float:
	return (scroller.offset+_previous_width*0.5)/_zoom if scroller!=null and _previous_width>0 else -1.0

func _scroll_changed(offset: float) -> void:
	parallax.apply(offset,_zoom,0)
	for pair in [[upper,"upper"],[lower,"lower"]]:
		var x := offset*float(parallax.ratios[pair[1]])/_zoom
		pair[0].set_view(x,x+size.x/_zoom)

func _activate(number: int) -> void:
	if scroller.suppress_click(): return
	for node in level_nodes:
		if int(node.entry["level_number"])==number and node.entry["can_enter"]: level_requested.emit(number)
