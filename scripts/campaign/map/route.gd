extends Node2D
var entries: Array[Dictionary] = []
var view_start := 0.0
var view_end := 900.0

func set_view(left: float, right: float) -> void:
	view_start = left; view_end = right; queue_redraw()

func _draw() -> void:
	for index in range(entries.size()-1):
		var a := CampaignMapData.position_of(entries[index])
		var b := CampaignMapData.position_of(entries[index+1])
		if maxf(a.x,b.x)<view_start-80 or minf(a.x,b.x)>view_end+80: continue
		var points := PackedVector2Array()
		for step in 21: points.append(a.bezier_interpolate(a+Vector2(85,18),b-Vector2(85,18),b,step/20.0))
		var future: bool = entries[index+1]["is_unavailable"]
		draw_polyline(points,Color("101622"),13,true)
		draw_polyline(points,Color("42414a") if future else Color("7f634b"),7,true)
		for step in range(2,20,3): draw_circle(points[step],2.2,Color("636777") if future else Color("edb574"))
