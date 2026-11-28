extends RefCounted
## Paso 12.1a: medidas de tela sobre piel, compartidas por probar_piezas.gd y probar_ropa_extremos.gd.
## Traslado de las funciones privadas de RE.1c; las constantes llegan como argumentos. 12.1b-b5: el cruce del rayo es
## segment_hit (el de Godot perdía los triángulos pequeños) y cada rayo mira todas las celdas de su caja (por puntos a media
## celda se saltaba las esquinas).
## Uso: const Cloth := preload("medidas_tela.gd")
##   var hands := Cloth.hand_mask(mesh, skeleton, ["Hand", "Thumb"])
##   var inner := Cloth.covered_skin(body, cloth, tris, hands, 0.02, 0.09, 0.05, 0.025)
##   var heights := Cloth.cloth_heights(skin, normals, inner, cloth, tris, 0.02, 0.09, 0.05)

const PARALLEL := 1e-6  # PROVISIONAL: seno × coseno por debajo del cual el rayo se toma por paralelo al triángulo (sin unidades)
const EDGE := 1e-4  # PROVISIONAL: holgura baricéntrica; un rayo justo por una arista o un vértice cuenta (redondeo de 32 bits)


## Altura de la primera tela sobre cada vértice de piel `which`, a lo largo de su normal (INF si no hay). Era _cloth_heights.
static func cloth_heights(skin: PackedVector3Array, normals: PackedVector3Array, which: PackedInt32Array,
		cloth: PackedVector3Array, tris: PackedInt32Array, below: float, above: float, cell: float) -> PackedFloat64Array:
	var grid := cloth_grid(cloth, tris, cell)
	var stamp := PackedInt32Array()
	stamp.resize(tris.size() / 3)
	stamp.fill(-1)
	var heights := PackedFloat64Array()
	heights.resize(which.size())
	for k in which.size():
		var normal := normals[which[k]].normalized()
		var from := skin[which[k]] - normal * below
		var to := skin[which[k]] + normal * above
		var best := INF
		for key: Vector3i in _box_cells(from, to, cell):
			for t: int in grid.get(key, PackedInt32Array()):
				if stamp[t] == k:
					continue
				stamp[t] = k
				var hit: Variant = segment_hit(from, to, cloth[tris[3 * t]], cloth[tris[3 * t + 1]], cloth[tris[3 * t + 2]])
				if hit != null:
					best = minf(best, from.distance_to(hit) - below)
		heights[k] = best
	return heights


## Las celdas de la caja del segmento: todas las que puede cruzar.
static func _box_cells(from: Vector3, to: Vector3, cell: float) -> Array[Vector3i]:
	var low := Vector3i((from.min(to) / cell).floor())
	var high := Vector3i((from.max(to) / cell).floor())
	var cells: Array[Vector3i] = []
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				cells.append(Vector3i(x, y, z))
	return cells


## Punto donde el segmento from→to corta el triángulo abc (por cualquiera de sus caras), o null. Möller–Trumbore con la
## tolerancia relativa a las longitudes: Geometry3D.segment_intersects_triangle (Godot 4.7.2) usa una absoluta (1e-5)
## y con un segmento de 13 cm no acierta triángulos de catetos de 7 mm o menos.
static func segment_hit(from: Vector3, to: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Variant:
	var ray := to - from
	var edge_b := b - a
	var edge_c := c - a
	var across := ray.cross(edge_c)
	var det := edge_b.dot(across)
	if absf(det) <= PARALLEL * ray.length() * edge_b.length() * edge_c.length():  # paralelo o triángulo sin área
		return null
	var start := from - a
	var u := start.dot(across) / det
	if u < -EDGE or u > 1.0 + EDGE:
		return null
	var side := start.cross(edge_b)
	var v := ray.dot(side) / det
	if v < -EDGE or u + v > 1.0 + EDGE:
		return null
	var along := edge_c.dot(side) / det
	return from + ray * along if along >= 0.0 and along <= 1.0 else null


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
