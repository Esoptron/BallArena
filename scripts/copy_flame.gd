extends Control
## Shared small vector flame, with GPU flow; count redraws only on change.
const FLAME_SHADER := preload("res://shaders/copy_flame.gdshader")
static var _shared_material: ShaderMaterial
var count: int = 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(54,62)
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = FLAME_SHADER
		_shared_material.set_shader_parameter("flame_texture",preload("res://assets/ui/copy-flame.svg"))
	var flame := ColorRect.new()
	flame.name = "Flame"
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flame.show_behind_parent = true
	flame.size = Vector2(54,62)
	flame.material = _shared_material
	# Different phases keep the two cards from flickering in lockstep.
	flame.color = Color(1,1,1,float(get_instance_id()%97)/97.0)
	add_child(flame)
func set_count(value: int) -> void:
	if count == value: return
	count = value
	queue_redraw()
func _draw() -> void:
	var text := str(count)
	var font := ThemeDB.fallback_font
	var bounds := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,21)
	var point := Vector2(27-bounds.x*0.5,46)
	draw_string_outline(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,21,3,Color(0.24,0.07,0.02))
	draw_string(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color(1.0,0.98,0.88))
