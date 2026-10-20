extends VBoxContainer
## Read-only campaign encyclopedia. Only the selected actor is instantiated.
const STYLES := preload("res://scripts/ui/menu_styles.gd")
const ART := preload("res://scripts/campaign/combat/boss_art.gd")
const BLUE := Color("83b2ff")
const GOLD := Color("e2b46d")
const WEIGHTS := ["лёгкий", "легче среднего", "средний", "тяжелее среднего", "тяжёлый"]
const DESCRIPTIONS := {
	"fencer": "Лёгкий дуэлянт с быстрой рапирой. На близкой дистанции совершает выпад; между выпадами есть пауза.",
	"spearman": "Держит врага на расстоянии. Урон наносит только наконечник копья; древко может оттолкнуть противника.",
	"axe": "Тяжёлая секира сильно толкает цель. После попадания вращение ненадолго замедляется.",
	"shield": "Щит сокращает прямой урон спереди на 35%. Удары с других сторон и периодический урон обходят эту защиту.",
	"crossbow": "Перед выстрелом коротко готовит арбалет. Болт летит по зафиксированному направлению и не преследует цель.",
	"hammer": "Тяжёлый молот с мощным отбрасыванием. Попадание ненадолго снижает скорость движения жертвы на 10%.",
	"flail": "Урон наносит груз на конце цепи. Цепь участвует в столкновениях оружия; груз раскачивается при вращении.",
	"boomerang": "Бросает бумеранг по дуге и ждёт его возвращения. Один бросок может повредить каждую цель только один раз.",
	"chakram": "Быстро вращает широкий диск. Лёгкое тело и лёгкое оружие делают этого врага подвижным бойцом ближнего боя.",
	"harpoon": "Попадает наконечником гарпуна и ненадолго подтягивает цель. У притягивания отдельная перезарядка; оно не обездвиживает полностью.",
	"sickle": "Серп с вероятностью 15% оставляет порез: 0,2 HP в секунду на 4 секунды. Одновременно действуют до двух порезов.",
	"trident": "Три наконечника увеличивают охват. Они используют общую перезарядку и не наносят тройной урон при одном контакте.",
	"alchemist": "Бросает колбы. После падения появляется небольшая опасная зона на 2 секунды, наносящая 0,5 HP в секунду. Одновременно поддерживает одну свою зону.",
	"pyro": "Огненный снаряд наносит прямой урон и поджигает цель: ещё 1 HP за 3 секунды. Повторный огонь обновляет горение.",
	"cryo": "Ледяной снаряд на 1,6 секунды замедляет вращение оружия на 15%. У вампира вместо этого замедляется движение.",
	"magnet": "После заметной подготовки притягивает ближайших врагов магнитным полем. Урон получает только цель, оказавшаяся вплотную.",
	"bridge_guard": "БОСС · Копьё и щит с противоположной стороны. Щит сокращает прямой урон на 35%; периодическая защитная стойка — на 55%. Ниже половины HP оружие вращается быстрее.",
	"chain_maestro": "БОСС · Длинный цеп с периодическим увеличением досягаемости. Ниже 40% HP вращается быстрее, а цеп становится ещё длиннее.",
	"storm_crossbow": "БОСС · Чередует один быстрый болт и два расходящихся болта. Перед выстрелом готовится; ниже 40% HP стреляет чаще.",
	"nox": "БОСС · Чередует три вида колб и поддерживает до двух опасных зон. У разных смесей отличаются вид и периодический урон. Ниже 40% HP бросает колбы чаще.",
	"magnetic_archon": "БОСС · После подготовки притягивает, затем отталкивает врагов. Урон наносится только вблизи, отталкивание не добавляет урона. Ниже 40% HP способность применяется чаще.\n\nМагнитный дрон: после прямого несмертельного попадания, оставившего Архонту меньше половины HP, он один раз вызывает маленького помощника. Дрон использует магнитное поле; его здоровье и скорость показаны ниже."
}
var selected_id := ""
var filter_kind := 0
var visible_ids: Array[String] = []
var selector: OptionButton
var detail: PanelContainer
var portrait_actor: ArenaBall
var previous_button: Button
var next_button: Button

func _ready() -> void:
	add_theme_constant_override("separation",12)
	var heading := HBoxContainer.new(); add_child(heading)
	var title := _label("БЕСТИАРИЙ",26,GOLD)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(title)
	var filters := OptionButton.new(); filters.custom_minimum_size=Vector2(230,44)
	filters.add_theme_font_size_override("font_size",18)
	for text in ["Все · 21", "Противники · 16", "Боссы · 5"]: filters.add_item(text)
	filters.item_selected.connect(_filter); heading.add_child(filters)
	var navigation := HBoxContainer.new(); add_child(navigation)
	previous_button=_button(navigation,"‹",_step.bind(-1))
	previous_button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	selector=OptionButton.new(); selector.custom_minimum_size=Vector2(0,52)
	selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	selector.add_theme_font_size_override("font_size",20)
	selector.item_selected.connect(_select_index); navigation.add_child(selector)
	next_button=_button(navigation,"›",_step.bind(1))
	next_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	_filter(0)

func _label(text: String, font_size: int = 18, colour: Color = Color("eef3ff")) -> Label:
	var label := Label.new(); label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",colour)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := STYLES.battle_button(text,BLUE)
	button.custom_minimum_size=Vector2(52,52)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",18)
	button.pressed.connect(action); parent.add_child(button)
	return button

func _filter(kind: int) -> void:
	filter_kind=kind; visible_ids.clear(); selector.clear()
	for id: String in CampaignCatalog.data():
		var enemy: Dictionary = CampaignCatalog.data()[id]
		var boss := enemy.has("boss")
		if (kind==1 and boss) or (kind==2 and not boss): continue
		visible_ids.append(id)
		selector.add_item(("★ " if boss else "")+String(enemy["name"]))
	for index in visible_ids.size():
		selector.set_item_text(index,"%d/%d · %s"%[index+1,visible_ids.size(),selector.get_item_text(index)])
	_select_index(maxi(0,visible_ids.find(selected_id)))

func _step(direction: int) -> void:
	_select_index(posmod(selector.selected+direction,visible_ids.size()))

func _select_index(index: int) -> void:
	if index<0 or index>=visible_ids.size(): return
	selected_id=visible_ids[index]; selector.select(index)
	# Free immediately so paging never keeps old preview bodies alive for a frame.
	if is_instance_valid(detail): detail.free()
	detail=PanelContainer.new()
	detail.add_theme_stylebox_override("panel",STYLES.box(Color("111d30"),Color("344762"),16,16,14))
	add_child(detail)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); detail.add_child(box)
	var profile := CampaignCatalog.enemy(selected_id)
	var definition := profile["definition"] as CharacterDefinition
	var enemy: Dictionary = profile["enemy"]
	box.add_child(_label(definition.display_name,28,GOLD if enemy.has("boss") else BLUE))
	var preview := Control.new(); preview.custom_minimum_size=Vector2(240,140)
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(preview)
	portrait_actor=CampaignProfiles.create_actor(profile,preview)
	portrait_actor.position=Vector2(130,75); portrait_actor.freeze=true
	portrait_actor.collision_layer=0; portrait_actor.collision_mask=0
	portrait_actor.ball_color=ART.colour(selected_id,Color("ff293b"))
	ART.attach(portrait_actor,selected_id)
	# Diagonal presentation keeps long weapons inside the portrait, below its title.
	var weapon := portrait_actor.get_node("CampaignWeapon") as Node2D
	weapon.rotation=-PI*0.8
	for child in portrait_actor.get_children():
		child.set_physics_process(false)
		if child.has_method("_process"): child.call("_process",0.0)
		child.set_process(false)
	portrait_actor.set_process(false); portrait_actor.set_physics_process(false)
	for node_name in ["HealthDisplay","CooldownIndicator","BerserkIndicator"]: portrait_actor.get_node(node_name).hide()
	box.add_child(_label(DESCRIPTIONS.get(selected_id,"Описание пока не добавлено.")))
	var parameters: Dictionary = definition.abilities[0].parameters
	box.add_child(_label("БАЗОВЫЕ ХАРАКТЕРИСТИКИ",16,GOLD))
	box.add_child(_label("HP %s · урон %s · скорость %.0f ед/с\nПерезарядка %.1f с · вращение %.2f об/с\nВес тела: %s · вес оружия: %s"%[
		CampaignUnits.text(definition.starting_health),CampaignUnits.text(parameters["base_damage"]),definition.movement_speed,
		parameters["hit_cooldown"],float(parameters["spin_speed"])/TAU,
		WEIGHTS[definition.weight_class],WEIGHTS[definition.abilities[0].weapon_weight_class]]))
	box.add_child(_label("HP и урон могут отличаться в конкретной битве. Ниже указаны её фактические начальные значения.",16,BLUE))
	box.add_child(_label("ГДЕ ВСТРЕЧАЕТСЯ",16,GOLD))
	for encounter in encounters(selected_id): box.add_child(_label(encounter,16))
	if selected_id=="magnetic_archon":
		var drone := CampaignCatalog.enemy("magnet",{"hp":15,"damage":1,"size":0.65,"speed":310})["definition"] as CharacterDefinition
		box.add_child(_label("Призыв · магнитный дрон: %s HP · урон 1 · скорость %.0f ед/с. Встречается только вместе с Архонтом."%[CampaignUnits.text(drone.starting_health),drone.movement_speed],16,BLUE))

static func encounters(id: String) -> Array[String]:
	var result: Array[String] = []
	for level in CampaignLevels.all():
		for index in level["battles"].size():
			for enemy in level["battles"][index]["enemies"]:
				if enemy["id"]!=id: continue
				var definition := CampaignCatalog.enemy(id,enemy)["definition"] as CharacterDefinition
				result.append("%d–%02d · %s · %s HP · урон %s"%[level["level"],index+1,level["name"],CampaignUnits.text(definition.starting_health),CampaignUnits.text(definition.abilities[0].parameters["base_damage"])])
	return result
