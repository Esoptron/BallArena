extends VBoxContainer
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const PREVIEW := preload("res://scripts/campaign/barracks/preview.gd")
var evolution_button: Button
var help: AcceptDialog
func refresh(account: Dictionary, id: String) -> void:
	UI.clear(self)
	UI.title(self,"Эволюция","evolution")
	var hero: Dictionary=account["heroes"][id]
	var progress := CampaignEvolutions.progress(account,id)
	var comparison := UI.row(self,8)
	var current := UI.panel(comparison,"card",9)
	current.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var portrait := PREVIEW.new(); portrait.render_size=Vector2i(240,240); portrait.custom_minimum_size=Vector2(100,116)
	current.add_child(portrait); portrait.display(id,account)
	var current_name := UI.label("Текущая форма",14); current_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; current.add_child(current_name)
	comparison.add_child(UI.label("➜",26,UI.GOLD))
	var future := UI.panel(comparison,"card",9); future.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var unknown := UI.label("?",68,UI.MUTED); unknown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; unknown.custom_minimum_size=Vector2(100,116); future.add_child(unknown)
	var future_name := UI.label("Будущая форма",14); future_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; future.add_child(future_name)
	add_child(UI.label("Карточки героя: %s / %d"%[CampaignEconomy.text(progress["units"]),CampaignEconomy.data()["evolution_extra_cards"]],20,UI.GOLD))
	var cards := UI.row(self,8)
	var scale_value := int(CampaignEconomy.data()["card_scale"])
	for index in int(CampaignEconomy.data()["evolution_extra_cards"]):
		var box := UI.panel(cards,"card",8); box.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var miniature := PREVIEW.new(); miniature.render_size=Vector2i(128,128); miniature.custom_minimum_size=Vector2(60,70); box.add_child(miniature); miniature.display(id,account)
		var collected := clampi(int(progress["units"])-index*scale_value,0,scale_value)
		miniature.modulate=Color.WHITE if collected==scale_value else Color(0.7,0.7,0.7,0.55)
		var count := UI.label(CampaignEconomy.text(collected)+" / 1",15,UI.GREEN if collected==scale_value else UI.MUTED)
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(count)
	UI.progress(self,progress["units"],progress["required"],UI.GOLD)
	if not hero["owned"]: add_child(UI.paragraph("Сначала откройте героя: %s / 1 карточки. После открытия дополнительные карточки идут в эволюцию."%CampaignEconomy.text(hero["unlock_card_units"]),15,UI.GOLD))
	elif progress["cards_ready"]: add_child(UI.paragraph("Карточки собраны и сохранены. Способность эволюции ещё не определена.",15,UI.GREEN))
	else: add_child(UI.paragraph("После открытия героя соберите ещё %d его карточки. Половинки накапливаются."%CampaignEconomy.data()["evolution_extra_cards"],15))
	evolution_button=UI.button("Эволюция в разработке",func() -> void: pass)
	evolution_button.disabled=true; add_child(evolution_button)
	add_child(UI.paragraph("Новая форма и её способности появятся позже. Сейчас карточки не расходуются; дополнительных требований нет.",14))
	add_child(UI.button("Как получить?",_show_help))
	help=UI.dialog("Карточки персонажей"); add_child(help)
	var lines := ["Сундук открывается после 10 волн и победы над боссом.","Шанс карточки героя за каждую пройденную волну:"]
	for chest in CampaignEconomy.data()["chests"].values():
		lines.append("%s: %.0f%% за завершённую волну."%[chest["name"],float(chest["character_chance"])*100])
	lines.append("Первая целая карточка открывает героя. Дубликаты идут в эволюцию; половинки накапливаются. Героя также можно купить в магазине. Выпадение не гарантировано.")
	help.dialog_text="\n".join(lines)

func _show_help() -> void:
	help.popup_centered(Vector2i(mini(500,int(get_viewport_rect().size.x)-48),mini(340,int(get_viewport_rect().size.y)-48)))
