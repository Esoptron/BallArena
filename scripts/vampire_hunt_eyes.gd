@tool
extends Node2D
## Angular red eyes follow the approved body orientation and its pulse.
var fighter: ArenaBall

func _ready() -> void:
	fighter = get_parent().get_parent() as ArenaBall
	_process(0.0)

func _process(_delta: float) -> void:
	var fangs := fighter.get_node_or_null("Vampire") as VampireFangs
	visible = fighter.is_vampire and fighter.current_health > 0 and fangs != null and fangs.hunting
	if visible: queue_redraw()

func _draw() -> void:
	if not visible: return
	var radius := fighter.visual_diameter()*0.5
	# Mirrored, slanted sockets taper toward the centre; coordinates match the reference.
	for mirror in [-1.0,1.0]:
		draw_set_transform(Vector2.ZERO,0.0,Vector2(radius*mirror,radius))
		draw_colored_polygon(PackedVector2Array([Vector2(0.68,0.025),Vector2(0.60,0.115),
			Vector2(0.44,0.22),Vector2(0.23,0.395),Vector2(0.48,0.405),
			Vector2(0.60,0.315),Vector2(0.65,0.17)]),Color(0.12,0.002,0.008))
		draw_colored_polygon(PackedVector2Array([Vector2(0.62,0.12),Vector2(0.45,0.235),
			Vector2(0.29,0.365),Vector2(0.47,0.375),Vector2(0.565,0.30)]),Color(0.49,0.008,0.025))
		draw_colored_polygon(PackedVector2Array([Vector2(0.55,0.20),Vector2(0.45,0.24),
			Vector2(0.37,0.305),Vector2(0.405,0.365),Vector2(0.49,0.35),
			Vector2(0.545,0.295)]),Color(1.0,0.025,0.035))
		draw_rect(Rect2(Vector2(0.457,0.267),Vector2(0.022,0.046)),Color(1.0,0.97,0.88))
		draw_polyline(PackedVector2Array([Vector2(0.65,0.14),Vector2(0.57,0.32),
			Vector2(0.47,0.395),Vector2(0.26,0.39)]),Color(0.75,0.04,0.06),0.025)
	draw_set_transform(Vector2.ZERO)
