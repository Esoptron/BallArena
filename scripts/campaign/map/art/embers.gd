extends Node2D
## A dozen cheap sparks; no particles, physics, blur or full-background redraw.
var clock := 0.0
var elapsed := 0.0
func _process(delta: float) -> void:
	clock+=delta; elapsed+=delta
	if elapsed<1.0/24.0: return
	elapsed=0; queue_redraw()
func _draw() -> void:
	for index in 12:
		var age := fposmod(clock*0.19+index*0.083,1.0)
		var point := Vector2(70+index*105+sin(clock+index)*9,590-age*320)
		draw_circle(point,2.2,Color(1,0.58,0.16,sin(age*PI)*0.7))
		draw_line(point,point+Vector2(2,6),Color(1,0.75,0.31,sin(age*PI)*0.3),1,true)
