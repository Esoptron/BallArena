extends Node2D
var points: Array[Vector2] = []
var view_start := 0.0
var view_end := 2000.0
func set_view(left: float, right: float) -> void:
	view_start=left; view_end=right; queue_redraw()
func _ready() -> void: queue_redraw()
func _draw() -> void:
	for index in range(points.size()-1):
		var a := points[index]+Vector2(0,275)
		var b := points[index+1]+Vector2(0,275)
		if b.x<view_start-50 or a.x>view_end+50: continue
		var curve := PackedVector2Array()
		for step in 51: curve.append(a.bezier_interpolate(a+Vector2(120,12),b-Vector2(120,12),b,step/50.0))
		for step in range(3,49,4):
			var next: Vector2=curve[step+1]
			draw_line(curve[step],next,Color(1,0.48,0.14,0.23),16,true)
			draw_line(curve[step],next,Color("ffe9b1"),7,true)
