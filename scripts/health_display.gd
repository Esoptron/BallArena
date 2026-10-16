@tool
extends Node2D
## Character-neutral, upright HP display below the body.

var _health := -1
var _diameter := -1.0
var _scale := -1.0
func _process(_delta: float) -> void:
	var fighter := get_parent() as ArenaBall
	if fighter == null: return
	var health := fighter.starting_health if Engine.is_editor_hint() else fighter.current_health
	var diameter := fighter.visual_diameter()
	var display_scale := get_global_transform_with_canvas().x.length()
	if health != _health or diameter != _diameter or not is_equal_approx(display_scale, _scale):
		_health = health
		_diameter = diameter
		_scale = display_scale
		queue_redraw()


func _draw() -> void:
	var fighter := get_parent() as ArenaBall
	if fighter == null:
		return
	var health := fighter.starting_health if Engine.is_editor_hint() else fighter.current_health
	var text := str(health)
	var font := ThemeDB.fallback_font
	var size := int(clampf(fighter.visual_diameter() * 0.32, 15.0, 29.0))
	# Keep HP readable when the camera fits a phone-sized arena.
	if not Engine.is_editor_hint():
		var display_scale := maxf(0.05, get_global_transform_with_canvas().x.length())
		size = maxi(size, ceili(14.0 / display_scale))
	var bounds := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := Vector2(-bounds.x * 0.5, fighter.visual_diameter() * 0.5 + 6.0 + font.get_ascent(size))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3,
		Color(0.025, 0.035, 0.055, 0.95))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0.96, 0.98, 1.0) if health > 0 else Color(0.62, 0.64, 0.68))
