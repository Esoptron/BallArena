class_name EffectMeshGeometry
extends RefCounted
## Neutral geometry helpers shared by retained effect and character meshes.


static func add_polygon(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	polygon: PackedVector2Array,
	color: Color
) -> void:
	var start := vertices.size()
	for point in polygon:
		vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append(color)
	for index in Geometry2D.triangulate_polygon(polygon):
		indices.append(start + index)


static func add_circle(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	center: Vector2,
	radius: float,
	color: Color,
	segments: int = 24
) -> void:
	var polygon := PackedVector2Array()
	for index in segments:
		polygon.append(center + Vector2.from_angle(index * TAU / segments) * radius)
	add_polygon(vertices, colors, indices, polygon, color)


static func build_mesh(
	vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array
) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
