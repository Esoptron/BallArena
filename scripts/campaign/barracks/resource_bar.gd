extends HBoxContainer
const UI := preload("res://scripts/campaign/barracks/ui.gd")
var counters: Dictionary = {}
func _ready() -> void:
	add_theme_constant_override("separation",6)
	for wallet in ["coins","xp","crystals"]:
		var box := UI.panel(self,"steel",7)
		var line := UI.row(box,3)
		line.add_child(UI.icon({"coins":"coin","xp":"xp","crystals":"diamond"}[wallet],30))
		var number := UI.label("0",18); line.add_child(number); counters[wallet]=number
		box.get_parent().tooltip_text={"coins":"Монеты","xp":"Общий опыт","crystals":"Кристаллы"}[wallet]
func refresh(account: Dictionary) -> void:
	for wallet in counters:
		counters[wallet].text=str(account[wallet]) if wallet=="crystals" else CampaignEconomy.text(CampaignEconomy.wallet_units(account,wallet),4)
