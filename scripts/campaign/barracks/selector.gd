extends ScrollContainer
signal selected(id: String)
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const PREVIEW := preload("res://scripts/campaign/barracks/preview.gd")
var cards: Dictionary = {}
var previews: Dictionary = {}
var locks: Dictionary = {}
var line: HBoxContainer

func _ready() -> void:
	horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size.y=58
	line=UI.row(self,6); line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for id in CampaignProgression.playable_ids():
		var button := UI.button("",func() -> void: selected.emit(id))
		button.custom_minimum_size=Vector2(142,54); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.tooltip_text=CampaignProgression.data()["players"][id]["name"]
		line.add_child(button); cards[id]=button
		var margin := MarginContainer.new(); margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,9)
		button.add_child(margin)
		var row := UI.row(margin,2); row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var preview := PREVIEW.new(); preview.custom_minimum_size=Vector2(48,48)
		preview.render_size=Vector2i(128,128)
		row.add_child(preview); previews[id]=preview
		var text := UI.label(CampaignProgression.data()["players"][id]["name"],15)
		text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(text)
		var lock := UI.icon("lock",19); row.add_child(lock); locks[id]=lock

func refresh(account: Dictionary, current: String) -> void:
	for id in cards:
		UI.style_button(cards[id],id==current)
		locks[id].visible=not account["heroes"][id]["owned"]
		previews[id].display(id,account)

func reveal(id: String) -> void:
	if cards.has(id): ensure_control_visible(cards[id])
