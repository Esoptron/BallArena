extends VBoxContainer
signal requested(skill: String)
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const CARD := preload("res://scripts/campaign/barracks/upgrade_card.gd")
var card: Control
func refresh(account: Dictionary, id: String) -> void:
	UI.clear(self)
	UI.title(self,"Тренировка за монеты","coin")
	add_child(UI.paragraph("Монеты развивают уникальную способность. XP расходуется отдельно на основные параметры.",15))
	card=CARD.new(); add_child(card); card.configure(account,id,"ability")
	card.requested.connect(requested.emit)
