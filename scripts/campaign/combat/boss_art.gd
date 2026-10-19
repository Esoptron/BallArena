class_name CampaignBossArt
extends Node2D
## Small vector details over the unchanged ordinary body; no textures/particles.
const COLOURS := {
	"bridge_guard": Color("647c91"), "chain_maestro": Color("46556a"),
	"storm_crossbow": Color("708aa8"), "nox": Color("315948"),
	"magnetic_archon": Color("352640")}
var kind := ""
var clock := 0.0

static func colour(id: StringName, fallback: Color) -> Color:
	return COLOURS.get(String(id),fallback)

static func attach(actor: ArenaBall, id: StringName) -> void:
	if not COLOURS.has(String(id)) or actor.has_node("CampaignBossArt"): return
	var art := CampaignBossArt.new()
	art.name="CampaignBossArt"; art.kind=String(id); actor.add_child(art)
	art.set_process(id==&"magnetic_archon")

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func _draw() -> void:
	var actor := get_parent() as ArenaBall
	if actor==null: return
	var radius := actor.visual_diameter()*0.5
	var steel := Color("b1c4d2").darkened(0.55 if actor.is_paralyzed() else 0.0)
	if kind=="nox":
		draw_line(Vector2(-radius*0.74,-radius*0.37),Vector2(radius*0.74,radius*0.37),Color("30251f"),6,true)
		for index in 3:
			var center := Vector2((index-1)*radius*0.5,radius*0.23)
			draw_rect(Rect2(center-Vector2(4,7),Vector2(8,14)),Color("182323"))
			draw_rect(Rect2(center-Vector2(2,2),Vector2(4,7)),[Color("96c45e"),Color("75bfd2"),Color("b390db")][index])
			draw_line(center-Vector2(2,8),center+Vector2(2,-8),steel,2,true)
	elif kind=="magnetic_archon":
		for index in 3:
			var angle := clock*(0.65 if index%2==0 else -0.45)+index*TAU/3
			draw_arc(Vector2.ZERO,radius+5+index*3,angle,angle+1.1,20,Color("9284c9"),1.6,true)
			draw_circle(Vector2.from_angle(angle)*(radius+5+index*3),2,Color("bcb2e7"))
	else:
		draw_arc(Vector2.ZERO,radius*0.78,-2.7,-0.4,24,steel.darkened(0.35),1.5,true)
		for index in 4:
			var point := Vector2.from_angle(index*TAU/4+PI/4)*radius*0.77
			draw_circle(point,2,Color("172331")); draw_circle(point-Vector2(0.4,0.4),1,steel)
