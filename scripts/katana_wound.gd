@tool
extends Node2D
## Four stable stages of one cut, independent of the unlimited bleeding stacks.
const HALF_LENGTHS := [19.5, 23.0, 27.0, 30.0]
var _stage := -1
var _diameter := -1.0

func _process(_delta: float) -> void:
	var fighter := get_parent() as ArenaBall
	if fighter == null:
		return
	var stage := fighter.katana_wound_stage
	var diameter := fighter.visual_diameter()
	visible = stage > 0
	if stage != _stage or not is_equal_approx(diameter, _diameter):
		_stage = stage
		_diameter = diameter
		queue_redraw()

func emission_segment() -> PackedVector2Array:
	var fighter := get_parent() as ArenaBall
	var s := fighter.visual_diameter() / 70.0
	var half_length: float = HALF_LENGTHS[clampi(fighter.katana_wound_stage, 1, 4) - 1] * 0.8
	var center := Vector2(0.8, 2.0) * s
	var offset := Vector2.from_angle(-0.62) * half_length * s
	return PackedVector2Array([to_global(center - offset), to_global(center + offset)])

func _draw() -> void:
	var fighter := get_parent() as ArenaBall
	if fighter == null or fighter.katana_wound_stage <= 0:
		return
	var stage := clampi(fighter.katana_wound_stage, 1, 4)
	var s := fighter.visual_diameter() / 70.0
	var lengths := HALF_LENGTHS
	var widths := [0.65, 1.45, 2.55, 4.15]
	var half_length: float = lengths[stage - 1]
	var half_width: float = widths[stage - 1]
	# Lower left to upper right, as in the approved reference. Kept on the body,
	# rather than attached to the rotating weapon or the vampire's fang artwork.
	draw_set_transform(Vector2(0.8, 2.0) * s, -0.62, Vector2.ONE * s)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for index in 19:
		var t := index / 18.0
		var taper := pow(sin(t * PI), 0.8)
		var jagged := 1.0 + 0.20 * sin(index * 2.7) + 0.10 * sin(index * 5.1)
		var x := lerpf(-half_length, half_length, t)
		upper.append(Vector2(x, -half_width * taper * jagged))
		lower.append(Vector2(x, half_width * taper * (1.0 + 0.22 * sin(index * 3.9))))
	var rim := upper.duplicate()
	for index in range(lower.size() - 1, -1, -1):
		rim.append(lower[index])
	var edge := rim.duplicate()
	edge.append(edge[0])
	draw_polyline(edge, Color(0.37, 0.004, 0.02), 2.0 + stage * 0.22, true)
	draw_colored_polygon(rim, Color(0.22, 0.002, 0.014))
	draw_polyline(lower, Color(0.78, 0.018, 0.04), 0.75 + stage * 0.10, true)
	# A narrow recess and wet irregular edges give the wound depth and shine.
	var recess := PackedVector2Array()
	for point in upper:
		recess.append(Vector2(point.x * 0.93, point.y * 0.58))
	for index in range(lower.size() - 1, -1, -1):
		recess.append(Vector2(lower[index].x * 0.93, lower[index].y * 0.48))
	draw_colored_polygon(recess, Color(0.055, 0.001, 0.008))
	for index in range(3, 16, 3):
		var point := upper[index] + Vector2(0, -0.35)
		draw_line(point, upper[index + 1] + Vector2(0, -0.35), Color(1.0, 0.24, 0.27), 0.65, true)
		if stage >= 3:
			var bottom := lower[index]
			draw_line(bottom, bottom + Vector2(-1.2, 0.8 + stage * 0.18), Color(0.70, 0.025, 0.04), 0.65, true)
	# Deterministic specks: no per-frame RNG, particles or image processing.
	for index in (stage - 1) * 7:
		var t := fmod(index * 0.6180339 + 0.15, 1.0)
		var x := lerpf(-half_length * 0.88, half_length * 0.88, t)
		var side := -1.0 if index % 2 == 0 else 1.0
		var y := side * (half_width * sin(t * PI) + 1.7 + fmod(index * 1.37, 3.3))
		var p := Vector2(x, y)
		var radius := 0.23 + fmod(index * 0.31, 0.40)
		draw_circle(p, radius + 0.15, Color(0.28, 0.004, 0.016))
		draw_circle(p + Vector2(-0.09, -0.12), radius * 0.52, Color(0.86, 0.035, 0.045))
	draw_set_transform(Vector2.ZERO)
