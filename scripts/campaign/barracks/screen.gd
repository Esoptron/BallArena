extends Control
signal back_requested
signal shop_requested
signal hero_selected(id: String)
signal primary_requested(id: String)
signal ally_requested(id: String)
signal upgrade_requested(id: String, skill: String)
signal merge_requested(id: String, tier: int)
signal retry_requested
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const ART := preload("res://scripts/campaign/barracks/art.gd")
const TABS := ["Характеристики","Прокачка","Оружие","Эволюция"]
const TAB_ICONS := ["rank","rank","damage","evolution"]
var account: Dictionary = {}
var hero_id := "swordsman"
var active_tab := 0
var warning := ""
var selector: ScrollContainer
var showcase: Control
var resources: HBoxContainer
var tab_buttons: Array[Button] = []
var panels: Array[Control] = []
var local_scroll: ScrollContainer
var warning_bar: HBoxContainer
var warning_text: Label
var margin: MarginContainer
var _clock := 0.0
var _background: TextureRect
var _last_action_frame := -1
var _content_box: VBoxContainer
var _dirty: Array[bool] = [true,true,true,true]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if account.is_empty(): account=CampaignProgression.new_account()
	_background=TextureRect.new(); _background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.texture=ART.texture("forge"); _background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fire := ShaderMaterial.new(); fire.shader=preload("res://scripts/campaign/barracks/forge.gdshader"); _background.material=fire
	_background.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(_background)
	var shade := ColorRect.new(); shade.color=Color(0.01,0.02,0.045,0.20)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(shade)
	margin=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(margin)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",6); margin.add_child(column)
	var header := UI.row(column,8)
	var back := UI.button("‹",back_requested.emit); back.custom_minimum_size.x=58; header.add_child(back)
	var heading := UI.label("Казарма",26,UI.GOLD); header.add_child(heading)
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(spacer)
	resources=preload("res://scripts/campaign/barracks/resource_bar.gd").new(); header.add_child(resources)
	var shop := UI.button("Магазин",shop_requested.emit); header.add_child(shop)
	selector=preload("res://scripts/campaign/barracks/selector.gd").new(); column.add_child(selector)
	selector.selected.connect(select_hero)
	warning_bar=UI.row(column); warning_text=UI.paragraph("",14,UI.GOLD); warning_bar.add_child(warning_text)
	warning_bar.add_child(UI.button("Повторить",retry_requested.emit))
	var body := HBoxContainer.new(); body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10); column.add_child(body)
	showcase=preload("res://scripts/campaign/barracks/showcase.gd").new()
	showcase.size_flags_horizontal=Control.SIZE_EXPAND_FILL; showcase.size_flags_stretch_ratio=0.42; body.add_child(showcase)
	showcase.previous_requested.connect(_cycle.bind(-1)); showcase.next_requested.connect(_cycle.bind(1))
	showcase.primary_requested.connect(func(id: String) -> void:
		if _take_action(): primary_requested.emit(id))
	showcase.ally_requested.connect(func(id: String) -> void:
		if _take_action(): ally_requested.emit(id))
	showcase.shop_requested.connect(shop_requested.emit)
	var wrap := PanelContainer.new(); wrap.size_flags_horizontal=Control.SIZE_EXPAND_FILL; wrap.size_flags_stretch_ratio=0.58
	wrap.add_theme_stylebox_override("panel",ART.frame("panel",12)); body.add_child(wrap)
	local_scroll=ScrollContainer.new(); local_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(local_scroll)
	_content_box=VBoxContainer.new(); _content_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; local_scroll.add_child(_content_box)
	var stats := preload("res://scripts/campaign/barracks/stats_panel.gd").new(); _content_box.add_child(stats); panels.append(stats)
	var upgrades := preload("res://scripts/campaign/barracks/upgrade_panel.gd").new()
	_content_box.add_child(upgrades); panels.append(upgrades)
	upgrades.requested.connect(func(skill: String) -> void:
		if _take_action(): upgrade_requested.emit(hero_id,skill))
	var weapons := preload("res://scripts/campaign/barracks/weapon_panel.gd").new()
	_content_box.add_child(weapons); panels.append(weapons)
	weapons.requested.connect(func(tier: int) -> void:
		if _take_action(): merge_requested.emit(hero_id,tier))
	var evolution := preload("res://scripts/campaign/barracks/evolution_panel.gd").new()
	_content_box.add_child(evolution); panels.append(evolution)
	var nav := UI.row(column,6)
	for index in TABS.size():
		var button := UI.button(TABS[index],set_tab.bind(index))
		button.icon=ART.texture(TAB_ICONS[index]); button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",28)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; nav.add_child(button); tab_buttons.append(button)
	resized.connect(_layout); _layout(); refresh(account,warning)
	# Cached viewport textures redraw only after a profile change. The shader
	# supplies fire motion without a script callback every display frame.
	set_process(false)

func _layout() -> void:
	if not is_instance_valid(margin): return
	var insets := Vector4(8,6,8,6)
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var window_size := DisplayServer.window_get_size()
		if safe.has_area() and window_size.x>0 and window_size.y>0:
			var ratio := size/Vector2(window_size)
			insets=Vector4(maxf(8,safe.position.x*ratio.x),maxf(6,safe.position.y*ratio.y),maxf(8,(window_size.x-safe.end.x)*ratio.x),maxf(6,(window_size.y-safe.end.y)*ratio.y))
	for index in 4: margin.add_theme_constant_override("margin_"+["left","top","right","bottom"][index],ceili(insets[index]))
	for button in tab_buttons:
		button.custom_minimum_size.y=48 if size.y<500 else 58

func refresh(next_account: Dictionary, next_warning: String = "") -> void:
	account=next_account; warning=next_warning
	resources.refresh(account); selector.refresh(account,hero_id); showcase.refresh(account,hero_id)
	warning_bar.visible=not warning.is_empty(); warning_text.text=warning
	_dirty.assign([true,true,true,true])
	set_tab(active_tab,false)

func select_hero(id: String) -> void:
	if not CampaignProgression.playable_ids().has(id): return
	hero_id=id; hero_selected.emit(id)
	local_scroll.scroll_vertical=0
	refresh(account,warning)
	selector.reveal.call_deferred(id)

func set_tab(index: int, animate: bool = true) -> void:
	if index<0 or index>=panels.size(): return
	var changed := active_tab!=index
	active_tab=index
	if _dirty[index]:
		panels[index].refresh(account,hero_id)
		_dirty[index]=false
	for i in panels.size():
		panels[i].visible=i==index; UI.style_button(tab_buttons[i],i==index)
	if changed: local_scroll.scroll_vertical=0
	if animate and changed: UI.flash(tab_buttons[index])

func feedback(kind: String, skill: String = "") -> void:
	if kind=="upgrade" and active_tab==1: panels[1].feedback(skill)
	elif kind=="merge" and active_tab==2: panels[2].feedback()

func _cycle(direction: int) -> void:
	var ids := CampaignProgression.playable_ids()
	select_hero(ids[posmod(ids.find(hero_id)+direction,ids.size())])

func _take_action() -> bool:
	var frame := Engine.get_process_frames()
	if frame==_last_action_frame: return false
	_last_action_frame=frame
	return true
