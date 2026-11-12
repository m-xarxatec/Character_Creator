class_name CharacterBaker
extends RefCounted
## Hornea el personaje del editor en uno nuevo y limpio, listo para exportar (paso 3.6.3).
##
## Uso:
##   var character := CharacterBaker.bake(species.mesh, species.skeleton, true)   # true = pose T; false = pose A
## Devuelve: nodo raíz → Skeleton3D → MeshInstance3D. El personaje del editor no cambia.
## - Las formas, la escala de Proporción y la pose pasan a la malla (mesh_baker.gd).
## - La pose de cada variante la fija el exportador, no el editor: reposo (A) o pose T, sea cual sea la pose del editor
##   (que no cambia). La escala de Proporción de la pose sí se hornea.
## - El reposo nuevo es la pose global actual sin escala: todos los huesos con escala 1 y pose = reposo.
## - Apoyado en el suelo: el punto más bajo de la malla queda en y = 0.
## - La malla no lleva formas; UV, color `garment`, índices, huesos y pesos se copian tal cual.
##   Tangentes: no se pasan, pero Godot guarda unas igualmente al crear la superficie (sin uso: no hay mapas de normales).
## Los anclajes siguen siendo huesos (pasan a nodos vacíos en el paso 3.6.4).

const Baker := preload("mesh_baker.gd")
const TPose := preload("t_pose.gd")


static func bake(mesh: MeshInstance3D, skeleton: Skeleton3D, t_pose: bool) -> Node3D:
	var editor_positions: Array[Vector3] = []
	var editor_rotations: Array[Quaternion] = []
	for bone in skeleton.get_bone_count():
		editor_positions.append(skeleton.get_bone_pose_position(bone))
		editor_rotations.append(skeleton.get_bone_pose_rotation(bone))
	_set_rest_pose(skeleton)
	if t_pose:
		TPose.apply(skeleton)
	var baked: Dictionary = Baker.bake(mesh, skeleton)
	var globals: Array[Transform3D] = Baker.global_poses(skeleton)
	for bone in skeleton.get_bone_count():  # el editor queda como estaba
		skeleton.set_bone_pose_position(bone, editor_positions[bone])
		skeleton.set_bone_pose_rotation(bone, editor_rotations[bone])

	var vertices: PackedVector3Array = baked["vertices"]
	var lowest := INF
	for vertex in vertices:
		lowest = minf(lowest, vertex.y)
	var to_ground := Vector3(0.0, -lowest, 0.0)
	for i in vertices.size():
		vertices[i] += to_ground
	for bone in globals.size():  # sin escala y apoyado en el suelo
		globals[bone] = Transform3D(globals[bone].basis.orthonormalized(), globals[bone].origin + to_ground)

	var root := Node3D.new()
	root.name = "Character"
	var new_skeleton := _skeleton(skeleton, globals)
	root.add_child(new_skeleton)
	var new_mesh := MeshInstance3D.new()
	new_mesh.name = mesh.name
	new_mesh.mesh = _mesh(mesh.mesh, vertices, baked["normals"])
	new_mesh.skin = _skin(skeleton, mesh.skin, globals)
	new_skeleton.add_child(new_mesh)
	new_mesh.skeleton = NodePath("..")
	return root


static func _set_rest_pose(skeleton: Skeleton3D) -> void:
	for bone in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(bone)
		skeleton.set_bone_pose_position(bone, rest.origin)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())


static func _skeleton(source: Skeleton3D, globals: Array[Transform3D]) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = source.name
	for bone in source.get_bone_count():
		skeleton.add_bone(source.get_bone_name(bone))
	for bone in source.get_bone_count():
		var parent := source.get_bone_parent(bone)
		var rest := globals[bone] if parent < 0 else globals[parent].affine_inverse() * globals[bone]
		skeleton.set_bone_parent(bone, parent)
		skeleton.set_bone_rest(bone, rest)
		skeleton.set_bone_pose_position(bone, rest.origin)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, Vector3.ONE)
	return skeleton


## Mismos binds y en el mismo orden que la Skin original: los índices de hueso de la malla siguen valiendo.
static func _skin(source: Skeleton3D, source_skin: Skin, globals: Array[Transform3D]) -> Skin:
	var skin := Skin.new()
	for i in source_skin.get_bind_count():
		var bone := source_skin.get_bind_bone(i)
		if bone < 0:
			bone = source.find_bone(source_skin.get_bind_name(i))
		skin.add_bind(bone, globals[bone].affine_inverse())
	return skin


static func _mesh(source: Mesh, vertices: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
