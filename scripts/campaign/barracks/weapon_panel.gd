extends VBoxContainer
signal requested(tier: int)
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const MODEL := preload("res://scripts/campaign/barracks/presentation.gd")
const PREVIEW := preload("res://scripts/campaign/barracks/preview.gd")
var selected_tiers: Dictionary = {}
var hero_id := ""
var account: Dictionary
var merge_button: Button
var merge_progress: ProgressBar
var inventory: HBoxContainer
var card_buttons: Array[Button] = []

func refresh(next_account: Dictionary, id: String) -> void:
	account=next_account; hero_id=id; UI.clear(self); card_buttons.clear()
	var hero: Dictionary=account["heroes"][id]
	var s := CampaignProgression.stats(id,account)
	var factors: Array=CampaignEconomy.data()["weapon_length_factors"]
	var stage := int(hero["weapon_stage"])
	var tier := int(selected_tiers.get(id,stage))
	UI.title(self,"Оружие","damage")
	var header := UI.row(self,8)
	var portrait := PREVIEW.new(); portrait.custom_minimum_size=Vector2(130,120); header.add_child(portrait); portrait.display(id,account,true)
	var summary := VBoxContainer.new(); summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(summary)
	summary.add_child(UI.paragraph(MODEL.WEAPONS[id],21,UI.GOLD))
	summary.add_child(UI.label("Ступень %d / %d"%[stage+1,factors.size()],15))
	summary.add_child(UI.label("Длина %.0f%%"%(s["length_factor"]*100),20,UI.INK))
	summary.add_child(UI.paragraph("%.2f ед. · базовая %.2f ед."%[s["weapon_length"],s["full_length"]],14))
	var ladder := UI.row(self,2)
	for index in factors.size():
		var box := VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; ladder.add_child(box)
		var percent := UI.label("%.0f%%"%(float(factors[index])*100),13,UI.GOLD if index<=stage else UI.MUTED)
		percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(percent)
		UI.progress(box,1 if index<=stage else 0,1)
	if id=="vampire": add_child(UI.paragraph("Клыки всегда исходной длины. Ступени и карточки сохраняются, но не меняют дальность укуса.",14,UI.GOLD))
	var scroll := ScrollContainer.new(); scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y=128; add_child(scroll)
	inventory=UI.row(scroll,6)
	for index in factors.size():
		var button := UI.button("",_select.bind(index),index==tier)
		button.add_theme_stylebox_override("normal",UI.ART.frame("card",8))
		button.add_theme_stylebox_override("hover",UI.ART.frame("card",8))
		button.add_theme_stylebox_override("pressed",UI.ART.frame("card",8))
		button.modulate=Color(1.3,1.15,0.8) if index==tier else Color.WHITE
		button.custom_minimum_size=Vector2(86,120); inventory.add_child(button); card_buttons.append(button)
		var column := VBoxContainer.new(); column.mouse_filter=Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left=6; column.offset_right=-6; column.offset_top=7; column.offset_bottom=-7; column.add_theme_constant_override("separation",0); button.add_child(column)
		var miniature := PREVIEW.new(); miniature.render_size=Vector2i(160,160); miniature.custom_minimum_size=Vector2(66,64); column.add_child(miniature)
		var tier_account := account.duplicate(true); tier_account["heroes"][id]["weapon_stage"]=index
		miniature.display(id,tier_account,true)
		var caption := UI.label(("✓ " if index==stage else "")+"%d · %.0f%%"%[index+1,factors[index]*100],13,UI.GOLD if index==stage else UI.INK)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; column.add_child(caption)
		var count := UI.label("×"+CampaignEconomy.text(hero["weapon_cards"][index]),16,UI.GREEN if index==stage else UI.INK)
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; column.add_child(count)
		button.tooltip_text="%s · ступень %d%s"%[MODEL.WEAPONS[id],index+1," · используется" if index==stage else ""]
	var cost := int(CampaignEconomy.data()["merge_copies"])
	var units := int(CampaignEconomy.data()["card_scale"])
	var owned_units := int(hero["weapon_cards"][tier])
	var footer := UI.panel(self,"steel",10)
	footer.add_child(UI.label("Слияние ступени %d"%(tier+1),18,UI.GOLD))
	var last := tier==factors.size()-1
	footer.add_child(UI.label("%s / %d карточки"%[CampaignEconomy.text(owned_units),cost] if not last else "Максимальная ступень оружия",16))
	merge_progress=UI.progress(footer,mini(owned_units,cost*units),cost*units,Color("4bc9ff"))
	var reason := ""
	if not account["active_run"].is_empty(): reason="Слияние доступно вне похода"
	elif last: reason="Следующей ступени пока нет"
	elif owned_units<cost*units: reason="Нужны %d одинаковые карточки ступени %d"%[cost,tier+1]
	merge_button=UI.button("Слить %d → 1"%cost,func() -> void: requested.emit(tier),true)
	merge_button.icon=UI.ART.texture("merge"); merge_button.expand_icon=true; merge_button.add_theme_constant_override("icon_max_width",28)
	merge_button.disabled=not reason.is_empty(); footer.add_child(merge_button)
	if not reason.is_empty(): footer.add_child(UI.paragraph(reason,14))
	footer.add_child(UI.paragraph("Половинки учитываются точно. Карточки закрытых героев остаются в коллекции.",13))

func _select(tier: int) -> void:
	selected_tiers[hero_id]=tier; refresh(account,hero_id)

func feedback() -> void:
	UI.flash(merge_button)
	var target := merge_progress.value
	merge_progress.value=0
	create_tween().tween_property(merge_progress,"value",target,0.35)
