class_name StyleNormals
extends RefCounted
## Normales del estilo ilustración (paso 3.16): torso suavizado y cara de elipsoide, para que el toon no corte el
## cuerpo en manchas. Salen de las maquetas del 3.12 (probar_estilo.gd) y del 3.13a-2 (probar_normales_cara.gd).
##
## Uso, con una malla ya horneada (sin formas):
##   var head := StyleNormals.head_weights(arrays, mesh.skin, skeleton)
##   arrays[Mesh.ARRAY_NORMAL] = StyleNormals.apply(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], arrays[Mesh.ARRAY_INDEX], head)
## - smooth: cada normal pasa a la media de sus vecinas, `steps` veces (los vértices repetidos en las costuras de UV
##   cuentan como uno).
## - face: la normal de un elipsoide con el centro y el tamaño de la caja de la cabeza (vértices con peso de Head > 0,5),
##   mezclada con la de la malla según el peso de Head (en el cuello pasa poco a poco a la de siempre). `depth` < 1 quita
##   fondo al elipsoide solo por delante: la cara mira más al frente.
## Lo usa GlbExporter: viajan en el .glb. En el editor, la vista en vivo no las lleva todavía (haría falta hornear).

const SMOOTH_STEPS := 10  # elegido en el 3.12 (anatomia.png)
const FACE_DEPTH := 0.6  # elegido en el 3.13a-2 (aplanado_hoja.png)
const WELD := 100000.0  # vértices a menos de 0,01 mm son el mismo


## Torso suavizado y cara de elipsoide, con los valores elegidos.
static func apply(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		head_weight: PackedFloat32Array) -> PackedVector3Array:
	return face(vertices, smooth(vertices, normals, indices, SMOOTH_STEPS), head_weight, 1.0, FACE_DEPTH)


## Peso del hueso Head en cada vértice (0 si no lo tiene).
static func head_weights(arrays: Array, skin: Skin, skeleton: Skeleton3D) -> PackedFloat32Array:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var head := -1
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		var name: String = skeleton.get_bone_name(bone) if bone >= 0 else String(skin.get_bind_name(i))
		if name == "Head":
			head = i
	var result := PackedFloat32Array()
	result.resize(weights.size() / 4)
	for v in result.size():
		for k in 4:
			if bones[4 * v + k] == head:
				result[v] += weights[4 * v + k]
	return result


static func smooth(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		steps: int) -> PackedVector3Array:
	var weld := {}
	var id := PackedInt32Array()
	id.resize(vertices.size())
	for i in vertices.size():
		var key := Vector3i((vertices[i] * WELD).round())
		if not weld.has(key):
			weld[key] = weld.size()
		id[i] = weld[key]
	var neighbors: Array[Dictionary] = []
	neighbors.resize(weld.size())
	for n in neighbors.size():
		neighbors[n] = {}
	for t in range(0, indices.size(), 3):
		for e in 3:
			var a := id[indices[t + e]]
			var b := id[indices[t + (e + 1) % 3]]
			neighbors[a][b] = true
			neighbors[b][a] = true
	var current := PackedVector3Array()
	current.resize(weld.size())
	for i in vertices.size():
		current[id[i]] = normals[i]
	for step in steps:
		var next := current.duplicate()
		for n in current.size():
			var sum := current[n]
			for m: int in neighbors[n]:
				sum += current[m]
			next[n] = sum.normalized()
		current = next
	var result := PackedVector3Array()
	result.resize(vertices.size())
	for i in vertices.size():
		result[i] = current[id[i]]
	return result


## Mezcla cada normal con la del elipsoide de la cabeza: amount × peso de Head.
static func face(vertices: PackedVector3Array, normals: PackedVector3Array, head_weight: PackedFloat32Array,
		amount: float, depth: float) -> PackedVector3Array:
	var box := AABB()
	var first := true
	for i in vertices.size():
		if head_weight[i] > 0.5:
			box = AABB(vertices[i], Vector3.ZERO) if first else box.expand(vertices[i])
			first = false
	var center := box.get_center()
	var radii := box.size / 2.0
	var result := normals.duplicate()
	for i in vertices.size():
		var w := head_weight[i] * amount
		if w > 0.0:
			var offset := vertices[i] - center
			var r := radii
			if offset.z > 0.0:
				r.z *= depth
			var ellipsoid := (offset / (r * r)).normalized()
			result[i] = normals[i].lerp(ellipsoid, w).normalized()
	return result
