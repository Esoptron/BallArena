extends PanelContainer
signal requested(skill: String)
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const MODEL := preload("res://scripts/campaign/barracks/presentation.gd")
var skill := ""
var action: Button
var progress_bar: ProgressBar

func configure(account: Dictionary, id: String, key: String) -> void:
	skill=key
	UI.clear(self); add_theme_stylebox_override("panel",UI.ART.frame("steel",10))
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",5); add_child(box)
	var title := UI.row(box,5)
	title.add_child(UI.icon(MODEL.ICONS[key],32))
	var name_label := UI.paragraph(MODEL.ability_name(id) if key=="ability" else MODEL.NAMES[key],15,UI.INK)
	title.add_child(name_label)
	var current_rank := int(account["heroes"][id]["ability_rank"]) if key=="ability" else CampaignProgression.rank(account,id,key)
	var rank_label := UI.label("Ранг %d"%current_rank,13,UI.GOLD)
	title.add_child(rank_label)
	var current := CampaignProgression.stats(id,account)
	var future := MODEL.next_stats(account,id,key)
	var cost := CampaignProgression.coin_cost(account,id) if key=="ability" else CampaignProgression.xp_cost(account,id,key)
	var text := MODEL.value(key,current).replace(" рад/с","")
	if cost>=0: text+=" → "+MODEL.value(key,future).replace(" рад/с","")
	var amount := UI.label(text,18,UI.GREEN); amount.tooltip_text=MODEL.value(key,current)+" → "+MODEL.value(key,future)
	box.add_child(amount)
	# Only capped skills get a truthful progress bar.
	if key=="recovery": progress_bar=UI.progress(box,current["recovery"],CampaignProgression.data()["recovery_max"],UI.GREEN)
	elif key=="ability": progress_bar=UI.progress(box,current["chance"],current["training_cap"],UI.GOLD)
	elif key=="spin":
		var cap := int(ceili((float(CampaignProgression.data()["spin_max_fraction"])-float(CampaignProgression.data()["players"][id]["spin_fraction"]))/float(CampaignProgression.data()["spin_rank_fraction"])))
		progress_bar=UI.progress(box,current_rank,cap,Color("ba76ff"))
	var currency := "coins" if key=="ability" else "xp"
	var reason := MODEL.reason(account,id,cost,currency)
	var footer := UI.row(box,5)
	footer.add_child(UI.icon("coin" if key=="ability" else "xp",25))
	footer.add_child(UI.label(str(cost) if cost>=0 else "Макс.",15,UI.GOLD))
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; footer.add_child(spacer)
	action=UI.button("Тренировать" if key=="ability" else "Улучшить",func() -> void: requested.emit(skill),reason.is_empty())
	action.add_theme_font_size_override("font_size",14); action.disabled=not reason.is_empty(); footer.add_child(action)
	if not reason.is_empty(): box.add_child(UI.paragraph(reason,13,UI.MUTED))
	if id=="vampire" and key=="ability": box.add_child(UI.paragraph("Доля базового HP для запуска Охоты, а не вероятность события.",14,UI.GOLD))

func animate_gain() -> void:
	UI.flash(self)
	if is_instance_valid(progress_bar):
		var target := progress_bar.value
		progress_bar.value=maxf(0,target-progress_bar.max_value*0.15)
		create_tween().tween_property(progress_bar,"value",target,0.3)
