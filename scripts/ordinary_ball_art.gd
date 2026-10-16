@tool
extends Node2D

var _radius := -1.0
var _color := Color.TRANSPARENT
var _mesh: ArrayMesh
var _mesh_radius := -1.0
var _mesh_color := Color.TRANSPARENT

func _process(_delta: float) -> void:
	var fighter := get_parent() as ArenaBall
	visible = fighter != null and not fighter.is_vampire
	if visible:
		var radius := fighter.visual_diameter() * 0.5
		var color := fighter.body_color()
		if radius != _radius or color != _color:
			_radius = radius
			_color = color
			queue_redraw()


func _draw() -> void:
	var fighter := get_parent() as ArenaBall
	if fighter == null or fighter.is_vampire:
		return
	var radius := fighter.visual_diameter() * 0.5
	var color := fighter.body_color()
	if _mesh == null or radius != _mesh_radius or color != _mesh_color:
		_mesh_radius=radius
		_mesh_color=color
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		EffectMeshGeometry.add_circle(vertices,colors,indices,Vector2.ZERO,radius+1.25,Color(.035,.015,.025),64)
		EffectMeshGeometry.add_circle(vertices,colors,indices,Vector2.ZERO,radius,color.darkened(.26),64)
		var center := Vector2(-.10,-.13)*radius
		for layer in 18:
			var t := layer/17.0
			EffectMeshGeometry.add_circle(vertices,colors,indices,center,radius*lerpf(.83,.66,t),color.lightened(t*.035),64)
		_mesh = EffectMeshGeometry.build_mesh(vertices, colors, indices)
	draw_mesh(_mesh,null)
	draw_arc(Vector2.ZERO, radius - 0.35, -PI + 0.16, -0.06, 64,
		color.lightened(0.17), 0.85, true)
	draw_arc(Vector2.ZERO, radius - 0.35, 0.08, PI - 0.12, 64,
		color.darkened(0.05), 0.65, true)

