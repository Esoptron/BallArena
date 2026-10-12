class_name BloodDrawing
extends RefCounted
## Shared glossy teardrop silhouette for attached and detached blood.


static func draw_drop(canvas: CanvasItem, center: Vector2, radius: float, alpha: float = 1.0) -> void:
	var silhouette := PackedVector2Array()
	for point in [Vector2(0, -1.65), Vector2(0.32, -0.94), Vector2(0.68, -0.45),
			Vector2(0.94, 0.05), Vector2(0.87, 0.60), Vector2(0.53, 0.96),
			Vector2(0, 1.10), Vector2(-0.53, 0.96), Vector2(-0.87, 0.60),
			Vector2(-0.94, 0.05), Vector2(-0.68, -0.45), Vector2(-0.32, -0.94)]:
		silhouette.append(center + point * radius)
	canvas.draw_colored_polygon(silhouette, Color(0.28, 0.003, 0.014, alpha))
	canvas.draw_circle(center + Vector2(0.0, 0.15) * radius, radius * 0.77,
		Color(0.69, 0.008, 0.026, alpha))
	canvas.draw_circle(center + Vector2(-0.13, -0.02) * radius, radius * 0.50,
		Color(0.91, 0.018, 0.04, alpha))
	canvas.draw_line(center + Vector2(-0.34, -0.68) * radius,
		center + Vector2(-0.46, -0.05) * radius,
		Color(1.0, 0.87, 0.82, alpha * 0.95), maxf(0.6, radius * 0.22), true)
	canvas.draw_circle(center + Vector2(-0.32, -0.63) * radius, radius * 0.12,
		Color(1.0, 0.97, 0.91, alpha))
