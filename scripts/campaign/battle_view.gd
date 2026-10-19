extends "res://scripts/main.gd"
func _ready() -> void:
	_layout_viewport=get_viewport()
	_layout_viewport.size_changed.connect(_fit_arena)
	_fit_arena()
	camera.force_update_scroll()
