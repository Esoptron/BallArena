extends Control
## Static canvas geometry is retained by Godot until resize; no frame updates or bitmap assets.
var hero_scene := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if not hero_scene:
		_ambient()
		return
	# Vertex-coloured bands provide a dark blue arena without full-screen blur passes.
	var horizon := size.y*0.57
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),Vector2(size.x,horizon),Vector2(0,horizon)]),PackedColorArray([Color("050d1a"),Color("07182f"),Color("08182d"),Color("071225")]))
	draw_polygon(PackedVector2Array([Vector2(0,horizon),Vector2(size.x,horizon),size,Vector2(0,size.y)]),PackedColorArray([Color("071225"),Color("08182d"),Color("040b16"),Color("040b16")]))
	var focus := Vector2(size.x*0.5,size.y*0.20)
	for layer in range(12,0,-1):
		draw_circle(focus,layer*size.x*0.032,Color(0.12,0.35,0.72,0.014))
	# Stadium rail curves and sparse lights.
	for lane in 2:
		var rail := PackedVector2Array()
		for index in 49:
			var x := float(index)/48.0
			rail.append(Vector2(x*size.x,size.y*(0.38+lane*0.075+0.10*sin(x*PI))))
		draw_polyline(rail,Color(0.16,0.36,0.65,0.22 if lane==0 else 0.10),2,true)
	for x in [0.08,0.19,0.81,0.92]:
		var light := Vector2(x*size.x,size.y*(0.43+0.085*sin(x*PI)))
		for layer in range(3,0,-1): draw_line(light-Vector2(8,0),light+Vector2(8,0),Color(0.15,0.54,0.95,0.05),layer*4,true)
		draw_line(light-Vector2(8,0),light+Vector2(8,0),Color(0.27,0.67,1,0.65),2,true)
	# Perspective floor and elliptical arena rim.
	for index in 9:
		var t := float(index)/8.0
		var y := horizon+(size.y-horizon)*t*t
		draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.13,0.35,0.64,0.18),1,true)
	for index in 11:
		var x := size.x*(float(index)/10.0)
		draw_line(Vector2(size.x*0.5+(x-size.x*0.5)*0.18,horizon),Vector2(x,size.y),Color(0.14,0.40,0.74,0.27),1,true)
	var ring := PackedVector2Array()
	for index in 129:
		var angle := index*TAU/128.0
		ring.append(Vector2(size.x*0.5,size.y*0.80)+Vector2(cos(angle)*size.x*0.54,sin(angle)*size.y*0.16))
	draw_polyline(ring,Color(0.11,0.40,0.78,0.18),7,true)
	draw_polyline(ring,Color(0.18,0.46,0.86,0.58),2,true)

func _ambient() -> void:
	var center := size*Vector2(0.84,0.24)
	for layer in range(20,0,-1):
		draw_circle(center,30.0+layer*12.0,Color(0.20,0.42,0.75,0.006))
	var other := size*Vector2(0.13,0.86)
	for layer in range(15,0,-1): draw_circle(other,20.0+layer*13,Color(0.73,0.12,0.24,0.005))
	for index in 7:
		var y := size.y*(index+0.5)/7.0
		draw_line(Vector2(0,y),Vector2(size.x,y-size.x*0.13),Color(0.27,0.37,0.52,0.035),1.0)
