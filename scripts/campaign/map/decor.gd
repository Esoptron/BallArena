extends Node2D
## Only visible scenery chunks are retained. No bitmap panoramas or particles.
var kind := "upper"
var palette: Dictionary = {}
var view_start := 0.0
var view_end := 900.0
var view_top := 0.0
var view_bottom := 260.0

func set_view(left: float, right: float, top: float, bottom: float, theme: Dictionary) -> void:
	view_start = left; view_end = right; view_top = top; view_bottom = bottom; palette = theme
	queue_redraw()

func _draw() -> void:
	if palette.is_empty(): return
	if kind == "upper":
		draw_polygon(PackedVector2Array([Vector2(view_start,view_top),Vector2(view_end,view_top),Vector2(view_end,view_bottom),Vector2(view_start,view_bottom)]),PackedColorArray([Color(palette["sky_top"]),Color(palette["sky_top"]),Color(palette["sky_bottom"]),Color(palette["sky_bottom"])]))
		for index in range(floori(view_start/220)-1,ceili(view_end/220)+1): _fortress(index)
	else:
		for index in range(floori(view_start/150)-1,ceili(view_end/150)+1): _foreground(index)

func _fortress(index: int) -> void:
	var x := index*220.0
	var height := 68.0 + fposmod(index*37.0,51.0)
	var stone := Color(palette["far_wall"])
	draw_rect(Rect2(x,111,220,86),stone.darkened(0.23))
	for brick in 6: draw_line(Vector2(x+brick*39,114),Vector2(x+brick*39,180),stone.darkened(0.36),1)
	draw_rect(Rect2(x+60,178-height,57,height+25),stone)
	draw_rect(Rect2(x+55,173-height,67,10),stone.lightened(0.13))
	for tooth in 4: draw_rect(Rect2(x+57+tooth*17,165-height,12,9),stone.lightened(0.08))
	for window in 2:
		var point := Vector2(x+73+window*20,191-height)
		draw_rect(Rect2(point-Vector2(2,3),Vector2(5,14)),Color("111a2a"))
		draw_line(point,point+Vector2(0,7),Color("c99960"),1.5,true)
	draw_line(Vector2(x+88,173-height),Vector2(x+88,133-height),stone.lightened(0.25),2,true)
	draw_colored_polygon(PackedVector2Array([Vector2(x+90,136-height),Vector2(x+124,142-height),Vector2(x+119,163-height),Vector2(x+90,158-height)]),Color(palette["banner"]))
	draw_line(Vector2(x+98,140-height),Vector2(x+98,155-height),Color("c8864e"),1.5,true)
	var chain := PackedVector2Array()
	for step in 13: chain.append(Vector2(x+step*220.0/12,91+9*sin(step*PI/12)))
	draw_polyline(chain,stone.lightened(0.12),2,true)
	for step in 8: draw_circle(Vector2(x+step*29,92+8*sin(step*PI/7)),2,stone.lightened(0.2))

func _foreground(index: int) -> void:
	var x := index*150.0
	var lava := Color(palette["lava"])
	draw_rect(Rect2(x,248,151,maxf(30,view_bottom-248)),lava.darkened(0.5))
	draw_line(Vector2(x,249),Vector2(x+150,249),lava.lightened(0.12),2,true)
	var rock := PackedVector2Array([Vector2(x,262),Vector2(x+18,254),Vector2(x+41,258),Vector2(x+70,250),Vector2(x+99,257),Vector2(x+130,253),Vector2(x+150,261),Vector2(x+150,maxf(285,view_bottom)),Vector2(x,maxf(285,view_bottom))])
	draw_colored_polygon(rock,Color("111722"))
	draw_polyline(PackedVector2Array([Vector2(x+15,270),Vector2(x+42,262),Vector2(x+51,273)]),lava.darkened(0.15),1.5,true)
