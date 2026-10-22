extends VBoxContainer
const UI := preload("res://scripts/campaign/barracks/ui.gd")
const MODEL := preload("res://scripts/campaign/barracks/presentation.gd")
var expanded := false
var details_box: VBoxContainer
var data_account: Dictionary
var hero_id := ""

func refresh(account: Dictionary, id: String) -> void:
	data_account=account; hero_id=id
	UI.clear(self)
	UI.title(self,"Характеристики героя","rank")
	var grid := GridContainer.new(); grid.columns=2
	grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8)
	add_child(grid)
	for entry in MODEL.main_stats(id,account):
		var box := UI.panel(grid,"inset",10)
		box.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var line := UI.row(box,7)
		line.add_child(UI.icon(entry["icon"],40))
		var values := VBoxContainer.new(); values.size_flags_horizontal=Control.SIZE_EXPAND_FILL; values.add_theme_constant_override("separation",0); line.add_child(values)
		values.add_child(UI.paragraph(entry["name"],14))
		values.add_child(UI.label(entry["value"],18))
		if entry.has("max"): UI.progress(values,entry["amount"],entry["max"],UI.GREEN)
	var toggle := UI.button("Подробные параметры  "+("▴" if expanded else "▾"),_toggle)
	add_child(toggle)
	details_box=VBoxContainer.new(); details_box.visible=expanded; add_child(details_box)
	for entry in MODEL.details(id,account):
		var line := UI.row(details_box)
		var caption := UI.paragraph(str(entry[0]),14)
		caption.size_flags_stretch_ratio=1.1; line.add_child(caption)
		var detail := UI.paragraph(str(entry[1]),14,UI.INK)
		detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; line.add_child(detail)
	add_child(UI.paragraph("Постоянные параметры кампании. Временные бонусы похода и усиления в бою здесь не учитываются.",13))

func _toggle() -> void:
	expanded=not expanded
	refresh(data_account,hero_id)
