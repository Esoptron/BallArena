extends Control
signal closed
const STYLES := preload("res://scripts/ui/menu_styles.gd")
const BLUE := Color("83b2ff")
const GOLD := Color("e2b46d")
const NAMES := {"hp":"Макс. HP", "speed":"Скорость", "spin":"Вращение", "damage":"Урон", "hit_growth":"Прирост урона за попадание", "healing":"Лечение за укус", "heal_growth":"Прирост лечения за укус", "chance_growth":"Прирост шанса кровотечения", "recovery":"Восстановление после боя"}
var account := CampaignProgression.new_account()
var page := "levels"
var content: VBoxContainer
var page_root: Control
var battle_view: Node2D
var battle_arena: BallArena
var battle_title: Label
var battle_stats: Label
var _hud_clock := 0.0
var _transition_pending := false
var _layout_viewport: Viewport
var viewed_hero := ""
var save_path := ""
var save_warning := ""
var save_blocked := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_viewport=get_viewport()
	_layout_viewport.size_changed.connect(_resize)
	var loaded := CampaignSave.load_account(save_path)
	save_warning=loaded["warning"]
	save_blocked=loaded["account"].is_empty()
	if not save_blocked: account=loaded["account"]
	show_page("levels")

func _save() -> bool:
	if save_blocked: return false
	var result := CampaignSave.write(account,save_path)
	if result!=OK:
		save_warning="Не удалось записать прогресс (ошибка %d). Не закрывайте игру; повторите сохранение."%result
	return result==OK

func _resize() -> void:
	if is_instance_valid(content): content.custom_minimum_size.x=maxf(280,get_viewport_rect().size.x-40)

func _label(text: String, size_value: int = 18, color: Color = Color("eef3ff")) -> Label:
	var label := Label.new(); label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",color)
	return label

func _button(parent: Node, text: String, action: Callable, disabled_value: bool = false) -> Button:
	var button := STYLES.battle_button(text,BLUE)
	button.custom_minimum_size.y=52; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",18); button.disabled=disabled_value
	button.pressed.connect(action); parent.add_child(button); return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",STYLES.box(Color("111d30"),Color("344762"),16,16,14))
	parent.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",10); panel.add_child(box); return box

func _clear_page() -> void:
	if is_instance_valid(page_root): remove_child(page_root); page_root.queue_free()
	page_root=Control.new(); page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(page_root)
	content=null

func show_page(next: String) -> void:
	page=next; _clear_page()
	var background := ColorRect.new(); background.color=Color("090f1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page_root.add_child(background)
	var decor := preload("res://scripts/menu_backdrop.gd").new()
	decor.mouse_filter=Control.MOUSE_FILTER_IGNORE; decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page_root.add_child(decor)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left=20; scroll.offset_top=12; scroll.offset_right=-20; scroll.offset_bottom=-12
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; page_root.add_child(scroll)
	content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12); scroll.add_child(content); _resize()
	var header := HBoxContainer.new(); content.add_child(header)
	_button(header,"← Режимы" if next=="levels" else "← Кампания",back)
	var wallet := _label("%d монет  ·  %d XP"%[account["coins"],account["xp"]],20,GOLD)
	wallet.size_flags_horizontal=Control.SIZE_EXPAND_FILL; wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; header.add_child(wallet)
	if not save_warning.is_empty():
		content.add_child(_label(save_warning,18,GOLD))
		if not save_blocked: _button(content,"Повторить сохранение",func() -> void:
			if _save(): save_warning=""; show_page(page))
	if save_blocked:
		content.add_child(_label("Запуск похода заблокирован, чтобы сохранить данные. Восстановите файл сохранения или его .bak. Путь: "+(CampaignSave.default_path() if save_path.is_empty() else save_path),18,GOLD))
		return
	match next:
		"levels": _levels()
		"barracks": _barracks()
		"shop": _shop()
		"reward": _reward()
		"defeat":
			content.add_child(_label("Поражение",32,GOLD))
			content.add_child(_label("Награды за завершённые битвы сохранены. Временные усиления и накопление попаданий сброшены."))
			_button(content,"Вернуться к уровням",show_page.bind("levels"))
		"complete":
			content.add_child(_label("Уровень завершён",32,GOLD))
			content.add_child(_label("Выбранный бонус сохранён для следующего уровня. Начните новый уровень с полным здоровьем."))
			_button(content,"К карте кампании",show_page.bind("levels"))

func _levels() -> void:
	content.add_child(_label("ОСНОВНАЯ КАМПАНИЯ",28,GOLD))
	var row := HBoxContainer.new(); content.add_child(row)
	_button(row,"Казарма",show_page.bind("barracks")); _button(row,"Магазин",show_page.bind("shop"))
	content.add_child(_label("Герой: "+CampaignProgression.data()["players"][account["selected_hero"]]["name"]+"  ·  5 уровней / 50 битв"))
	var run: Dictionary = account["active_run"]
	if not run.is_empty():
		var panel := _panel(content)
		panel.add_child(_label("Текущий поход · %d–%d · %s HP"%[run["level"],run["battle"],CampaignUnits.text(run["hp"])],22,BLUE))
		_button(panel,"Выбрать награду" if run["status"]=="reward" else "Продолжить",_resume)
		_button(panel,"Завершить поход…",_confirm_abandon)
	for level in CampaignLevels.all():
		var number := int(level["level"])
		var unlocked := number<=int(account["unlocked_level"])
		_button(content,"%02d  ·  %s  ·  10 битв%s"%[number,level["name"],"  ✓" if account["boss_wins"].has(number) else ""],_start.bind(number),not unlocked or not run.is_empty())
	if account["next_bonus"].has("6"): content.add_child(_label("Бонус для будущего уровня 6 сохранён. Уровень ещё не создан.",16,GOLD))

func _confirm_abandon() -> void:
	var dialog := ConfirmationDialog.new(); dialog.title="Завершить поход?"
	dialog.dialog_text="Текущие HP и временные карточки будут сброшены. Заработанные монеты и XP останутся."
	dialog.ok_button_text="Завершить"; dialog.cancel_button_text="Продолжить поход"; add_child(dialog)
	dialog.confirmed.connect(func() -> void: account["active_run"]={}; _save(); show_page("levels"))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible: dialog.queue_free())
	dialog.popup_centered(Vector2i(420,160))

func _start(level: int) -> void:
	var candidate := account.duplicate(true)
	if CampaignRun.start(candidate,level,account["selected_hero"],randi()) and _commit_account(candidate): _resume()

func _resume() -> void:
	if account["active_run"].is_empty(): return
	if account["active_run"]["status"]=="reward": show_page("reward"); return
	_start_battle()

func _start_battle() -> void:
	if not CampaignRun.begin(account): return
	if not _save(): account["active_run"]["status"]="ready"; show_page("levels"); return
	_transition_pending=false
	var run: Dictionary = account["active_run"]
	var encounter := CampaignLevels.encounter(run["level"],run["battle"])
	battle_view=preload("res://scenes/main.tscn").instantiate()
	battle_view.set_script(preload("res://scripts/campaign/battle_view.gd"))
	battle_arena=battle_view.get_node("Arena")
	battle_arena.set_script(preload("res://scripts/campaign/arena.gd"))
	var lineup: Array[Dictionary] = [CampaignProfiles.hero(run["hero"],CampaignRun.profile_account(account),run["bonuses"])]
	for enemy in encounter["enemies"]: lineup.append(CampaignCatalog.enemy(enemy["id"],enemy))
	battle_arena.set("lineup",lineup)
	battle_arena.set("carried_hp",run["hp"]); battle_arena.set("carried_peak",run["peak"])
	battle_arena.spawn_seed=int(run["seed"]) ^ int(run["battle"])*104729
	get_viewport().add_child(battle_view)
	battle_arena.connect("campaign_finished",_finished)
	_clear_page()
	var bar := HBoxContainer.new(); bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left=12; bar.offset_right=-12; bar.offset_top=8; page_root.add_child(bar)
	var pause_button := _button(bar,"← Пауза",_pause)
	pause_button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	battle_title=_label("%s · %d/10%s"%[CampaignLevels.all()[int(run["level"])-1]["name"],run["battle"]," · БОСС" if encounter["boss"] else ""],18,GOLD)
	if encounter["boss"]: battle_title.text+=" · "+CampaignCatalog.data()[encounter["enemies"][0]["id"]]["name"]
	battle_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; battle_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; bar.add_child(battle_title)
	battle_stats=_label("",15,BLUE); battle_stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	battle_stats.offset_left=20; battle_stats.offset_right=-20; battle_stats.offset_top=-55; page_root.add_child(battle_stats)
	page="battle"
	_process(0.25)

func _pause() -> void:
	if not is_instance_valid(battle_view) or _transition_pending: return
	battle_view.process_mode=Node.PROCESS_MODE_DISABLED
	var dialog := ConfirmationDialog.new(); dialog.title="Пауза"
	dialog.dialog_text="Можно продолжить бой или вернуться к кампании. При выходе незавершённая битва начнётся заново с теми же HP и позициями."
	dialog.ok_button_text="К кампании"; dialog.cancel_button_text="Продолжить бой"; add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		account["active_run"]["status"]="ready"; _save(); _clear_battle(); show_page("levels"))
	dialog.canceled.connect(func() -> void:
		if is_instance_valid(battle_view): battle_view.process_mode=Node.PROCESS_MODE_INHERIT)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible: dialog.queue_free())
	dialog.popup_centered(Vector2i(460,180))

func _process(delta: float) -> void:
	if page!="battle" or not is_instance_valid(battle_arena): return
	_hud_clock+=delta
	if _hud_clock<0.2: return
	_hud_clock=0
	var actor := battle_arena.fighters[0] as CampaignBall
	var text := "HP %s / %s   ·   Скорость %.0f"%[CampaignUnits.text(actor.current_health),CampaignUnits.text(actor.campaign_effective_max),actor.effective_movement_speed()]
	for ability in battle_arena.director.abilities:
		if ability.fighter!=actor or not ability.is_enabled(): continue
		if ability is SwordAbility: text+="   ·   Урон %s   ·   Вращение %.2f/с"%[CampaignUnits.text(ability.current_damage),ability.effective_spin_speed()/TAU]
		elif ability is VampireFangs: text+="   ·   Укус %s   ·   Лечение %s"%[CampaignUnits.text(ability.get("campaign_damage")),CampaignUnits.text(ability.get("campaign_healing"))]
		if ability is KatanaAbility: text+="   ·   Кровь %.1f%%"%(ability.critical_chance*100)
	battle_stats.text=text

func _finished(won: bool, hp: int, peak: int) -> void:
	if _transition_pending: return
	_transition_pending=true
	var run: Dictionary = account["active_run"]
	var reward := CampaignLevels.encounter(run["level"],run["battle"])["reward"] as Dictionary
	if not CampaignRun.settle(account,won,hp,peak,reward): return
	_save()
	_finish_transition.call_deferred(won)

func _finish_transition(won: bool) -> void:
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree(): return
	_clear_battle(); show_page("reward" if won else "defeat")

func _clear_battle() -> void:
	if is_instance_valid(battle_view): battle_view.get_parent().remove_child(battle_view); battle_view.queue_free()
	battle_view=null; battle_arena=null

func _reward() -> void:
	var run: Dictionary = account["active_run"]
	if run.get("status","")!="reward": show_page("levels"); return
	content.add_child(_label("Победа · выберите усиление",28,GOLD))
	content.add_child(_label("Бонус для следующего уровня" if int(run["battle"])==10 else "Усиления складываются до завершения этого уровня",18,BLUE))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); content.add_child(row)
	for i in run["offer"].size():
		var id: String = run["offer"][i]
		var data: Array = CampaignCards.DEFINITIONS[id]
		var box := _panel(row)
		box.add_child(_label({"common":"ОБЫЧНАЯ","rare":"РЕДКАЯ","legendary":"ЛЕГЕНДАРНАЯ"}[data[2]],14,GOLD if data[2]=="legendary" else BLUE))
		box.add_child(_label(data[0],24)); box.add_child(_label(data[1],18))
		_button(box,"Выбрать",_choose.bind(i))

func _choose(index: int) -> void:
	var boss := int(account["active_run"].get("battle",0))==10
	var candidate := account.duplicate(true)
	if not CampaignRun.choose(candidate,index): return
	if not _commit_account(candidate): show_page("reward"); return
	show_page("complete") if boss else _resume()

func _barracks() -> void:
	content.add_child(_label("Казарма · постоянные улучшения",28,GOLD))
	var choices := HBoxContainer.new(); content.add_child(choices)
	for id in CampaignProgression.playable_ids():
		_button(choices,CampaignProgression.data()["players"][id]["name"]+(" 🔒" if not account["heroes"][id]["owned"] else ""),_select.bind(id))
	var id: String = viewed_hero if not viewed_hero.is_empty() else account["selected_hero"]
	var stats := CampaignProgression.stats(id,account)
	var box := _panel(content)
	box.add_child(_label(stats["name"],28,BLUE))
	_portrait(box,id)
	var summary := "HP %.2f · скорость %.0f · урон %.2f (+%.2f за попадание)\nВращение %.2f рад/с (%.2f об/с) · оружие %.2f / %.2f · кулдаун %.1f с\nМасса %.2f · вес тела %s · вес оружия %s\nСпособность %.2f%% · восстановление после боя %.0f%%"%[
		stats["max_hp"],stats["speed"],stats["damage"],stats["hit_growth"],stats["spin"],stats["spin"]/TAU,stats["weapon_length"],stats["full_length"],stats["cooldown"],stats["mass"],_weight(stats["body_weight"]),_weight(stats["weapon_weight"]),stats["chance"]*100,stats["recovery"]*100]
	if id=="vampire": summary+="\nЛечение %.2f (+%.2f за полный укус). Охота при %.2f HP. Дальность клыков не меняется."%[stats["healing"],stats["heal_growth"],stats["base_hp"]*stats["chance"]]
	if id=="katana": summary+="\nКровотечение %.2f HP/с за каждый крит до конца боя; шанс +%.2f п.п./попадание."%[stats["bleed_damage"],stats["chance_growth"]*100]
	var profile := CampaignProfiles.hero(id,account)["definition"] as CharacterDefinition
	var params := profile.abilities[0].parameters
	summary+="\nНачальное HP без рангов: %.2f · длительность способности %.1f с"%[CampaignProgression.data()["players"][id]["hp"],stats["duration"]]
	if id=="knifeman": summary+="\nКонтратака %.2f%% за тик захвата · прирост вращения %.2f рад/с за попадание"%[stats["chance"]*100,params["spin_gain"]]
	if id=="club": summary+="\nШанс удара о стену %.2f%% · урон %.0f%% макс. HP · щит %.1f%% / %.1f с"%[stats["chance"]*100,params["wall_burst_fraction"]*100,params["shield_chance"]*100,params["shield_duration"]]
	if stats["damage_cap"]>0: summary+="\nПотолок роста урона в одном бою: %.2f; растёт с постоянным уроном."%stats["damage_cap"]
	box.add_child(_label(summary))
	var locked: bool = not account["active_run"].is_empty() or not account["heroes"][id]["owned"]
	if locked: box.add_child(_label("Откройте героя в магазине; постоянная прокачка доступна вне похода.",16,GOLD))
	for skill in CampaignProgression.data()["players"][id]["xp_skills"]:
		var price := CampaignProgression.xp_cost(account,id,skill)
		var next_account := account.duplicate(true)
		next_account["heroes"][id]["ranks"][skill]=CampaignProgression.rank(account,id,skill)+1
		var future := CampaignProgression.stats(id,next_account)
		var stat_key: String = {"hp":"max_hp","recovery":"recovery"}.get(skill,skill)
		var old := float(stats[stat_key]); var after := float(future[stat_key])
		if skill in ["recovery","chance_growth"]: old*=100; after*=100
		_button(box,"%s · ранг %d · %.2f → %.2f · %s XP"%[NAMES[skill],CampaignProgression.rank(account,id,skill),old,after,str(price) if price>=0 else "макс."],_upgrade.bind(id,skill),locked or price<0 or account["xp"]<price)
	var coin_price := CampaignProgression.coin_cost(account,id)
	_button(box,"Тренировать способность · %s монет"%(str(coin_price) if coin_price>=0 else "максимум"),_upgrade.bind(id,"ability"),locked or coin_price<0 or account["coins"]<coin_price)
	_weapons(box,id,locked)
	var evo: Dictionary = account["heroes"][id]["evolution"]
	box.add_child(_label("Эволюция — в разработке. Первая: эпическое оружие, личное испытание, 3 карты героя. Прогресс карт: %d; испытание: %s."%[evo["character_cards"],"пройдено" if evo["personal_trial_won"] else "не пройдено"],16,BLUE))

static func _weight(value: int) -> String: return ["лёгкий","легче среднего","средний","тяжелее среднего","тяжёлый"][value]
func _select(id: String) -> void:
	viewed_hero=id
	if account["heroes"][id]["owned"]: account["selected_hero"]=id; _save()
	show_page("barracks")

func _portrait(parent: Node, id: String) -> void:
	var space := Control.new(); space.custom_minimum_size=Vector2(200,150); space.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(space)
	var actor := CampaignProfiles.create_actor(CampaignProfiles.hero(id,account),space)
	actor.position=Vector2(105,78); actor.freeze=true; actor.collision_layer=0; actor.collision_mask=0
	for child in actor.get_children():
		child.set_physics_process(false)
		if child.has_method("_process"): child.call("_process",0.0)
		child.set_process(false)
	actor.set_physics_process(false); actor.set_process(false)
	for name_value in ["HealthDisplay","CooldownIndicator","BerserkIndicator"]: actor.get_node(name_value).hide()
func _upgrade(id: String, skill: String) -> void:
	if not account["active_run"].is_empty(): return
	var candidate := account.duplicate(true)
	if CampaignProgression.upgrade(candidate,id,skill): _commit_account(candidate); show_page("barracks")

func _weapons(box: VBoxContainer, id: String, locked: bool) -> void:
	if id=="vampire": box.add_child(_label("Редкость клыков сохраняется для будущей эволюции. Дальность остаётся исходной на каждой ступени.",16,GOLD))
	var hero: Dictionary = account["heroes"][id]
	box.add_child(_label("Оружие · "+CampaignProgression.data()["rarity_names"][int(hero["equipped_rarity"])]))
	for tier in 4:
		var text := "%s ×%d · длина %.0f%%"%[CampaignProgression.data()["rarity_names"][tier],hero["weapon_cards"][tier],100.0 if id=="vampire" else float(CampaignProgression.data()["rarity_factors"][tier])*100]
		if tier<3: _button(box,text+" · слить 3 → 1",_merge.bind(id,tier),locked or int(hero["weapon_cards"][tier])<3)
		else: box.add_child(_label(text,16,BLUE))
	if OS.is_debug_build(): _button(box,"Отладка: +1 обычная карта оружия",_debug_weapon.bind(id),locked)
func _merge(id: String, tier: int) -> void:
	if not account["active_run"].is_empty(): return
	var candidate := account.duplicate(true)
	if CampaignProgression.merge(candidate,id,tier): _commit_account(candidate); show_page("barracks")
func _debug_weapon(id: String) -> void:
	if not OS.is_debug_build() or not account["active_run"].is_empty(): return
	account["heroes"][id]["weapon_cards"][0]+=1; _save(); show_page("barracks")

func _shop() -> void:
	content.add_child(_label("Магазин · только игровые монеты",28,GOLD))
	for id in CampaignProgression.playable_ids():
		var owned: bool = account["heroes"][id]["owned"]
		var price := int(CampaignProgression.data()["prices"][id])
		_button(content,"%s · %s"%[CampaignProgression.data()["players"][id]["name"],"открыт" if owned else "%d монет"%price],_buy.bind(id),owned or account["coins"]<price)
	var features: Dictionary = account["features"]
	content.add_child(_label("Союзник — будущая система. После пятого босса можно открыть слот за 2200 монет. Союзники пока не участвуют в боях.",18,BLUE))
	_button(content,"Слот союзника · %s"%("приобретён" if features["ally_slot_owned"] else "2200 монет"),_buy_ally,not features["ally_slot_available"] or features["ally_slot_owned"] or account["coins"]<2200)
func _buy(id: String) -> void:
	var candidate := account.duplicate(true)
	if CampaignProgression.buy_hero(candidate,id): _commit_account(candidate); show_page("shop")
func _buy_ally() -> void:
	var features: Dictionary = account["features"]
	if not features["ally_slot_available"] or features["ally_slot_owned"] or account["coins"]<2200: return
	var candidate := account.duplicate(true)
	candidate["coins"]-=2200; candidate["features"]["ally_slot_owned"]=true; _commit_account(candidate); show_page("shop")

func _commit_account(candidate: Dictionary) -> bool:
	if save_blocked: return false
	var result := CampaignSave.write(candidate,save_path)
	if result!=OK:
		save_warning="Запись не удалась (ошибка %d). Покупка или переход отменены; повторите попытку."%result
		return false
	account=candidate
	save_warning=""
	return true

func back() -> void:
	if page=="battle": _pause()
	elif page=="levels": _save(); closed.emit()
	elif page=="reward": show_page("levels")
	else: show_page("levels")

func _exit_tree() -> void:
	if is_instance_valid(_layout_viewport) and _layout_viewport.size_changed.is_connected(_resize): _layout_viewport.size_changed.disconnect(_resize)
	_clear_battle()
