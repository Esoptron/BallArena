@tool
extends Node2D
## Thick curved tufts overlap the body's rim and hide the tooth roots.


func _draw() -> void:
	var fangs := get_parent() as VampireFangs
	if fangs == null or fangs.fighter == null or not fangs.fighter.is_vampire:
		return
	var radius := fangs.fighter.visual_diameter() * 0.5
	var color := fangs.fighter.body_color()
	for index in 15:
		var angle := lerpf(-PI * 0.85, -PI * 0.15, float(index) / 14.0)
		var length := 1.13 + 0.09 * (0.5 + 0.5 * sin(float(index) * 2.13))
		var root_left := Vector2.from_angle(angle - 0.09) * radius * 0.83
		var shoulder := Vector2.from_angle(angle - 0.12) * radius * 1.11
		var tip := Vector2.from_angle(angle + 0.065) * radius * length
		var fold := Vector2.from_angle(angle + 0.11) * radius * 1.04
		var root_right := Vector2.from_angle(angle + 0.095) * radius * 0.87
		var tuft := PackedVector2Array()
		for step in 7:
			tuft.append(fangs._cubic(root_left, shoulder, tip, tip, float(step) / 6.0))
		for step in 7:
			tuft.append(fangs._cubic(tip, fold, root_right, root_right, float(step) / 6.0))
		draw_colored_polygon(tuft, color.darkened(0.34))
		var outline := PackedVector2Array()
		for point in tuft:
			if point.length() >= radius * 0.99:
				outline.append(point)
		draw_polyline(outline, Color(0.10, 0.009, 0.02), 0.65, true)
		var ridge := PackedVector2Array()
		for step in 7:
			ridge.append(fangs._cubic(root_left.lerp(root_right, 0.4),
				shoulder.lerp(fold, 0.42), tip * 0.97, tip * 0.97, float(step) / 6.0))
		ridge.append(root_right)
		draw_colored_polygon(ridge, color.darkened(0.10))

