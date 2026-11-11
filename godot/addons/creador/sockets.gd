class_name Sockets
extends RefCounted
## Anclajes: pasa los huesos de anclaje del personaje horneado a nodos vacíos hijos de su hueso (paso 3.6.4).
##
## Uso:
##   var character := Sockets.to_nodes(baked, species.manifest["bones"]["sockets"])   # null si error() no es ""
## Entra el personaje de character_baker.gd (raíz → Skeleton3D → MeshInstance3D) y devuelve uno nuevo:
## - Skeleton3D solo con los huesos de deformación (mismo reposo y padres).
## - Por anclaje: BoneAttachment3D "<anclaje>_attachment" pegado al hueso padre y, dentro, el nodo vacío "<anclaje>"
##   donde estaba el hueso de anclaje (posición y giro; escala 1 porque el horneado ya quitó las escalas).
## - Skin sin los anclajes; los índices de hueso de la malla se corrigen si cambian.
## El personaje de entrada no cambia (quien llama lo libera).


## "" si se puede convertir; si no, el motivo.
static func error(character: Node3D, socket_names: Array) -> String:
	var skeleton: Skeleton3D = character.get_child(0)
	var mesh: MeshInstance3D = skeleton.get_child(0)
	for socket: String in socket_names:
		if skeleton.find_bone(socket) < 0:
			return "Falta el hueso de anclaje " + socket
		if skeleton.get_bone_parent(skeleton.find_bone(socket)) < 0:
			return "El anclaje %s no cuelga de ningún hueso" % socket
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for i in bones.size():
		if weights[i] > 0.0 and skeleton.get_bone_name(mesh.skin.get_bind_bone(bones[i])) in socket_names:
			return "El vértice %d tiene peso en un anclaje" % (i / 4)
	return ""


static func to_nodes(character: Node3D, socket_names: Array) -> Node3D:
	if error(character, socket_names) != "":
		return null
	var source: Skeleton3D = character.get_child(0)
	var source_mesh: MeshInstance3D = source.get_child(0)
	var root := Node3D.new()
	root.name = character.name
	var skeleton := Skeleton3D.new()
	skeleton.name = source.name
	root.add_child(skeleton)
	var new_index := {}  # índice de hueso viejo -> nuevo
	for bone in source.get_bone_count():
		if not source.get_bone_name(bone) in socket_names:
			new_index[bone] = skeleton.add_bone(source.get_bone_name(bone))
	for bone: int in new_index:
		var index: int = new_index[bone]
		var rest := source.get_bone_rest(bone)
		skeleton.set_bone_parent(index, new_index.get(source.get_bone_parent(bone), -1))
		skeleton.set_bone_rest(index, rest)
		skeleton.set_bone_pose_position(index, rest.origin)
		skeleton.set_bone_pose_rotation(index, rest.basis.get_rotation_quaternion())
	var mesh := MeshInstance3D.new()
	mesh.name = source_mesh.name
	skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")
	var new_bind := _skin(source_mesh.skin, new_index, mesh)
	mesh.mesh = _mesh(source_mesh.mesh, new_bind)
	for socket: String in socket_names:
		var bone := source.find_bone(socket)
		var holder := BoneAttachment3D.new()
		holder.name = socket + "_attachment"
		skeleton.add_child(holder)
		holder.bone_name = source.get_bone_name(source.get_bone_parent(bone))
		var node := Node3D.new()
		node.name = socket
		node.transform = source.get_bone_rest(bone)
		holder.add_child(node)
	return root


## Skin sin los anclajes. Devuelve {bind viejo: bind nuevo}.
static func _skin(source: Skin, new_index: Dictionary, mesh: MeshInstance3D) -> Dictionary:
	var skin := Skin.new()
	var new_bind := {}
	for i in source.get_bind_count():
		if new_index.has(source.get_bind_bone(i)):
			new_bind[i] = skin.get_bind_count()
			skin.add_bind(new_index[source.get_bind_bone(i)], source.get_bind_pose(i))
	mesh.skin = skin
	return new_bind


## La misma malla con los índices de hueso corregidos (un índice sin peso que apuntaba a un anclaje pasa a 0).
static func _mesh(source: Mesh, new_bind: Dictionary) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	for i in bones.size():
		bones[i] = new_bind.get(bones[i], 0)
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
