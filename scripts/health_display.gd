@tool
extends Node2D
## Character-neutral, upright center HP display.


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var fighter := get_parent() as ArenaBall
	if fighter == null:
		return
	var health := fighter.starting_health if Engine.is_editor_hint() else fighter.current_health
	var text := str(health)
	var font := ThemeDB.fallback_font
	var size := int(clampf(fighter.visual_diameter() * 0.25, 12.0, 22.0))
	var bounds := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := Vector2(-bounds.x * 0.5, font.get_ascent(size) - font.get_height(size) * 0.5)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3,
		Color(0.025, 0.035, 0.055, 0.95))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0.96, 0.98, 1.0) if health > 0 else Color(0.62, 0.64, 0.68))
