extends Control
signal previous_requested
signal next_requested
signal primary_requested(id: String)
signal ally_requested(id: String)
signal shop_requested
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const ART := preload("res://scripts/campaign/barracks/art.gd")
const MODEL := preload("res://scripts/campaign/barracks/presentation.gd")
var preview: Control
var heading: Label
var status: Label
var description: Button
var primary: Button
var ally: Button
var info: AcceptDialog
var brief: Label
var hero_id := ""
var _transition: Tween

func _ready() -> void:
	var dais := TextureRect.new(); dais.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	dais.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; dais.texture=ART.texture("pedestal")
	dais.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dais.anchor_left=0.03; dais.anchor_right=0.97; dais.anchor_top=0.45; dais.anchor_bottom=0.94; add_child(dais)
	preview=preload("res://scripts/campaign/barracks/preview.gd").new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_top=0; preview.offset_bottom=-35; add_child(preview)
	var name_panel := PanelContainer.new(); name_panel.add_theme_stylebox_override("panel",ART.frame("button",4))
	name_panel.anchor_right=1; name_panel.offset_bottom=36; add_child(name_panel)
	heading=UI.label("",24,UI.GOLD); heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; name_panel.add_child(heading)
	status=UI.label("",14,UI.GOLD); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.anchor_right=1; status.offset_top=36; status.offset_bottom=55; add_child(status)
	var before := UI.button("‹",previous_requested.emit); before.custom_minimum_size.x=44
	before.anchor_top=0.4; before.anchor_bottom=0.4; before.offset_top=-22; before.offset_bottom=22; before.offset_right=44; add_child(before)
	var after := UI.button("›",next_requested.emit); after.custom_minimum_size.x=44
	after.anchor_left=1; after.anchor_right=1; after.anchor_top=0.4; after.anchor_bottom=0.4
	after.offset_top=-22; after.offset_bottom=22; after.offset_left=-44; add_child(after)
	brief=UI.paragraph("",15,UI.INK); brief.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	brief.anchor_left=0.08; brief.anchor_right=0.92; brief.offset_top=57; brief.offset_bottom=105; add_child(brief)
	description=UI.button("ⓘ",_explain)
	description.add_theme_font_size_override("font_size",14)
	description.anchor_left=1; description.anchor_right=1
	description.offset_left=-44; description.offset_top=36; description.offset_bottom=80; add_child(description)
	var actions := HBoxContainer.new(); actions.anchor_top=1; actions.anchor_bottom=1; actions.anchor_right=1
	actions.offset_top=-44; add_child(actions)
	primary=UI.button("Основной",func() -> void: primary_requested.emit(hero_id))
	primary.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(primary)
	ally=UI.button("Союзник",func() -> void: ally_requested.emit(hero_id))
	ally.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(ally)
	info=UI.dialog("Особенность героя"); info.min_size=Vector2i(320,100); add_child(info)
	resized.connect(_layout); _layout()

func _layout() -> void:
	if is_instance_valid(brief): brief.visible=size.y>=330
	if is_instance_valid(preview):
		preview.set_compact(size.y<330)
		preview.offset_top=100 if size.y>=330 else 50
		preview.offset_bottom=-42

func refresh(account: Dictionary, id: String) -> void:
	var changed := hero_id!=id
	hero_id=id
	heading.text=CampaignProgression.data()["players"][id]["name"]
	var hero: Dictionary=account["heroes"][id]
	var owned: bool=hero["owned"]
	var active: bool=not account["active_run"].is_empty()
	var is_primary: bool=account["selected_hero"]==id
	var is_ally: bool=account["selected_ally"]==id
	status.text="Основной герой" if is_primary else ("Союзник" if is_ally else ("Герой открыт" if owned else "Закрыт · карточки %s/1"%CampaignEconomy.text(hero["unlock_card_units"])))
	primary.text="✓ Основной" if is_primary else ("Выбрать" if owned else "В магазин")
	primary.disabled=active or is_primary
	# Locked heroes are inspectable. The purchase route never appoints them.
	for connection in primary.pressed.get_connections(): primary.pressed.disconnect(connection["callable"])
	primary.pressed.connect(func() -> void:
		if owned: primary_requested.emit(hero_id)
		else: shop_requested.emit())
	ally.text="Убрать союзника" if is_ally else "В союзники"
	ally.disabled=active or not owned or not account["features"]["ally_slot_owned"]
	for connection in ally.pressed.get_connections(): ally.pressed.disconnect(connection["callable"])
	ally.pressed.connect(func() -> void: ally_requested.emit("" if is_ally else hero_id))
	ally.tooltip_text="Купите постоянный слот союзника в магазине" if not account["features"]["ally_slot_owned"] else "HP переносится между волнами; погибшие не возвращаются"
	primary.tooltip_text="Смена героя доступна вне похода" if active else ""
	if not owned:
		var prices: PackedStringArray=[]
		for currency in CampaignEconomy.prices(id): prices.append("%d %s"%[CampaignEconomy.prices(id)[currency],"монет" if currency=="coins" else "кристаллов"])
		primary.text="Открыть · "+str(int(CampaignEconomy.prices(id).values()[0])) if not prices.is_empty() else "В магазин"
		primary.tooltip_text="В магазине: "+" или ".join(prices)
	description.tooltip_text=MODEL.DESCRIPTIONS[id]
	brief.text=MODEL.DESCRIPTIONS[id]
	preview.display(id,account)
	if changed:
		if _transition and _transition.is_valid(): _transition.kill()
		preview.modulate.a=0.35
		_transition=create_tween(); _transition.tween_property(preview,"modulate:a",1.0,0.2)

func _explain() -> void:
	info.dialog_text=MODEL.DESCRIPTIONS[hero_id]
	info.popup_centered(Vector2i(mini(480,int(get_viewport_rect().size.x)-48),160))
