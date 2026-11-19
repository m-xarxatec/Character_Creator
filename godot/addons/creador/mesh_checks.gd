class_name MeshChecks
extends RefCounted
## Medidas de deformación de un personaje en una pose, comparado con su reposo (paso 5.10). No cambia nada.
##
## Uso:
##   var results := MeshChecks.run(mesh, skeleton)     # con la pose ya puesta en el esqueleto
## Resultados como los de CharacterChecks (5.3) y además "valor": {"id", "nivel", "texto", "huesos", "valor"}.
## Todo compara la pose con el reposo del MISMO personaje: un cuerpo extremo no avisa por serlo, solo si se deforma mal.
## - seccion (%): cuánto adelgaza el anillo de vértices de una articulación (distancia media a la articulación).
## - cruce (mm): dos partes que no se tocaban en reposo y en la pose se atraviesan (cápsulas por hueso).
## - estiramiento (factor): la arista que más se alarga respecto al reposo.
## - degenerados: triángulos que en la pose quedan sin área.
## Lento (hornea la malla dos veces en CPU): para el informe, no para cada fotograma.

const MeshBaker := preload("mesh_baker.gd")

## Umbrales [aviso, error], aprobados el 2026-11-18 con las medidas del 5.9 y el 5.10.
const LIMITS := {"seccion": [20.0, 35.0], "cruce": [10.0, 30.0], "estiramiento": [3.0, 6.0], "degenerados": [1.0, 1.0]}
const RING_WEIGHT := 0.25  # un vértice es del anillo de una articulación si pesa esto o más en los dos huesos
const MIN_RING := 8
const MIN_CAPSULE := 20  # vértices propios para que un hueso tenga cápsula
const MIN_EDGE := 0.0001  # m: aristas más cortas no cuentan para el estiramiento
const MIN_AREA := 1e-10  # m²: por debajo, el triángulo cuenta como degenerado


static func run(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Array[Dictionary]:
	var poses: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(bone))
		skeleton.set_bone_pose(bone, skeleton.get_bone_rest(bone))
	var rest: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
	var rest_globals := MeshBaker.global_poses(skeleton)
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose(bone, poses[bone])
	var posed: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
	var globals := MeshBaker.global_poses(skeleton)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var owners := _owners(arrays, mesh.skin, skeleton)
	var results: Array[Dictionary] = []
	results.append_array(_sections(rest, posed, joint_rings(arrays, mesh.skin, skeleton), skeleton, rest_globals, globals))
	results.append_array(_crossings(rest, owners, skeleton, rest_globals, globals))
	results.append(_stretch_result(rest, posed, indices, owners, skeleton))
	results.append(_degenerate_result(rest, posed, indices))
	return results


## Pérdida de sección en % (positivo = la articulación adelgaza).
static func section_loss(rest: PackedVector3Array, posed: PackedVector3Array, ring: PackedInt32Array,
		joint_rest: Vector3, joint_posed: Vector3) -> float:
	var r_rest := 0.0
	var r_posed := 0.0
	for v in ring:
		r_rest += rest[v].distance_to(joint_rest)
		r_posed += posed[v].distance_to(joint_posed)
	return 100.0 * (1.0 - r_posed / r_rest)


## {índice del hueso hijo: PackedInt32Array}: vértices con peso ≥ RING_WEIGHT en el hueso y en su padre.
static func joint_rings(arrays: Array, skin: Skin, skeleton: Skeleton3D) -> Dictionary:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var binds := _bind_bones(skin, skeleton)
	var rings := {}
	for v in weights.size() / 4:
		var strong := {}
		for k in range(4 * v, 4 * v + 4):
			if weights[k] >= RING_WEIGHT:
				strong[binds[bones[k]]] = true
		for bone: int in strong:
			if strong.has(skeleton.get_bone_parent(bone)):
				if not rings.has(bone):
					rings[bone] = PackedInt32Array()
				var ring: PackedInt32Array = rings[bone]
				ring.append(v)
				rings[bone] = ring
	return rings


## Cápsula de cada hueso: {hueso: {"child": índice, "r": radio}}, con los vértices en reposo y las poses de reposo.
## Segmento: de la cabeza del hueso a la de su primer hijo con vértices propios. Radio: mediana de las distancias.
static func capsules(vertices: PackedVector3Array, owners: PackedInt32Array, skeleton: Skeleton3D,
		globals: Array[Transform3D]) -> Dictionary:
	var own := {}  # hueso -> lista de vértices de los que es el hueso de mayor peso
	for v in owners.size():
		if not own.has(owners[v]):
			own[owners[v]] = PackedInt32Array()
		var list: PackedInt32Array = own[owners[v]]
		list.append(v)
		own[owners[v]] = list
	var result := {}
	for bone: int in own:
		if (own[bone] as PackedInt32Array).size() < MIN_CAPSULE:
			continue
		var child := -1
		for candidate in skeleton.get_bone_children(bone):
			if own.has(candidate):
				child = candidate
				break
		if child < 0:
			continue
		var a := globals[bone].origin
		var b := globals[child].origin
		var distances := PackedFloat32Array()
		for v in own[bone]:
			distances.append(vertices[v].distance_to(Geometry3D.get_closest_point_to_segment(vertices[v], a, b)))
		distances.sort()
		result[bone] = {"child": child, "r": distances[distances.size() / 2]}
	return result


## Solape de dos cápsulas {"a", "b", "r"} en metros; 0 si no se tocan.
static func capsule_overlap(first: Dictionary, second: Dictionary) -> float:
	var closest := Geometry3D.get_closest_points_between_segments(first["a"], first["b"], second["a"], second["b"])
	return maxf(0.0, first["r"] + second["r"] - closest[0].distance_to(closest[1]))


## Mayor alargamiento de una arista respecto al reposo (factor).
static func stretch(rest: PackedVector3Array, posed: PackedVector3Array, indices: PackedInt32Array) -> float:
	return _worst_edge(rest, posed, indices)[0]


static func degenerate_count(rest: PackedVector3Array, posed: PackedVector3Array, indices: PackedInt32Array) -> int:
	return _degenerate(rest, posed, indices).size()


## Paso P.5b: número con coma decimal para los textos del informe («0,6 mm»).
static func num(value: float, decimals: int) -> String:
	return ("%.*f" % [decimals, value]).replace(".", ",")


static func _result(id: String, value: float, text: String, bones: PackedStringArray) -> Dictionary:
	var level := "error" if value >= LIMITS[id][1] else ("aviso" if value >= LIMITS[id][0] else "bien")
	return {"id": id, "nivel": level, "texto": text, "huesos": bones, "valor": value}


## Índice de hueso del esqueleto de cada bind de la Skin.
static func _bind_bones(skin: Skin, skeleton: Skeleton3D) -> PackedInt32Array:
	var binds := PackedInt32Array()
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		binds.append(bone if bone >= 0 else skeleton.find_bone(skin.get_bind_name(i)))
	return binds


## Hueso de mayor peso de cada vértice.
static func _owners(arrays: Array, skin: Skin, skeleton: Skeleton3D) -> PackedInt32Array:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var binds := _bind_bones(skin, skeleton)
	var owners := PackedInt32Array()
	for v in weights.size() / 4:
		var best := 4 * v
		for k in range(4 * v + 1, 4 * v + 4):
			if weights[k] > weights[best]:
				best = k
		owners.append(binds[bones[best]])
	return owners


static func _sections(rest: PackedVector3Array, posed: PackedVector3Array, rings: Dictionary, skeleton: Skeleton3D,
		rest_globals: Array[Transform3D], globals: Array[Transform3D]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var worst := 0.0
	var worst_bone := ""
	for bone: int in rings:
		var ring: PackedInt32Array = rings[bone]
		if ring.size() < MIN_RING:
			continue
		var loss := section_loss(rest, posed, ring, rest_globals[bone].origin, globals[bone].origin)
		var name := skeleton.get_bone_name(bone)
		if loss > worst:
			worst = loss
			worst_bone = name
		if loss >= LIMITS["seccion"][0]:
			results.append(_result("seccion", loss, "La articulación de %s adelgaza un %s %%" % [name, num(loss, 0)], PackedStringArray([name])))
	if results.is_empty():
		results.append(_result("seccion", worst, "Ninguna articulación adelgaza (máximo %s %%, %s)" % [num(worst, 1), worst_bone],
			PackedStringArray()))
	return results


static func _crossings(rest: PackedVector3Array, owners: PackedInt32Array, skeleton: Skeleton3D,
		rest_globals: Array[Transform3D], globals: Array[Transform3D]) -> Array[Dictionary]:
	var found := capsules(rest, owners, skeleton, rest_globals)
	var bones := found.keys()
	var results: Array[Dictionary] = []
	var worst := 0.0
	var worst_pair := ""
	for i in bones.size():
		for j in range(i + 1, bones.size()):
			var a: int = bones[i]
			var b: int = bones[j]
			if _related(skeleton, a, b):
				continue
			var before := capsule_overlap(_capsule(found, a, rest_globals), _capsule(found, b, rest_globals))
			if before > 0.0:
				continue
			var mm := 1000.0 * capsule_overlap(_capsule(found, a, globals), _capsule(found, b, globals))
			var names := PackedStringArray([skeleton.get_bone_name(a), skeleton.get_bone_name(b)])
			if mm > worst:
				worst = mm
				worst_pair = " y ".join(names)
			if mm >= LIMITS["cruce"][0]:
				results.append(_result("cruce", mm, "%s se atraviesan %s mm" % [" y ".join(names), num(mm, 0)], names))
	if results.is_empty():
		results.append(_result("cruce", worst, "Ninguna parte atraviesa otra (máximo %s mm%s)" % [num(worst, 1),
			", " + worst_pair if worst_pair else ""], PackedStringArray()))
	return results


static func _capsule(found: Dictionary, bone: int, globals: Array[Transform3D]) -> Dictionary:
	return {"a": globals[bone].origin, "b": globals[found[bone]["child"]].origin, "r": found[bone]["r"]}


## Mismo hueso, padre e hijo, hermanos, o abuelo y nieto: se tocan por construcción.
static func _related(skeleton: Skeleton3D, a: int, b: int) -> bool:
	var pa := skeleton.get_bone_parent(a)
	var pb := skeleton.get_bone_parent(b)
	return a == b or pa == b or pb == a or pa == pb \
		or (pa >= 0 and skeleton.get_bone_parent(pa) == b) or (pb >= 0 and skeleton.get_bone_parent(pb) == a)


## [factor, vértice] de la arista que más se alarga.
static func _worst_edge(rest: PackedVector3Array, posed: PackedVector3Array, indices: PackedInt32Array) -> Array:
	var worst := 1.0
	var vertex := -1
	for t in indices.size() / 3:
		for e in 3:
			var a := indices[3 * t + e]
			var b := indices[3 * t + (e + 1) % 3]
			var length := rest[a].distance_to(rest[b])
			if length < MIN_EDGE:
				continue
			var factor := posed[a].distance_to(posed[b]) / length
			if factor > worst:
				worst = factor
				vertex = a
	return [worst, vertex]


static func _stretch_result(rest: PackedVector3Array, posed: PackedVector3Array, indices: PackedInt32Array,
		owners: PackedInt32Array, skeleton: Skeleton3D) -> Dictionary:
	var edge := _worst_edge(rest, posed, indices)
	var bones := PackedStringArray([skeleton.get_bone_name(owners[edge[1]])]) if edge[1] >= 0 else PackedStringArray()
	return _result("estiramiento", edge[0], "La malla se estira hasta ×%s" % num(edge[0], 2) + (" (%s)" % bones[0] if bones else ""), bones)


## Triángulos sin área en la pose que sí la tenían en reposo.
static func _degenerate(rest: PackedVector3Array, posed: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	var found := PackedInt32Array()
	for t in indices.size() / 3:
		if _area(posed, indices, t) < MIN_AREA and _area(rest, indices, t) >= MIN_AREA:
			found.append(t)
	return found


static func _area(vertices: PackedVector3Array, indices: PackedInt32Array, t: int) -> float:
	var a := vertices[indices[3 * t]]
	return 0.5 * (vertices[indices[3 * t + 1]] - a).cross(vertices[indices[3 * t + 2]] - a).length()


static func _degenerate_result(rest: PackedVector3Array, posed: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var count := _degenerate(rest, posed, indices).size()
	return _result("degenerados", count, "%d triángulos quedan sin área" % count, PackedStringArray())
