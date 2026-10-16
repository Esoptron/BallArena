extends Node2D
const ICON := preload("res://scripts/grizzly_icon.gd")
var sword: SwordAbility
func _ready() -> void:
	sword = get_parent().get_node_or_null("Sword") as SwordAbility
func _process(_delta: float) -> void:
	var fighter := get_parent() as ArenaBall
	if not is_instance_valid(sword):
		sword = fighter.get_node_or_null("Sword") as SwordAbility
	visible = is_instance_valid(sword) and sword.is_enabled() and sword.berserk_remaining > 0.0 and fighter.current_health > 0
	if visible:
		position = Vector2(0,-fighter.visual_diameter()*0.5-18.0)
		queue_redraw()
func _draw() -> void:
	if not is_instance_valid(sword) or sword.berserk_remaining <= 0.0:
		return
	var pulse := 0.5 + 0.5*sin(sword.berserk_remaining*12.0)
	draw_circle(Vector2.ZERO,13.0,Color(0.16,0.045,0.02,0.90))
	draw_arc(Vector2.ZERO,13.0,-PI*0.5,-PI*0.5+TAU*sword.berserk_remaining/sword.berserk_duration,32,Color(1.0,0.41,0.12),1.2,true)
	ICON.draw_icon(self,Vector2.ZERO,10.0+pulse*0.7)
