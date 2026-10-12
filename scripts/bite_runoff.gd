extends Node2D
## Optional cosmetic experiment. At most two short paths; no fluid simulation.
## Removing this node or disabling Arena.experimental_blood_runoff leaves bite wounds intact.

const LIFETIME := 4.0
const DROP_PERIOD := 0.70
const DROP_RADIUS := 4.2
const SAMPLES := 24
var fighter: ArenaBall
var paths: Array[Dictionary] = []
var age: float = 0.0
var active: bool = false
var first_arrival: float = 0.0
var emitted: int = 0


func _ready() -> void:
	fighter = get_parent() as ArenaBall
	set_process(false)


func start(origins: PackedVector2Array, radius: float) -> void:
	paths.clear()
	age = 0.0
	first_arrival = INF
	emitted = 0
	for origin in origins:
		var full := PackedVector2Array()
		var side := -1.0 if origin.x < 0.0 else 1.0
		var edge_radius := maxf(1.0, radius - 1.5)
		for index in SAMPLES + 1:
			var t := float(index) / SAMPLES
			var y := lerpf(origin.y, edge_radius, t)
			var edge_x := side * sqrt(maxf(0.0, edge_radius * edge_radius - y * y))
			var blend := smoothstep(0.0, 0.22, t)
			full.append(Vector2(lerpf(origin.x, edge_x, blend), y))
		var length := 0.0
		for index in range(1, full.size()):
			length += full[index].distance_to(full[index - 1])
		var arrival := maxf(0.14, length / (radius * 1.15))
		first_arrival = minf(first_arrival, arrival)
		paths.append({"points": full, "radius": radius, "arrival": arrival})
	active = not paths.is_empty()
	set_process(active)
	queue_redraw()


func _process(delta: float) -> void:
	if not fighter.experimental_blood_runoff:
		clear()
		return
	advance(delta)


func clear() -> void:
	active = false
	paths.clear()
	set_process(false)
	queue_redraw()


func advance(delta: float) -> void:
	if not active:
		return
	age = minf(age + delta, LIFETIME)
	var count := maxi(0, int(floor((age - first_arrival) / DROP_PERIOD + 0.000001)))
	while emitted < count:
		emitted += 1
		if is_instance_valid(fighter.blood_effects):
			var bottom := sample_point(paths[0], 1.0)
			var center := bottom + Vector2.DOWN * DROP_RADIUS * 1.9
			fighter.blood_effects.call("spawn_drop", fighter.to_global(center), DROP_RADIUS)
	if age >= LIFETIME:
		clear()
	else:
		queue_redraw()


func sample_point(path: Dictionary, progress: float) -> Vector2:
	var points: PackedVector2Array = path["points"]
	var scaled := clampf(progress, 0.0, 1.0) * SAMPLES
	var index := mini(int(scaled), SAMPLES - 1)
	return points[index].lerp(points[index + 1], scaled - index) 		* (fighter.visual_diameter() * 0.5 / float(path["radius"]))


func _draw() -> void:
	if not active:
		return
	var alpha := 1.0 - smoothstep(3.5, LIFETIME, age)
	for path in paths:
		var arrival: float = path["arrival"]
		var head := clampf(age / arrival, 0.0, 1.0)
		# The trailing start drains toward the bottom while the advancing head flows down.
		var tail := clampf((age - 0.32) / (LIFETIME - 0.32), 0.0, 1.0)
		if head > tail:
			var points := PackedVector2Array()
			var outline_colors := PackedColorArray()
			var blood_colors := PackedColorArray()
			var shine_colors := PackedColorArray()
			for index in SAMPLES + 1:
				var t := float(index) / SAMPLES
				points.append(sample_point(path, lerpf(tail, head, t)))
				var opacity := alpha * smoothstep(0.0, 0.16, t)
				outline_colors.append(Color(0.19, 0.002, 0.013, opacity))
				blood_colors.append(Color(0.70, 0.008, 0.031, opacity))
				shine_colors.append(Color(1.0, 0.69, 0.64, opacity * (0.35 + 0.4 * sin(t * PI))))
			var wet_head := points[points.size() - 1]
			draw_circle(wet_head, 2.25, Color(0.19, 0.002, 0.013, alpha))
			draw_polyline_colors(points, outline_colors, 4.5, true)
			draw_polyline_colors(points, blood_colors, 3.2, true)
			draw_circle(wet_head, 1.60, Color(0.75, 0.01, 0.035, alpha))
			var glints := PackedVector2Array()
			for point in points:
				glints.append(point + Vector2(-0.45, -0.35))
			draw_polyline_colors(glints, shine_colors, 0.85, true)
			draw_circle(wet_head + Vector2(-0.5, -0.4), 0.35, Color(1.0, 0.8, 0.73, alpha * 0.8))
	if age >= first_arrival:
		var growth := fmod(age - first_arrival, DROP_PERIOD) / DROP_PERIOD
		var bottom := sample_point(paths[0], 1.0)
		var radius := DROP_RADIUS * smoothstep(0.0, 0.76, growth)
		if radius > 0.1:
			var center := bottom + Vector2.DOWN * radius * lerpf(0.4, 1.9, growth)
			var neck := lerpf(2.4, 0.35, smoothstep(0.65, 1.0, growth))
			draw_line(bottom, center, Color(0.25, 0.002, 0.016, alpha), neck + 1.1, true)
			draw_line(bottom, center, Color(0.74, 0.01, 0.034, alpha), neck, true)
			BloodDrawing.draw_drop(self, center, radius, alpha)
