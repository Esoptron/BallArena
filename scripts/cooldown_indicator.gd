extends Node2D
## Shared lightweight cooldown UI: retained weapon art + one small animated arc.
var fighter: ArenaBall
var _phase := 0.0
var _ratio := 0.0
func _ready() -> void:
	fighter = get_parent() as ArenaBall
	z_index = 8
	visible = false
func _process(delta: float) -> void:
	if not is_instance_valid(fighter):
		visible = false
		return
	_phase += delta
	var remaining := 0.0
	var duration := 1.0
	for ability in fighter.combat_components:
		if not is_instance_valid(ability):
			continue
		var time := ability.cooldown_time_left() if ability.is_enabled() else 0.0
		var item := ability.cooldown_visual()
		if item != null:
			# Slow, gentle two-second pulse; never hide a weapon completely.
			item.self_modulate.a = .72+.28*cos(_phase*PI) if time > 0 else 1.0
		if time > remaining:
			remaining = time
			duration = ability.cooldown_full_duration()
	visible = fighter.current_health > 0 and remaining > 0.000001
	if not visible: return
	_ratio = clampf(remaining/maxf(.001,duration),0.0,1.0)
	position = Vector2(0,-fighter.visual_diameter()*.5-17)
	queue_redraw()
func _draw() -> void:
	draw_circle(Vector2.ZERO,9.5,Color(.025,.045,.075,.84))
	draw_arc(Vector2.ZERO,6.5,0,TAU,24,Color(.34,.48,.62,.42),1.5,true)
	var angle := _phase*2.6
	draw_arc(Vector2.ZERO,6.5,angle,angle+TAU*maxf(.16,_ratio),24,Color(.91,.96,1,.97),2,true)
	draw_circle(Vector2.from_angle(angle)*6.5,1.6,Color(1,.79,.36))
