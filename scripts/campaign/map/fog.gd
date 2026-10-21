extends Control
## Small terminal-only fog, suspended whenever outside the viewport.
var clock := 0.0
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sign := Label.new(); sign.name = "ComingSoon"
	sign.text = CampaignMapData.config()["terminal"]["label"]
	sign.position = Vector2(30,102); sign.size = Vector2(330,54)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_theme_font_size_override("font_size",30)
	sign.add_theme_color_override("font_color",Color("edd7b0"))
	sign.add_theme_color_override("font_shadow_color",Color("080e18"))
	sign.add_theme_constant_override("shadow_offset_y",3)
	add_child(sign)
	set_process(false)

func set_animation_visible(value: bool) -> void:
	set_process(value)

func _process(delta: float) -> void:
	clock += delta; _elapsed += delta
	if _elapsed<1.0/24.0: return
	_elapsed = 0; queue_redraw()

func _draw() -> void:
	for index in 8:
		var x := 15+index*size.x/8+sin(clock*0.35+index)*10
		for layer in range(3,0,-1):
			draw_set_transform(Vector2(x,120+sin(clock*0.2+index*1.4)*50),0,Vector2(1.3,0.7))
			draw_circle(Vector2.ZERO,45+layer*13,Color(0.19,0.24,0.32,0.055))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(18,94,350,64),Color(0.035,0.055,0.085,0.75))
	draw_line(Vector2(25,96),Vector2(360,96),Color("526078"),2,true)
	draw_line(Vector2(30,162),Vector2(353,162),Color("313e53"),2,true)
