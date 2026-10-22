extends VBoxContainer
signal requested(skill: String)
const UI := preload("res://scripts/campaign/barracks/ui.gd")
var mode := 0
var account: Dictionary
var hero_id := ""
var cards: Dictionary = {}
var training: VBoxContainer
var body: VBoxContainer
var modes: Array[Button] = []

func _ready() -> void:
	var switches := UI.row(self)
	for index in 2:
		var button := UI.button(["Параметры · XP","Способность · монеты"][index],_set_mode.bind(index))
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; switches.add_child(button); modes.append(button)
	body=VBoxContainer.new(); add_child(body)

func _set_mode(value: int) -> void:
	mode=value; refresh(account,hero_id)

func refresh(next_account: Dictionary, id: String) -> void:
	account=next_account; hero_id=id
	UI.clear(body); cards.clear()
	for i in modes.size(): UI.style_button(modes[i],mode==i)
	if mode==1:
		training=preload("res://scripts/campaign/barracks/training_panel.gd").new(); body.add_child(training)
		training.refresh(account,id); training.requested.connect(requested.emit)
		return
	UI.title(body,"Прокачка параметров","rank")
	var grid := GridContainer.new(); grid.columns=2
	grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); body.add_child(grid)
	for skill in CampaignProgression.data()["players"][id]["xp_skills"]:
		var card := preload("res://scripts/campaign/barracks/upgrade_card.gd").new()
		grid.add_child(card); card.configure(account,id,skill)
		card.requested.connect(requested.emit); cards[skill]=card

func feedback(skill: String) -> void:
	if skill=="ability" and mode==1: training.card.animate_gain()
	elif cards.has(skill): cards[skill].animate_gain()
