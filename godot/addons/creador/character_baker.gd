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
## - OPT.3b: bake = prepare_bake (hilo principal) → compute_bake (cualquier hilo) → finish_bake (hilo principal).
## - profile_axes (paso 5.7b; solo con pose T; lo usa GlbExporter desde el 5.16): cada hueso del perfil humanoide de Godot
##   sale con el giro de reposo global del perfil, que es lo que escribe «Overwrite Axis» al importar. La malla no
##   cambia (las bind poses son la inversa del reposo nuevo) y los anclajes, que no son del perfil, tampoco.
## - pieces (paso AB.7): mallas que siguen al cuerpo (BodyPiece), horneadas igual y detrás del cuerpo en el esqueleto
##   (el cuerpo sigue siendo su primer hijo). El suelo lo marca el cuerpo.
## - rigid (paso AB.11): accesorios rígidos (BoneAttachment3D de RigidPiece), como mallas al 100 % de su hueso.
## - cache (paso OPT.3a): formas ya leídas del cuerpo (MeshBaker._add_shapes); solo del cuerpo, no de las piezas.
## - Paso 9.7.3 (D31): las formas de expresión (expr_*) no se hornean (tampoco la que se prueba en la vista): cada malla
##   que las tiene sale con ellas como formas, con el nombre VRM (sin expr_), ya en la pose de la variante. A cada una se
##   le suman sus correcciones (expr_blinkLeft*eye_tall_incr…) con el peso que tiene ahora su otra parte.

const Baker := preload("mesh_baker.gd")
const TPose := preload("t_pose.gd")
const RigidPiece := preload("rigid_piece.gd")
const ShapeWeights := preload("shape_weights.gd")  # paso 9.7.3


static func bake(mesh: MeshInstance3D, skeleton: Skeleton3D, t_pose: bool, profile_axes := false, pieces: Array = [],
		rigid: Array = [], cache: Variant = null) -> Node3D:
	var job := prepare_bake(mesh, skeleton, t_pose, profile_axes, pieces, rigid, cache)
	compute_bake(job)
	return finish_bake(job)


## Paso OPT.3b: bake en tres partes. prepare_bake, en el hilo principal: pone la pose de la variante, lee todo lo que
## hace falta del editor (arrays, formas activas, matrices de piel, poses globales, huesos y binds) y devuelve el
## esqueleto a su pose, en el mismo fotograma. Lo que cambie después no entra.
static func prepare_bake(mesh: MeshInstance3D, skeleton: Skeleton3D, t_pose: bool, profile_axes := false,
		pieces: Array = [], rigid: Array = [], cache: Variant = null) -> Dictionary:
	var editor_positions: Array[Vector3] = []
	var editor_rotations: Array[Quaternion] = []
	for bone in skeleton.get_bone_count():
		editor_positions.append(skeleton.get_bone_pose_position(bone))
		editor_rotations.append(skeleton.get_bone_pose_rotation(bone))
	_set_rest_pose(skeleton)
	if t_pose:
		TPose.apply(skeleton)
	var meshes: Array[Dictionary] = [_read_mesh(mesh, skeleton, cache)]  # el cuerpo, el primero
	for piece: MeshInstance3D in pieces:
		meshes.append(_read_mesh(piece, skeleton, null))
	var posed: Array[Transform3D] = Baker.global_poses(skeleton)  # con escala, para los accesorios rígidos (AB.11)
	for bone in skeleton.get_bone_count():  # el editor queda como estaba
		skeleton.set_bone_pose_position(bone, editor_positions[bone])
		skeleton.set_bone_pose_rotation(bone, editor_rotations[bone])

	var names := PackedStringArray()
	var parents := PackedInt32Array()
	for bone in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(bone))
		parents.append(skeleton.get_bone_parent(bone))
	var accessories := []
	for holder: BoneAttachment3D in rigid:
		var bone := skeleton.find_bone(holder.bone_name)
		for instance in RigidPiece.meshes(holder):
			accessories.append({"bone": bone, "name": instance.name, "mesh": instance.mesh, "transform": instance.transform})
	return {"skeleton_name": skeleton.name, "names": names, "parents": parents, "posed": posed, "meshes": meshes,
		"accessories": accessories, "bases": profile_global_bases() if profile_axes and t_pose else {}}


## Lo que compute_bake necesita de una malla (la pose ya puesta). cache: la de MeshBaker._add_shapes (solo el cuerpo).
static func _read_mesh(mesh: MeshInstance3D, skeleton: Skeleton3D, cache: Variant) -> Dictionary:
	var active := Baker.active_shapes(mesh)
	for shape: int in active.keys():  # paso 9.7.3: la expresión que se prueba no se hornea
		if ShapeWeights.is_expression(mesh.mesh.get_blend_shape_name(shape)):
			active.erase(shape)
	var shapes := {} if cache == null else cache as Dictionary
	Baker.cache_shapes(mesh, active, shapes)
	var used := {}
	for shape: int in active:
		used[shape] = shapes[shape]
	var binds := PackedInt32Array()  # hueso de cada bind (la Skin del editor cambia con los deslizadores: se copia)
	for i in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(i)
		binds.append(bone if bone >= 0 else skeleton.find_bone(mesh.skin.get_bind_name(i)))
	return {"name": mesh.name, "arrays": mesh.mesh.surface_get_arrays(0), "active": active, "shapes": used,
		"matrices": Baker.skin_matrices(skeleton, mesh.skin), "binds": binds, "expressions": _read_expressions(mesh, shapes)}


## Paso 9.7.3: {nombre VRM: [posiciones de la forma, [[peso, posiciones de una corrección], …]]} de las expr_* de la
## malla (las correcciones, con el peso de su otra parte ahora). Hilo principal: pide a la malla las que no estén en shapes.
static func _read_expressions(mesh: MeshInstance3D, shapes: Dictionary) -> Dictionary:
	var names := ShapeWeights.shape_names(mesh.mesh)
	var wanted := {}
	for i in names.size():
		if ShapeWeights.is_expression(names[i]):
			wanted[i] = 1.0
	if wanted.is_empty():
		return {}
	Baker.cache_shapes(mesh, wanted, shapes)
	var out := {}
	for i: int in wanted:
		if "*" in names[i]:
			continue
		var fixes := []
		for j: int in wanted:
			var parts := names[j].split("*")
			var other := names.find(parts[1]) if parts.size() == 2 and parts[0] == names[i] else -1
			if other >= 0 and mesh.get_blend_shape_value(other) != 0.0:
				fixes.append([mesh.get_blend_shape_value(other), shapes[j][0]])
		out[names[i].trim_prefix(ShapeWeights.EXPRESSION_PREFIX)] = [shapes[i][0], fixes]
	return out


## compute_bake, en cualquier hilo: solo arrays. Formas y huesos de cada malla (como MeshBaker.bake), suelo y reposo nuevo.
static func compute_bake(job: Dictionary) -> void:
	for entry: Dictionary in job["meshes"]:
		var arrays: Array = entry["arrays"]
		var vertices: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		Baker.add_shape_arrays(vertices, normals, entry["active"], entry["shapes"])
		Baker._skin(entry["matrices"], arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], vertices, normals)
		entry["vertices"] = vertices
		entry["normals"] = normals
		entry["morphs"] = _morphs(entry)  # paso 9.7.3

	var body_vertices: PackedVector3Array = job["meshes"][0]["vertices"]
	var lowest := INF
	for vertex in body_vertices:  # el suelo lo marca el cuerpo
		lowest = minf(lowest, vertex.y)
	var to_ground := Vector3(0.0, -lowest, 0.0)
	for entry: Dictionary in job["meshes"]:
		var vertices: PackedVector3Array = entry["vertices"]
		for i in vertices.size():
			vertices[i] += to_ground
		entry["vertices"] = vertices
	var posed: Array[Transform3D] = job["posed"]
	var globals: Array[Transform3D] = posed.duplicate()
	for bone in globals.size():  # sin escala y apoyado en el suelo
		globals[bone] = Transform3D(globals[bone].basis.orthonormalized(), globals[bone].origin + to_ground)
	var bases: Dictionary = job["bases"]
	var names: PackedStringArray = job["names"]
	for bone in globals.size():
		if bases.has(names[bone]):
			globals[bone] = Transform3D(bases[names[bone]], globals[bone].origin)
	job["globals"] = globals
	job["to_ground"] = to_ground


## Paso 9.7.3: {nombre VRM: desplazamiento en la pose de la variante} de las expresiones de una malla. Solo arrays.
static func _morphs(entry: Dictionary) -> Dictionary:
	var arrays: Array = entry["arrays"]
	var base: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var out := {}
	for name: String in entry["expressions"]:
		var source: Array = entry["expressions"][name]
		var shape: PackedVector3Array = source[0]
		var delta := PackedVector3Array()
		delta.resize(base.size())
		for i in base.size():
			delta[i] = shape[i] - base[i]
		for fix: Array in source[1]:
			var weight: float = fix[0]
			var correction: PackedVector3Array = fix[1]
			for i in base.size():
				delta[i] += weight * (correction[i] - base[i])
		out[name] = Baker.skinned_deltas(entry["matrices"], arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], delta)
	return out


## finish_bake, en el hilo principal: crea Character → Skeleton3D → mallas (cuerpo, piezas y accesorios, en este orden).
static func finish_bake(job: Dictionary) -> Node3D:
	var globals: Array[Transform3D] = job["globals"]
	var root := Node3D.new()
	root.name = "Character"
	var new_skeleton := _skeleton(job["skeleton_name"], job["names"], job["parents"], globals)
	root.add_child(new_skeleton)
	for entry: Dictionary in job["meshes"]:
		var new_mesh := MeshInstance3D.new()
		new_mesh.name = entry["name"]
		new_mesh.mesh = _mesh(entry["arrays"], entry["vertices"], entry["normals"], entry["morphs"])
		new_mesh.skin = _skin(entry["binds"], globals)
		new_skeleton.add_child(new_mesh)
		new_mesh.skeleton = NodePath("..")
	var posed: Array[Transform3D] = job["posed"]
	for accessory: Dictionary in job["accessories"]:
		var instance := MeshInstance3D.new()  # RigidPiece.to_skinned solo lee nombre, malla y transform
		instance.name = accessory["name"]
		instance.mesh = accessory["mesh"]
		instance.transform = accessory["transform"]
		var bone: int = accessory["bone"]
		var skinned := RigidPiece.to_skinned(instance, bone, posed[bone], globals[bone], job["to_ground"])
		instance.free()
		new_skeleton.add_child(skinned)
		skinned.skeleton = NodePath("..")
	return root


## {nombre de hueso: Basis} con el giro de reposo global de cada hueso de SkeletonProfileHumanoid
## (el de su pose de referencia encadenado con los de sus padres).
static func profile_global_bases() -> Dictionary:
	var profile := SkeletonProfileHumanoid.new()
	var bases := {}
	for i in profile.bone_size:
		var basis := Basis.IDENTITY
		var bone := i
		while bone >= 0:
			basis = profile.get_reference_pose(bone).basis * basis
			bone = profile.find_bone(profile.get_bone_parent(bone))
		bases[String(profile.get_bone_name(i))] = basis.orthonormalized()  # encadenar acumula error: sin esto la escala no es 1
	return bases


static func _set_rest_pose(skeleton: Skeleton3D) -> void:
	for bone in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(bone)
		skeleton.set_bone_pose_position(bone, rest.origin)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())


static func _skeleton(skeleton_name: StringName, names: PackedStringArray, parents: PackedInt32Array,
		globals: Array[Transform3D]) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = skeleton_name
	for bone in names.size():
		skeleton.add_bone(names[bone])
	for bone in names.size():
		var parent := parents[bone]
		var rest := globals[bone] if parent < 0 else globals[parent].affine_inverse() * globals[bone]
		skeleton.set_bone_parent(bone, parent)
		skeleton.set_bone_rest(bone, rest)
		skeleton.set_bone_pose_position(bone, rest.origin)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, Vector3.ONE)
	return skeleton


## Mismos binds y en el mismo orden que la Skin original: los índices de hueso de la malla siguen valiendo.
static func _skin(binds: PackedInt32Array, globals: Array[Transform3D]) -> Skin:
	var skin := Skin.new()
	for bone in binds:
		skin.add_bind(bone, globals[bone].affine_inverse())
	return skin


## arrays: los de la malla del editor leídos en prepare_bake (UV, color `garment`, índices, huesos y pesos, tal cual).
## morphs (paso 9.7.3): las expresiones de la malla, ya en la pose (vacío: sin formas, como antes).
static func _mesh(source_arrays: Array, vertices: PackedVector3Array, normals: PackedVector3Array,
		morphs := {}) -> ArrayMesh:
	var arrays := source_arrays.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	return Baker.with_morphs(arrays, morphs)
