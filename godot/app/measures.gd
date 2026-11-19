extends RefCounted
# Paso IU.8a: medidas en vivo del personaje para la barra de estado: altura en metros y cabezas de alto.
# Rápida: la muestra de vértices de character_box.gd (con los extremos en reposo) más la barbilla.
# Barbilla (regla del paso 3.12, probar_estilo.gd): entre los vértices cuyo hueso de más peso es Head, los del centro
# (|x| < 10 % del ancho de la cabeza) y de delante (z > centro de la cabeza), el más bajo en reposo.
# Uso: var measures := Measures.new(species.mesh, species.skeleton)
#      var m := measures.measure(species.mesh, species.skeleton)   # {height, head, heads}

const CharacterBox := preload("character_box.gd")
const CENTER := 0.1  # fracción del ancho de la cabeza que cuenta como «centro»

var box  # CharacterBox con la barbilla en la muestra
var chin := -1  # índice del vértice de la barbilla en la malla
var chin_sample := -1  # su posición en la muestra


func _init(mesh: MeshInstance3D, skeleton: Skeleton3D) -> void:
	chin = chin_vertex(mesh, skeleton)
	box = CharacterBox.new(mesh, PackedInt32Array([chin]))
	chin_sample = Array(box.samples).find(chin)


## La barbilla en reposo (sin formas), por la regla del 3.12.
static func chin_vertex(mesh: MeshInstance3D, skeleton: Skeleton3D) -> int:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mask := head_mask(mesh, skeleton)
	var head_box := AABB()
	var first := true
	for i in vertices.size():
		if mask[i]:
			head_box = AABB(vertices[i], Vector3.ZERO) if first else head_box.expand(vertices[i])
			first = false
	var best := -1
	for i in vertices.size():
		if mask[i] and absf(vertices[i].x) < CENTER * head_box.size.x and vertices[i].z > head_box.get_center().z:
			if best < 0 or vertices[i].y < vertices[best].y:
				best = i
	return best


## 1 en los vértices cuyo hueso de más peso es Head.
static func head_mask(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedByteArray:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var head := -1
	for i in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(i)
		var bone_name: String = skeleton.get_bone_name(bone) if bone >= 0 else String(mesh.skin.get_bind_name(i))
		if bone_name == "Head":
			head = i
	var mask := PackedByteArray()
	mask.resize(weights.size() / 4)
	for v in mask.size():
		var best := 0
		for k in range(1, 4):
			if weights[4 * v + k] > weights[4 * v + best]:
				best = k
		mask[v] = 1 if bones[4 * v + best] == head else 0
	return mask


## {height, head, heads} con las formas y la pose de ahora (llamarla en reposo).
func measure(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Dictionary:
	var placed: PackedVector3Array = box.points(mesh, skeleton)
	var top := -INF
	var bottom := INF
	for p: Vector3 in placed:
		top = maxf(top, p.y)
		bottom = minf(bottom, p.y)
	var head := top - placed[chin_sample].y
	var height := top - bottom
	return {"height": height, "head": head, "heads": height / head if head > 0.0 else 0.0}
