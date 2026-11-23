extends RefCounted
# Paso P.3: caja aproximada del personaje en la pose de ahora, para encuadrarlo (body_view.gd → orbit_camera.gd).
# Rápida: solo una muestra de vértices (1 de cada STRIDE y los más extremos en reposo), solo con las formas activas.
# Se calcula como MeshBaker (formas + 4 huesos por vértice), pero sin hornear toda la malla.
# Paso IU.8a: extra = vértices que se quieren seguir además (la barbilla de measures.gd); points() da sus posiciones.
# Uso: var box := CharacterBox.new(species.mesh); var aabb := box.measure(species.mesh, species.skeleton)

const MeshBaker := preload("../addons/creador/mesh_baker.gd")
const STRIDE := 16

var samples := PackedInt32Array()  # índices de los vértices de la muestra
var base := PackedVector3Array()  # su posición sin formas
var bones := PackedInt32Array()  # 4 por muestra
var weights := PackedFloat32Array()
var offsets: Array[PackedVector3Array] = []  # por forma: desplazamiento de cada muestra


func _init(mesh: MeshInstance3D, extra := PackedInt32Array()) -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var chosen := {}
	for i in range(0, vertices.size(), STRIDE):
		chosen[i] = true
	for axis in 3:  # los extremos en reposo (punta de los dedos, coronilla, pies)
		var low := 0
		var high := 0
		for i in vertices.size():
			low = i if vertices[i][axis] < vertices[low][axis] else low
			high = i if vertices[i][axis] > vertices[high][axis] else high
		chosen[low] = true
		chosen[high] = true
	for i: int in extra:
		chosen[i] = true
	var all_bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var all_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for i: int in chosen:
		samples.append(i)
		base.append(vertices[i])
		for k in 4:
			bones.append(all_bones[4 * i + k])
			weights.append(all_weights[4 * i + k])
	for shape: Array in MeshBaker.shape_arrays(mesh.mesh):  # paso OPT.1: una sola vez por fotograma
		var shape_vertices: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
		var offset := PackedVector3Array()
		for s in samples.size():
			offset.append(shape_vertices[samples[s]] - base[s])
		offsets.append(offset)


## Caja de la muestra con las formas y la pose de ahora, en el espacio de la malla.
func measure(mesh: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	var placed := points(mesh, skeleton)
	var box := AABB(placed[0], Vector3.ZERO)
	for position: Vector3 in placed:
		box = box.expand(position)
	return box


## Posición de cada muestra (en el orden de samples) con las formas y la pose de ahora.
func points(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var shaped := base.duplicate()
	for shape in offsets.size():
		var weight := mesh.get_blend_shape_value(shape)
		if weight != 0.0:
			var offset := offsets[shape]
			for s in shaped.size():
				shaped[s] += weight * offset[s]
	var matrices := MeshBaker.skin_matrices(skeleton, mesh.skin)
	var placed := PackedVector3Array()
	placed.resize(shaped.size())
	for s in shaped.size():
		var position := Vector3.ZERO
		var total := 0.0
		for k in range(4 * s, 4 * s + 4):
			if weights[k] > 0.0:
				position += weights[k] * (matrices[bones[k]] * shaped[s])
				total += weights[k]
		placed[s] = position / total
	return placed
