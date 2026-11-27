extends RefCounted
## Paso 12.1a: medidas de tela sobre piel, compartidas por probar_piezas.gd y probar_ropa_extremos.gd.
## Traslado de las funciones privadas de RE.1c (sin cambiar el cálculo); las constantes llegan como argumentos.
## Uso: const Cloth := preload("medidas_tela.gd")
##   var hands := Cloth.hand_mask(mesh, skeleton, ["Hand", "Thumb"])
##   var inner := Cloth.covered_skin(body, cloth, tris, hands, 0.02, 0.09, 0.05, 0.025)
##   var heights := Cloth.cloth_heights(skin, normals, inner, cloth, tris, 0.02, 0.09, 0.05)


## Altura de la primera tela sobre cada vértice de piel `which`, a lo largo de su normal (INF si no hay). Era _cloth_heights.
static func cloth_heights(skin: PackedVector3Array, normals: PackedVector3Array, which: PackedInt32Array,
		cloth: PackedVector3Array, tris: PackedInt32Array, below: float, above: float, cell: float) -> PackedFloat64Array:
	var grid := cloth_grid(cloth, tris, cell)
	var stamp := PackedInt32Array()
	stamp.resize(tris.size() / 3)
	stamp.fill(-1)
	var heights := PackedFloat64Array()
	heights.resize(which.size())
	var steps := ceili((below + above) / (0.5 * cell))
	for k in which.size():
		var normal := normals[which[k]].normalized()
		var from := skin[which[k]] - normal * below
		var to := skin[which[k]] + normal * above
		var best := INF
		for s in steps + 1:
			var center := Vector3i((from.lerp(to, float(s) / steps) / cell).floor())
			for t: int in grid.get(center, PackedInt32Array()):
				if stamp[t] == k:
					continue
				stamp[t] = k
				var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, cloth[tris[3 * t]], cloth[tris[3 * t + 1]], cloth[tris[3 * t + 2]])
				if hit != null:
					best = minf(best, from.distance_to(hit) - below)
		heights[k] = best
	return heights


## {celda: triángulos de la tela cuya caja la toca}. Era _cloth_grid.
static func cloth_grid(cloth: PackedVector3Array, tris: PackedInt32Array, cell: float) -> Dictionary:
	var grid := {}
	for t in tris.size() / 3:
		var a := cloth[tris[3 * t]]
		var b := cloth[tris[3 * t + 1]]
		var c := cloth[tris[3 * t + 2]]
		var from := Vector3i((a.min(b).min(c) / cell).floor())
		var to := Vector3i((a.max(b).max(c) / cell).floor())
		for x in range(from.x, to.x + 1):
			for y in range(from.y, to.y + 1):
				for z in range(from.z, to.z + 1):
					var key := Vector3i(x, y, z)
					if not grid.has(key):
						grid[key] = PackedInt32Array()
					grid[key].append(t)
	return grid


## Piel tapada en neutro y a más de `hem` de piel sin tapar (sin manos). Era _os_inner (+ _has_near).
static func covered_skin(body: Dictionary, cloth: PackedVector3Array, tris: PackedInt32Array, hands: PackedByteArray,
		below: float, above: float, cell: float, hem: float) -> PackedInt32Array:
	var skin: PackedVector3Array = body["vertices"]
	var box := AABB(cloth[0], Vector3.ZERO)
	for point in cloth:
		box = box.expand(point)
	box = box.grow(below + 0.01)
	var near := PackedInt32Array()
	for v in skin.size():
		if hands[v] == 0 and box.has_point(skin[v]):
			near.append(v)
	var heights := cloth_heights(skin, body["normals"], near, cloth, tris, below, above, cell)
	var bare := {}
	for k in near.size():
		if not is_finite(heights[k]):
			var key := Vector3i((skin[near[k]] / hem).floor())
			if not bare.has(key):
				bare[key] = PackedInt32Array()
			bare[key].append(near[k])
	var inner := PackedInt32Array()
	for k in near.size():
		if is_finite(heights[k]) and not _has_near(skin, skin[near[k]], bare, hem):
			inner.append(near[k])
	return inner


static func _has_near(skin: PackedVector3Array, point: Vector3, bare: Dictionary, hem: float) -> bool:
	var center := Vector3i((point / hem).floor())
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				for v: int in bare.get(center + Vector3i(x, y, z), PackedInt32Array()):
					if point.distance_squared_to(skin[v]) < hem * hem:
						return true
	return false


## 1 en los vértices de piel que pesan sobre todo en `hand_bones` (cuelgan junto a la cadera, no van bajo la ropa). Era _hand_mask.
static func hand_mask(mesh: MeshInstance3D, skeleton: Skeleton3D, hand_bones: Array) -> PackedByteArray:
	var is_hand := {}
	for i in mesh.skin.get_bind_count():
		var bone := _bind_bone_name(mesh, skeleton, i)
		is_hand[i] = hand_bones.any(func(part: String) -> bool: return part in bone)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var sums := PackedFloat32Array()
	sums.resize(bones.size() / 4)
	for k in bones.size():
		if is_hand.get(bones[k], false):
			sums[k / 4] += weights[k]
	var mask := PackedByteArray()
	mask.resize(sums.size())
	for v in sums.size():
		mask[v] = 1 if sums[v] >= 0.5 else 0
	return mask


## Nuevo (12.1a): nombre del hueso que más pesa en cada vértice (la «zona» de los informes).
static func main_bones(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedStringArray:
	var names := PackedStringArray()
	for i in mesh.skin.get_bind_count():
		names.append(_bind_bone_name(mesh, skeleton, i))
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var found := PackedStringArray()
	found.resize(bones.size() / 4)
	for v in found.size():
		var best := 4 * v
		for k in range(4 * v, 4 * v + 4):
			if weights[k] > weights[best]:
				best = k
		found[v] = names[bones[best]]
	return found


static func _bind_bone_name(mesh: MeshInstance3D, skeleton: Skeleton3D, i: int) -> String:
	var bind_name := String(mesh.skin.get_bind_name(i))
	return bind_name if bind_name != "" else String(skeleton.get_bone_name(mesh.skin.get_bind_bone(i)))
