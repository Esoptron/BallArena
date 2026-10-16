extends RefCounted
## Retained badge geometry shared by notices and every active Berserk status.
static var _mesh: ArrayMesh
static func draw_icon(canvas: Node2D,center: Vector2,radius: float,alpha: float=1.0) -> void:
	if _mesh == null:_mesh=_build()
	canvas.draw_mesh(_mesh,null,Transform2D(0,Vector2.ONE*radius,0,center),Color(1,1,1,alpha))
static func _build() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var dark := Color(.10,.035,.02)
	var fur := Color(.48,.25,.11)
	for side in [-1.0,1.0]:
		EffectMeshGeometry.add_circle(vertices,colors,indices,Vector2(side*.63,-.62),.34,dark)
		EffectMeshGeometry.add_circle(vertices,colors,indices,Vector2(side*.63,-.62),.22,fur)
	var face := PackedVector2Array([Vector2(-.62,-.8),Vector2(-.9,-.4),Vector2(-.92,.18),Vector2(-.68,.76),Vector2(0,1),Vector2(.68,.76),Vector2(.92,.18),Vector2(.9,-.4),Vector2(.62,-.8),Vector2(0,-.98)])
	var outline := PackedVector2Array()
	for point in face:outline.append(point*1.10)
	EffectMeshGeometry.add_polygon(vertices,colors,indices,outline,dark)
	EffectMeshGeometry.add_polygon(vertices,colors,indices,face,fur)
	EffectMeshGeometry.add_polygon(vertices,colors,indices,PackedVector2Array([Vector2(-.58,-.53),Vector2(0,-.86),Vector2(.55,-.53),Vector2(0,.08)]),Color(.64,.35,.16))
	for side in [-1.0,1.0]:
		_line(vertices,colors,indices,Vector2(side*.65,-.38),Vector2(side*.16,-.10),.17,dark)
		_line(vertices,colors,indices,Vector2(side*.55,-.15),Vector2(side*.25,-.02),.12,Color(1,.22,.08))
	EffectMeshGeometry.add_circle(vertices,colors,indices,Vector2(0,.44),.51,Color(.75,.53,.31))
	EffectMeshGeometry.add_circle(vertices,colors,indices,Vector2(0,.30),.20,dark)
	EffectMeshGeometry.add_polygon(vertices,colors,indices,PackedVector2Array([Vector2(-.36,.52),Vector2(0,.43),Vector2(.36,.52),Vector2(.24,.82),Vector2(-.24,.82)]),dark)
	for side in [-1.0,1.0]:EffectMeshGeometry.add_polygon(vertices,colors,indices,PackedVector2Array([Vector2(side*.3,.52),Vector2(side*.13,.49),Vector2(side*.2,.72)]),Color(1,.91,.74))
	_line(vertices,colors,indices,Vector2(-.15,.81),Vector2(.15,.81),.09,Color(.87,.10,.07))
	return EffectMeshGeometry.build_mesh(vertices, colors, indices)
static func _line(vertices: PackedVector3Array,colors: PackedColorArray,indices: PackedInt32Array,a: Vector2,b: Vector2,width: float,color: Color) -> void:
	var side := (b-a).normalized().orthogonal()*width*.5
	EffectMeshGeometry.add_polygon(vertices,colors,indices,PackedVector2Array([a-side,b-side,b+side,a+side]),color)
