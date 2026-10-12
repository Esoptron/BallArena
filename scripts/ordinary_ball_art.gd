@tool
extends Node2D


func _process(_delta: float) -> void:
	var fighter := get_parent() as ArenaBall
	visible = fighter != null and not fighter.is_vampire
	if visible:
		queue_redraw()


func _draw() -> void:
	var fighter := get_parent() as ArenaBall
	if fighter == null or fighter.is_vampire:
		return
	var radius := fighter.visual_diameter() * 0.5
	var color := fighter.body_color()
	# Shared cartoon body: a broad soft highlight and a deep lower-right crescent.
	draw_circle(Vector2.ZERO, radius + 1.25, Color(0.035, 0.015, 0.025))
	draw_circle(Vector2.ZERO, radius, color.darkened(0.26))
	var highlight_center := Vector2(-0.10, -0.13) * radius
	for layer in 18:
		var t := float(layer) / 17.0
		draw_circle(highlight_center, radius * lerpf(0.83, 0.66, t),
			color.lightened(t * 0.035))
	draw_arc(Vector2.ZERO, radius - 0.35, -PI + 0.16, -0.06, 64,
		color.lightened(0.17), 0.85, true)
	draw_arc(Vector2.ZERO, radius - 0.35, 0.08, PI - 0.12, 64,
		color.darkened(0.05), 0.65, true)

