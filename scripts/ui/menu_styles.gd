extends RefCounted
## Shared shape construction; each screen still owns its exact colors and spacing.
static func box(fill: Color, border: Color, radius: int, horizontal_padding: float, vertical_padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = vertical_padding
	style.content_margin_bottom = vertical_padding
	return style

static func battle_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", box(Color("182337"), Color("2a3b56"), 12, 18, 14))
	button.add_theme_stylebox_override("hover", box(Color("23344d"), accent, 12, 18, 14))
	button.add_theme_stylebox_override("pressed", box(accent.darkened(0.65), accent, 12, 18, 14))
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, accent, 12, 18, 14))
	return button
