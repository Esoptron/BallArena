@tool
extends Node2D
## Display the unmodified approved PNG. Two render layers preserve bite occlusion.

const SOURCE := preload("res://assets/vampire-approved-reference.png")
const SOURCE_PIVOT := Vector2(626.0, 513.0)
const BODY_DIAMETER := 566.0
static var _materials: Dictionary = {}
var fighter: ArenaBall
var body: Sprite2D
var teeth: Sprite2D


func _ready() -> void:
	fighter = get_parent() as ArenaBall
	body = _make_layer("BodyAndFur", true)
	teeth = _make_layer("Teeth", false)
	teeth.z_index = -1
	var eyes := Node2D.new()
	eyes.name = "HuntEyes"
	eyes.z_index = 1
	eyes.set_script(preload("res://scripts/vampire_hunt_eyes.gd"))
	add_child(eyes)
	_process(0.0)


func _make_layer(layer_name: String, body_layer: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = layer_name
	sprite.texture = SOURCE
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = _material(body_layer,false,1.0)
	add_child(sprite)
	return sprite


func _process(_delta: float) -> void:
	if fighter == null:
		return
	visible = fighter.is_vampire
	if not visible:
		return
	var fangs := fighter.get_node_or_null("Vampire") as VampireFangs
	if fangs != null:
		rotation = fangs.rotation + PI
	for sprite in [body, teeth]:
		var art_diameter := fighter.visual_diameter()
		if sprite == teeth and fangs != null:
			art_diameter = fangs.fang_diameter()
		var art_scale := art_diameter / BODY_DIAMETER
		sprite.position = -SOURCE_PIVOT * art_scale
		sprite.scale = Vector2.ONE * art_scale
		var material := _material(sprite == body,fighter.ball_color.b > fighter.ball_color.r,0.35 if fighter.current_health <= 0 else (0.45 if fighter.is_paralyzed() else 1.0))
		if sprite.material != material:sprite.material=material

static func _material(body_layer: bool,blue: bool,brightness: float) -> ShaderMaterial:
	var key := "%s/%s/%s" % [body_layer,blue,brightness]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/approved_vampire.gdshader")
		material.set_shader_parameter("body_layer",body_layer)
		material.set_shader_parameter("blue_variant",blue)
		material.set_shader_parameter("status_brightness",brightness)
		_materials[key]=material
	return _materials[key]
