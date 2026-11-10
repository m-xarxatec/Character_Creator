class_name MeshBaker
extends RefCounted
## Horneado en CPU: vértices y normales finales del personaje (formas + esqueleto), sin tarjeta gráfica.
##
## Uso:
##   var baked := MeshBaker.bake(species.mesh, species.skeleton)   # {"vertices": …, "normals": …}
## Mismo orden de vértices que la superficie 0 de la malla. Es para exportar y probar, no para cada fotograma.
## - Formas: Godot guarda cada forma completa; el desplazamiento es forma − base.
## - Esqueleto: 4 huesos por vértice; matriz de cada hueso = pose global × bind pose. Los pesos se dividen por su suma.
## - Las poses globales se encadenan aquí desde las locales: get_bone_global_pose() puede dar un valor viejo
##   si se lee en el fotograma en que la escena entra en el árbol.
## - Normales: valen con escala uniforme (la de Proporción); con otra escala habría que usar la inversa traspuesta.
## - No se calculan tangentes: en el MVP no hay mapas de normales.


static func bake(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Dictionary:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_add_shapes(mesh, vertices, normals)
	_skin(skin_matrices(skeleton, mesh.skin), arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], vertices, normals)
	return {"vertices": vertices, "normals": normals}


## Pose global de cada hueso, encadenando las poses locales de padre a hijo.
static func global_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	globals.resize(skeleton.get_bone_count())
	var done := PackedByteArray()
	done.resize(globals.size())
	for i in globals.size():
		_global_pose(skeleton, i, globals, done)
	return globals


## Matriz de cada bind de la Skin: pose global × bind pose.
static func skin_matrices(skeleton: Skeleton3D, skin: Skin) -> Array[Transform3D]:
	var globals := global_poses(skeleton)
	var matrices: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(i))
		matrices.append(globals[bone] * skin.get_bind_pose(i))
	return matrices


static func _global_pose(skeleton: Skeleton3D, bone: int, globals: Array[Transform3D], done: PackedByteArray) -> Transform3D:
	if not done[bone]:
		var parent := skeleton.get_bone_parent(bone)
		var local := skeleton.get_bone_pose(bone)
		globals[bone] = local if parent < 0 else _global_pose(skeleton, parent, globals, done) * local
		done[bone] = 1
	return globals[bone]


static func _add_shapes(mesh: MeshInstance3D, vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
	var active := {}
	for shape in mesh.mesh.get_blend_shape_count():
		if mesh.get_blend_shape_value(shape) != 0.0:
			active[shape] = mesh.get_blend_shape_value(shape)
	if active.is_empty():
		return
	var base_vertices := vertices.duplicate()
	var base_normals := normals.duplicate()
	var shapes := (mesh.mesh as ArrayMesh).surface_get_blend_shape_arrays(0)
	for shape: int in active:
		var weight: float = active[shape]
		var shape_vertices: PackedVector3Array = shapes[shape][Mesh.ARRAY_VERTEX]
		var shape_normals: PackedVector3Array = shapes[shape][Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			vertices[i] += weight * (shape_vertices[i] - base_vertices[i])
			normals[i] += weight * (shape_normals[i] - base_normals[i])


static func _skin(matrices: Array[Transform3D], bones: PackedInt32Array, weights: PackedFloat32Array,
		vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
	for i in vertices.size():
		var position := Vector3.ZERO
		var normal := Vector3.ZERO
		var total := 0.0
		for k in range(4 * i, 4 * i + 4):
			var weight := weights[k]
			if weight > 0.0:
				var matrix := matrices[bones[k]]
				position += weight * (matrix * vertices[i])
				normal += weight * (matrix.basis * normals[i])
				total += weight
		vertices[i] = position / total
		normals[i] = normal.normalized()
