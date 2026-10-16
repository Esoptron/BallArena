class_name BloodDrawing
extends RefCounted
## One retained coloured mesh shared by every blood drop. Only its transform changes.
static var _mesh: ArrayMesh
static var _spark_mesh: ArrayMesh
static var _orb_mesh: ArrayMesh
const SILHOUETTE := [Vector2(0,-1.65),Vector2(.32,-.94),Vector2(.68,-.45),Vector2(.94,.05),Vector2(.87,.60),Vector2(.53,.96),Vector2(0,1.10),Vector2(-.53,.96),Vector2(-.87,.60),Vector2(-.94,.05),Vector2(-.68,-.45),Vector2(-.32,-.94)]
static func draw_drop(canvas: CanvasItem,center: Vector2,radius: float,alpha: float=1.0) -> void:
	if _mesh == null: _mesh = _build_mesh()
	canvas.draw_mesh(_mesh,null,Transform2D(0,Vector2.ONE*radius,0,center),Color(1,1,1,alpha))
static func _build_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_add_polygon(vertices,colors,indices,PackedVector2Array(SILHOUETTE),Color(.28,.003,.014))
	_add_circle(vertices,colors,indices,Vector2(0,.15),.77,Color(.69,.008,.026))
	_add_circle(vertices,colors,indices,Vector2(-.13,-.02),.50,Color(.91,.018,.04))
	var a := Vector2(-.34,-.68)
	var b := Vector2(-.46,-.05)
	var side := (b-a).normalized().orthogonal()*.11
	_add_polygon(vertices,colors,indices,PackedVector2Array([a-side,b-side,b+side,a+side]),Color(1,.87,.82,.95))
	_add_circle(vertices,colors,indices,Vector2(-.32,-.63),.12,Color(1,.97,.91))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
static func _add_polygon(vertices: PackedVector3Array,colors: PackedColorArray,indices: PackedInt32Array,polygon: PackedVector2Array,color: Color) -> void:
	var start := vertices.size()
	for point in polygon:
		vertices.append(Vector3(point.x,point.y,0))
		colors.append(color)
	for index in Geometry2D.triangulate_polygon(polygon):indices.append(start+index)
static func _add_circle(vertices: PackedVector3Array,colors: PackedColorArray,indices: PackedInt32Array,center: Vector2,radius: float,color: Color,segments: int=24) -> void:
	var polygon := PackedVector2Array()
	for index in segments:polygon.append(center+Vector2.from_angle(index*TAU/segments)*radius)
	_add_polygon(vertices,colors,indices,polygon,color)

static func get_spark_mesh() -> ArrayMesh:
	if _spark_mesh == null:
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		_add_polygon(vertices,colors,indices,PackedVector2Array([Vector2(-5,-2),Vector2(0,-2),Vector2(0,2),Vector2(-5,2)]),Color(1,.5,.08,.18))
		_add_polygon(vertices,colors,indices,PackedVector2Array([Vector2(-4,-.6),Vector2(0,-.6),Vector2(0,.6),Vector2(-4,.6)]),Color(1,.8,.3))
		_add_circle(vertices,colors,indices,Vector2.ZERO,.8,Color(1,1,.84))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_INDEX]=indices
		_spark_mesh=ArrayMesh.new()
		_spark_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _spark_mesh

static func get_orb_mesh() -> ArrayMesh:
	if _orb_mesh == null:
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		_add_circle(vertices,colors,indices,Vector2.ZERO,1.7,Color(.20,1,.32,.06))
		_add_circle(vertices,colors,indices,Vector2.ZERO,1,Color(.32,.95,.43,.35))
		_add_circle(vertices,colors,indices,Vector2(-.16,-.20),.35,Color(.75,1,.78,.5))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_INDEX]=indices
		_orb_mesh=ArrayMesh.new()
		_orb_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _orb_mesh

static func get_drop_mesh() -> ArrayMesh:
	if _mesh == null:_mesh=_build_mesh()
	return _mesh
static func draw_spark(canvas: CanvasItem,center: Vector2,angle: float,alpha: float) -> void:
	canvas.draw_mesh(get_spark_mesh(),null,Transform2D(angle,center),Color(1,1,1,alpha))
static func draw_orb(canvas: CanvasItem,center: Vector2,radius: float,alpha: float) -> void:
	canvas.draw_mesh(get_orb_mesh(),null,Transform2D(0,Vector2.ONE*radius,0,center),Color(1,1,1,alpha))
static func make_instances(mesh: ArrayMesh,capacity: int) -> MultiMeshInstance2D:
	var instance := MultiMeshInstance2D.new()
	instance.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_2D
	multi.use_colors=true
	multi.mesh=mesh
	multi.instance_count=capacity
	multi.visible_instance_count=0
	instance.multimesh=multi
	return instance
