extends RefCounted
# Medidas para comparar un .glb reimportado con el personaje que se exportó (en memoria). Las usan
# probar_exportar.gd (3.6.5) y probar_aleatorios.gd (3.8). Cada una devuelve la lista de errores, uno por elemento;
# stats() da (máximo, media). No comprueba nada: los límites son de quien las llama.

const WEIGHT_EPS := 1e-6  # un peso menor no cuenta como influencia


static func stats(errors: Array) -> Vector2:
	var worst := 0.0
	var sum := 0.0
	for error: float in errors:
		worst = maxf(worst, error)
		sum += error
	return Vector2(worst, sum / maxf(1.0, errors.size()))


static func angle(a: Basis, b: Basis) -> float:
	var q := (a.orthonormalized().inverse() * b.orthonormalized()).get_rotation_quaternion()
	return rad_to_deg(2.0 * acos(minf(1.0, absf(q.w))))


static func global_rests(skeleton: Skeleton3D) -> Dictionary:
	var rests := {}
	for bone in skeleton.get_bone_count():
		rests[skeleton.get_bone_name(bone)] = skeleton.get_bone_global_rest(bone)
	return rests


## {anclaje: transformación global en reposo}; vacío si alguno no cuelga de un BoneAttachment3D.
static func sockets(skeleton: Skeleton3D, socket_names: Array) -> Dictionary:
	var found := {}
	for socket: String in socket_names:
		var node := skeleton.find_child(socket, true, false) as Node3D
		var holder := node.get_parent() as BoneAttachment3D if node else null
		if holder == null or skeleton.find_bone(holder.bone_name) < 0:
			return {}
		found[socket] = skeleton.get_bone_global_rest(skeleton.find_bone(holder.bone_name)) * node.transform
	return found


## Huesos por nombre, en reposo: {mm: [...], deg: [...], count: huesos leídos, unit: todos con escala 1}.
## Un hueso que falta cuenta como error infinito.
static func bone_errors(skeleton: Skeleton3D, memory_skeleton: Skeleton3D) -> Dictionary:
	var rests := global_rests(skeleton)
	var memory_rests := global_rests(memory_skeleton)
	var mm := []
	var deg := []
	for bone: String in memory_rests:
		if not rests.has(bone):
			mm.append(INF)
			continue
		mm.append(1000.0 * rests[bone].origin.distance_to(memory_rests[bone].origin))
		deg.append(angle(rests[bone].basis, memory_rests[bone].basis))
	var unit := true
	for bone in skeleton.get_bone_count():
		unit = unit and skeleton.get_bone_rest(bone).basis.get_scale().is_equal_approx(Vector3.ONE) \
			and skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE)
	return {"mm": mm, "deg": deg, "count": rests.size(), "unit": unit}


## Anclajes: {mm: [...], deg: [...], found: leídos, memory_found: en memoria}.
static func socket_errors(skeleton: Skeleton3D, memory_skeleton: Skeleton3D, socket_names: Array) -> Dictionary:
	var read := sockets(skeleton, socket_names)
	var memory := sockets(memory_skeleton, socket_names)
	var mm := []
	var deg := []
	for socket: String in memory:
		if read.has(socket):
			mm.append(1000.0 * read[socket].origin.distance_to(memory[socket].origin))
			deg.append(angle(read[socket].basis, memory[socket].basis))
	return {"mm": mm, "deg": deg, "found": read.size(), "memory_found": memory.size()}


## Transformación de la malla a la escena (sube por los padres).
static func to_scene(mesh: MeshInstance3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var node: Node3D = mesh
	while node.get_parent() != null:
		result = node.transform * result
		node = node.get_parent()
	return result


## Por cada vértice leído, la distancia en mm al vértice más cercano de memoria (el exportador puede reordenarlos).
static func vertex_errors(mesh: MeshInstance3D, memory_vertices: PackedVector3Array) -> Array:
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var transform := to_scene(mesh)
	var grid := {}
	for vertex in memory_vertices:
		var cell := Vector3i((vertex * 1000.0).floor())
		if not grid.has(cell):
			grid[cell] = PackedVector3Array()
		grid[cell].append(vertex)
	var errors := []
	for vertex in vertices:
		var point := transform * vertex
		var nearest := INF
		var cell := Vector3i((point * 1000.0).floor())
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					for candidate: Vector3 in grid.get(cell + Vector3i(x, y, z), PackedVector3Array()):
						nearest = minf(nearest, point.distance_to(candidate))
		errors.append(1000.0 * nearest)
	return errors


## Los vértices leídos están en el mismo orden que los de memoria (misma posición con el mismo índice, en mm):
## hace falta para comparar pesos y normales por índice. Lista vacía si no hay el mismo número de vértices.
static func order_errors(mesh: MeshInstance3D, memory_vertices: PackedVector3Array) -> Array:
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var errors := []
	if vertices.size() != memory_vertices.size():
		return errors
	var transform := to_scene(mesh)
	for i in vertices.size():
		errors.append(1000.0 * (transform * vertices[i]).distance_to(memory_vertices[i]))
	return errors


## Por vértice: la mayor diferencia de peso, hueso por nombre (un hueso distinto cuenta con todo su peso).
## Cubre huesos y pesos a la vez. Compara por índice: antes, order_errors().
static func influence_errors(mesh: MeshInstance3D, skeleton: Skeleton3D, memory_mesh: MeshInstance3D,
		memory_skeleton: Skeleton3D) -> Array:
	var read := _influences(mesh, skeleton)
	var memory := _influences(memory_mesh, memory_skeleton)
	var errors := []
	for i in mini(read.size(), memory.size()):
		var worst := 0.0
		for bone: String in read[i]:
			worst = maxf(worst, absf(read[i][bone] - memory[i].get(bone, 0.0)))
		for bone: String in memory[i]:
			if not read[i].has(bone):
				worst = maxf(worst, memory[i][bone])
		errors.append(worst)
	return errors


## Por vértice: ángulo en grados entre la normal leída (en la escena) y la de memoria. Compara por índice.
static func normal_errors(mesh: MeshInstance3D, memory_mesh: MeshInstance3D) -> Array:
	var normals: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var memory: PackedVector3Array = memory_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var basis := to_scene(mesh).basis
	var errors := []
	for i in mini(normals.size(), memory.size()):
		errors.append(rad_to_deg((basis * normals[i]).normalized().angle_to(memory[i].normalized())))
	return errors


## Por vértice: {nombre de hueso: peso} de sus influencias con peso.
static func _influences(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Array:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var names := []
	for bind in mesh.skin.get_bind_count():
		var bind_name := mesh.skin.get_bind_name(bind)
		names.append(bind_name if bind_name != "" else skeleton.get_bone_name(mesh.skin.get_bind_bone(bind)))
	var result := []
	for i in bones.size() / 4:
		var vertex := {}
		for k in 4:
			if weights[4 * i + k] > WEIGHT_EPS:
				var bone: String = names[bones[4 * i + k]]
				vertex[bone] = vertex.get(bone, 0.0) + weights[4 * i + k]
		result.append(vertex)
	return result
