extends Control
signal closed
signal home_requested
const STYLES := preload("res://scripts/ui/menu_styles.gd")
const BLUE := Color("83b2ff")
const GOLD := Color("e2b46d")
var account := CampaignProgression.new_account()
var page := "levels"
var content: VBoxContainer
var page_root: Control
var level_map: Control
var barracks_view: Control
var _barracks_tab := 0
var _map_center := -1.0
var _map_current := -1
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
var pending_settlement: Dictionary = {}
var pending_won := false
const RARITIES := {"common":"Обычный", "rare":"Редкий", "epic":"Эпический", "legendary":"Легендарный"}

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
	if is_instance_valid(level_map): _map_center = level_map.center_on_map()
	level_map = null
	if is_instance_valid(barracks_view): _barracks_tab=barracks_view.active_tab
	barracks_view=null
	if is_instance_valid(page_root): remove_child(page_root); page_root.queue_free()
	page_root=Control.new(); page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(page_root)
	content=null

func show_page(next: String) -> void:
	page=next; _clear_page()
	if next == "levels" and not save_blocked:
		_levels()
		return
	if next == "map_art_preview" and not save_blocked:
		_art_preview()
		return
	if next == "barracks" and not save_blocked:
		_barracks()
		return
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
	var wallet := _label("%s монет · %s XP · %d ◆"%[CampaignEconomy.text(CampaignEconomy.wallet_units(account,"coins"),4),CampaignEconomy.text(CampaignEconomy.wallet_units(account,"xp"),4),account["crystals"]],18,GOLD)
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
		"shop": _shop()
		"bestiary": content.add_child(preload("res://scripts/campaign/bestiary.gd").new())
		"reward": _reward()
		"settlement_error":
			content.add_child(_label("Награда ещё не сохранена",28,GOLD))
			content.add_child(_label("Результат боя остаётся в памяти. Повторите запись, прежде чем продолжать."))
			_button(content,"Повторить сохранение результата",_retry_settlement)
		"defeat":
			content.add_child(_label("Поражение",32,GOLD))
			_result(content)
			_button(content,"Вернуться к уровням",show_page.bind("levels"))
		"complete":
			content.add_child(_label("Уровень завершён",32,GOLD))
			_result(content)
			content.add_child(_label("Выбранный бонус сохранён для следующего уровня. Начните новый уровень с полным здоровьем."))
			_button(content,"К карте кампании",show_page.bind("levels"))

func _levels() -> void:
	level_map = preload("res://scenes/campaign/level_map.tscn").instantiate()
	var current := CampaignMapData.current_level(account)
	if current != _map_current: _map_center = -1.0
	_map_current = current
	level_map.account = account
	level_map.initial_center = _map_center
	level_map.warning = save_warning
	level_map.home_requested.connect(_go_home)
	level_map.shop_requested.connect(show_page.bind("shop"))
	level_map.barracks_requested.connect(show_page.bind("barracks"))
	level_map.bestiary_requested.connect(show_page.bind("bestiary"))
	level_map.result_requested.connect(func() -> void:
		show_page("complete" if account["last_result"]["won"] else "defeat"))
	level_map.resume_requested.connect(_resume)
	level_map.abandon_requested.connect(_confirm_abandon)
	level_map.retry_requested.connect(func() -> void:
		if _save(): save_warning = ""
		show_page("levels"))
	level_map.level_requested.connect(func(number: int) -> void:
		if account["active_run"].is_empty(): _start(number)
		elif int(account["active_run"]["level"]) == number: _resume())
	page_root.add_child(level_map)

func _art_preview() -> void:
	var view := preload("res://scenes/campaign/level_map_art_preview.tscn").instantiate()
	view.account=account
	view.back_requested.connect(show_page.bind("levels"))
	view.home_requested.connect(_go_home)
	view.shop_requested.connect(show_page.bind("shop"))
	view.barracks_requested.connect(show_page.bind("barracks"))
	view.bestiary_requested.connect(show_page.bind("bestiary"))
	view.level_requested.connect(func(number: int) -> void:
		if account["active_run"].is_empty(): _start(number)
		elif int(account["active_run"]["level"])==number: _resume())
	page_root.add_child(view)

func _go_home() -> void:
	if not _save():
		show_page("levels")
		return
	save_warning = ""
	home_requested.emit()

func _confirm_abandon() -> void:
	var dialog := ConfirmationDialog.new(); dialog.title="Завершить поход?"
	dialog.dialog_text="Поход завершится как поражение: 50% накопленного золота и весь XP сохранятся, все награды карточками будут потеряны. Временные усиления сбросятся."
	if account["active_run"]["status"]=="reward" and int(account["active_run"]["battle"])==10:
		dialog.dialog_text="Сундук уже открыт, награды сохранены. При выходе вы откажетесь только от выбора бонуса для следующего уровня."
	dialog.ok_button_text="Завершить"; dialog.cancel_button_text="Продолжить поход"; add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var candidate := account.duplicate(true)
		if CampaignRun.abandon(candidate): _commit_account(candidate); show_page("levels"))
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
	if not run["ally"].is_empty():
		lineup.append(CampaignProfiles.hero(run["ally"]["hero"],CampaignRun.profile_account(account)))
		battle_arena.set("party_size",2)
		battle_arena.set("ally_hp",run["ally"]["hp"]); battle_arena.set("ally_peak",run["ally"]["peak"])
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
	battle_stats.offset_left=20; battle_stats.offset_right=-20; battle_stats.offset_top=-25; battle_stats.offset_bottom=-4; page_root.add_child(battle_stats)
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
	if page!="battle" or _transition_pending or not is_instance_valid(battle_arena): return
	_hud_clock+=delta
	if _hud_clock<0.2: return
	_hud_clock=0
	# HP is already under every body. Keep one unobtrusive economy line outside
	# the fixed arena; complete permanent attributes remain in the barracks.
	battle_stats.text=_chest_summary(account["active_run"])

func _finished(won: bool, hp: int, peak: int) -> void:
	if _transition_pending: return
	_transition_pending=true
	var run: Dictionary = account["active_run"]
	var reward := CampaignLevels.encounter(run["level"],run["battle"])["reward"] as Dictionary
	var candidate := account.duplicate(true)
	var ally_state: Dictionary=battle_arena.call("ally_result") if is_instance_valid(battle_arena) else {}
	if not CampaignRun.settle(candidate,won,hp,peak,reward,ally_state): return
	if not _commit_account(candidate):
		pending_settlement=candidate; pending_won=won
		show_page.call_deferred("settlement_error")
		return
	_finish_transition.call_deferred(won)

func _retry_settlement() -> void:
	if pending_settlement.is_empty() or not _commit_account(pending_settlement): return
	pending_settlement={}
	_clear_battle(); show_page("reward" if pending_won else "defeat")

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
	if int(run["battle"])==10: _result(content)
	else: content.add_child(_label(_chest_summary(run)+" · откроется после босса",16,GOLD))
	content.add_child(_label("Бонус для следующего уровня" if int(run["battle"])==10 else "Усиления складываются до завершения этого уровня",18,BLUE))
	if not run["ally"].is_empty(): content.add_child(_label("Усиления относятся к основному герою. HP обоих переносится между волнами; погибшие не возвращаются до следующего уровня.",16,BLUE))
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
	barracks_view=preload("res://scenes/campaign/barracks.tscn").instantiate()
	barracks_view.account=account
	barracks_view.hero_id=viewed_hero if CampaignProgression.playable_ids().has(viewed_hero) else account["selected_hero"]
	barracks_view.active_tab=_barracks_tab; barracks_view.warning=save_warning
	barracks_view.back_requested.connect(back)
	barracks_view.shop_requested.connect(show_page.bind("shop"))
	barracks_view.hero_selected.connect(func(id: String) -> void: viewed_hero=id)
	barracks_view.primary_requested.connect(_choose_hero)
	barracks_view.ally_requested.connect(_select_ally)
	barracks_view.upgrade_requested.connect(_upgrade)
	barracks_view.merge_requested.connect(_merge)
	barracks_view.retry_requested.connect(func() -> void:
		if _save(): save_warning=""
		_refresh_barracks())
	page_root.add_child(barracks_view)

func _refresh_barracks() -> void:
	if is_instance_valid(barracks_view): barracks_view.refresh(account,save_warning)
	else: show_page("barracks")

func _select(id: String) -> void:
	viewed_hero=id
	if is_instance_valid(barracks_view): barracks_view.select_hero(id)
	else: show_page("barracks")

func _choose_hero(id: String) -> void:
	if not account["active_run"].is_empty() or not account["heroes"][id]["owned"]: return
	var candidate := account.duplicate(true); candidate["selected_hero"]=id
	_commit_account(candidate); _refresh_barracks()

func _select_ally(id: String) -> void:
	var candidate := account.duplicate(true)
	if CampaignProgression.select_ally(candidate,id): _commit_account(candidate); _refresh_barracks()

func _upgrade(id: String, skill: String) -> void:
	if not account["active_run"].is_empty(): return
	var candidate := account.duplicate(true)
	if CampaignProgression.upgrade(candidate,id,skill):
		var saved := _commit_account(candidate)
		_refresh_barracks()
		if saved and is_instance_valid(barracks_view): barracks_view.feedback("upgrade",skill)

func _merge(id: String, tier: int) -> void:
	if not account["active_run"].is_empty(): return
	var candidate := account.duplicate(true)
	if CampaignProgression.merge(candidate,id,tier):
		var saved := _commit_account(candidate)
		_refresh_barracks()
		if saved and is_instance_valid(barracks_view): barracks_view.feedback("merge")
func _debug_weapon(id: String) -> void:
	if not OS.is_debug_build() or not account["active_run"].is_empty(): return
	var candidate := account.duplicate(true)
	candidate["heroes"][id]["weapon_cards"][0]+=2
	if _commit_account(candidate): show_page("barracks")

func _shop() -> void:
	content.add_child(_label("Магазин персонажей",28,GOLD))
	for id in CampaignProgression.playable_ids():
		var owned: bool = account["heroes"][id]["owned"]
		var box := _panel(content)
		box.add_child(_label("%s · %s · %s"%[CampaignProgression.data()["players"][id]["name"],RARITIES.get(CampaignEconomy.rarity(id),"Категория не задана"),"открыт" if owned else "карточки %s/1"%CampaignEconomy.text(account["heroes"][id]["unlock_card_units"])],22,BLUE))
		for currency in CampaignEconomy.prices(id):
			var price := int(CampaignEconomy.prices(id)[currency])
			_button(box,"%d %s"%[price,"монет" if currency=="coins" else "кристаллов"],_buy.bind(id,currency),owned or int(account[currency])<price)
	var features: Dictionary = account["features"]
	content.add_child(_label("Второй боец · постоянный слот союзника. После покупки выберите открытого героя в казарме. HP переносится, погибший не возвращается до конца уровня; поражение — после гибели обоих. Слот не требуется для доступа к уровням. Платежи и источники кристаллов пока не подключены.",18,BLUE))
	for currency in CampaignEconomy.data()["ally_slot_prices"]:
		var price := int(CampaignEconomy.data()["ally_slot_prices"][currency])
		_button(content,"Слот союзника · %s"%("приобретён" if features["ally_slot_owned"] else "%d %s"%[price,"монет" if currency=="coins" else "кристаллов"]),_buy_ally.bind(currency),features["ally_slot_owned"] or account[currency]<price)
func _buy(id: String, currency: String = "coins") -> void:
	var candidate := account.duplicate(true)
	if CampaignProgression.buy_hero(candidate,id,currency): _commit_account(candidate); show_page("shop")
func _buy_ally(currency: String = "coins") -> void:
	var candidate := account.duplicate(true)
	if CampaignProgression.buy_ally(candidate,currency): _commit_account(candidate); show_page("shop")

func _chest_summary(run: Dictionary) -> String:
	return "%s сундук · %d%% · накоплено %s монет / %s XP"%[CampaignEconomy.data()["chests"][run["chest"]]["name"],int(run["reward_half_units"])*50,CampaignEconomy.text(int(run["loot"]["gold_units"]),4),CampaignEconomy.text(int(run["loot"]["xp_units"]),4)]

func _result(parent: Node) -> void:
	var result: Dictionary=account["last_result"]
	if result.is_empty(): return
	var box := _panel(parent)
	box.add_child(_label("%s сундук открыт"%CampaignEconomy.data()["chests"][result["chest"]]["name"] if result["won"] else "Сундук потерян",24,GOLD))
	var awarded: Dictionary=result["awarded"]
	box.add_child(_label("Получено: %s монет · %s XP"%[CampaignEconomy.text(int(awarded["gold_units"]),4),CampaignEconomy.text(int(awarded["xp_units"]),4)]))
	if not result["won"]: box.add_child(_label("Потеряно: %s монет и все карточки. Опыт сохранён полностью."%CampaignEconomy.text(int(result["earned"]["gold_units"])-int(awarded["gold_units"]),4),18,GOLD))
	var loot: Dictionary=awarded if result["won"] else result["earned"]
	for kind in ["weapons","characters"]:
		for id in loot[kind]: box.add_child(_label("%s%s · %s · %s карточки"%["" if result["won"] else "Потеряно: ","Оружие" if kind=="weapons" else "Герой",CampaignProgression.data()["players"][id]["name"],CampaignEconomy.text(int(loot[kind][id]))],18,BLUE))
	if loot["weapons"].is_empty() and loot["characters"].is_empty(): box.add_child(_label("Карточки в этом сундуке не выпали.",16,BLUE))
	for kind in loot["reserved_characters"]: box.add_child(_label("%s карточки редкости «%s» %s: каталог этой категории пока пуст."%[CampaignEconomy.text(int(loot["reserved_characters"][kind])),RARITIES[kind],"сохранены в резерве" if result["won"] else "потеряны"],16,GOLD))
	if int(loot["reserved_weapons"])>0: box.add_child(_label("%s карточки оружия %s: подходящих получателей нет."%[CampaignEconomy.text(int(loot["reserved_weapons"])),"сохранены в резерве" if result["won"] else "потеряны"],16,GOLD))

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
	if not pending_settlement.is_empty(): return
	if page=="battle": _pause()
	elif page=="levels": _save(); closed.emit()
	elif page=="reward": show_page("levels")
	else: show_page("levels")

func _exit_tree() -> void:
	if is_instance_valid(_layout_viewport) and _layout_viewport.size_changed.is_connected(_resize): _layout_viewport.size_changed.disconnect(_resize)
	_clear_battle()
