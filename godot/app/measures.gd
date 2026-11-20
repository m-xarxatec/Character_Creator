extends RefCounted
# Paso IU.8a: medidas en vivo del personaje para la barra de estado: altura en metros y cabezas de alto.
# Rápida: la muestra de vértices de character_box.gd (con los extremos en reposo) más la barbilla.
# Barbilla (regla del paso 3.12, probar_estilo.gd): entre los vértices cuyo hueso de más peso es Head, los del centro
# (|x| < 10 % del ancho de la cabeza) y de delante (z > centro de la cabeza), el más bajo en reposo.
# Paso PL.1a: proportions(), las medidas de diseno/GUIA_ESTILO.md §2 con la malla horneada entera (exacta, más lenta).
# Uso: var measures := Measures.new(species.mesh, species.skeleton)
#      var m := measures.measure(species.mesh, species.skeleton)   # {height, head, heads}
#      var p := Measures.proportions(species.mesh, species.skeleton)   # ver proportions()

const CharacterBox := preload("character_box.gd")
const MeshBaker := preload("../addons/creador/mesh_baker.gd")
const CENTER := 0.1  # fracción del ancho de la cabeza que cuenta como «centro»
const HAND_PARTS := ["Hand", "Thumb", "Index", "Middle", "Ring", "Little"]
const FOOT_PARTS := ["Foot", "Toes"]
const TORSO := ["Hips", "Spine", "Chest", "UpperChest"]
const MIDLINE := 0.005  # metros: vértices del centro, donde está la ingle
const SHOULDER_BAND := 0.01  # metros arriba y abajo de la articulación del hombro
const SLICE := 0.005  # metros entre los cortes de la cintura
const WAIST_BAND := 0.015  # metros arriba y abajo de cada corte (la malla tiene un vértice cada 1–2 cm)

var box  # CharacterBox con la barbilla en la muestra
var chin := -1  # índice del vértice de la barbilla en la malla
var chin_sample := -1  # su posición en la muestra


func _init(mesh: MeshInstance3D, skeleton: Skeleton3D) -> void:
	chin = chin_vertex(mesh, skeleton)
	box = CharacterBox.new(mesh, PackedInt32Array([chin]))
	chin_sample = Array(box.samples).find(chin)


## La barbilla en reposo (sin formas), por la regla del 3.12.
static func chin_vertex(mesh: MeshInstance3D, skeleton: Skeleton3D) -> int:
	return chin_index(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], head_mask(mesh, skeleton))


## La barbilla de esos vértices: de los de la cabeza (mask), los del centro y de delante, el más bajo.
static func chin_index(vertices: PackedVector3Array, mask: PackedByteArray) -> int:
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
	var names := dominant_bones(mesh, skeleton)
	var mask := PackedByteArray()
	mask.resize(names.size())
	for v in names.size():
		mask[v] = 1 if names[v] == "Head" else 0
	return mask


## Nombre del hueso de más peso de cada vértice.
static func dominant_bones(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedStringArray:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bind_names := PackedStringArray()
	for i in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(i)
		bind_names.append(skeleton.get_bone_name(bone) if bone >= 0 else String(mesh.skin.get_bind_name(i)))
	var names := PackedStringArray()
	names.resize(weights.size() / 4)
	for v in names.size():
		var best := 0
		for k in range(1, 4):
			if weights[4 * v + k] > weights[4 * v + best]:
				best = k
		names[v] = bind_names[bones[4 * v + best]]
	return names


## Paso PL.1a: medidas de GUIA_ESTILO.md §2 con la malla horneada entera (llamarla en reposo). Ratios:
##   heads = altura ÷ cabeza (coronilla − barbilla); legs = ingle ÷ altura (ingle: el vértice más bajo del torso en el
##   centro); shoulders = ancho a la altura de los hombros (cabeza de UpperArm, ± SHOULDER_BAND) ÷ cabeza;
##   waist = el corte más estrecho del torso, de la cadera a medio camino entre UpperChest y el hombro ÷ ese ancho; hand = de la muñeca al
##   vértice de la mano más lejano ÷ cabeza; foot = largo en Z de pie y dedos ÷ cabeza (mano y pie: media de los lados).
## Y en metros: height, head, hand_l, hand_r, foot_l, foot_r; waist_at: dónde está la cintura en ese tramo (0 cadera, 1 arriba).
static func proportions(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Dictionary:
	var vertices: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
	var names := dominant_bones(mesh, skeleton)
	var globals := MeshBaker.global_poses(skeleton)
	var head_names := PackedByteArray()
	head_names.resize(names.size())
	var top := -INF
	var bottom := INF
	var crotch := INF
	for v in vertices.size():
		head_names[v] = 1 if names[v] == "Head" else 0
		top = maxf(top, vertices[v].y)
		bottom = minf(bottom, vertices[v].y)
		if absf(vertices[v].x) < MIDLINE and names[v] in TORSO:
			crotch = minf(crotch, vertices[v].y)
	var height := top - bottom
	var head := top - vertices[chin_index(vertices, head_names)].y
	var joint := func(bone: String) -> Vector3: return globals[skeleton.find_bone(bone)].origin
	var shoulder_y: float = (joint.call("LeftUpperArm").y + joint.call("RightUpperArm").y) / 2.0
	var shoulders := _width(vertices, names, shoulder_y, SHOULDER_BAND, [])
	var waist := INF
	var hip_y: float = (joint.call("LeftUpperLeg").y + joint.call("RightUpperLeg").y) / 2.0
	var top_y: float = (joint.call("UpperChest").y + shoulder_y) / 2.0  # a medio camino del hombro: por la axila
	var waist_y := hip_y
	var y := hip_y
	while y <= top_y:
		var width := _width(vertices, names, y, WAIST_BAND, TORSO)
		if width < waist:
			waist = width
			waist_y = y
		y += SLICE
	var result := {"height": height, "head": head, "heads": height / head, "legs": (crotch - bottom) / height,
		"shoulders": shoulders / head, "waist": waist / shoulders, "waist_at": (waist_y - hip_y) / (top_y - hip_y)}
	for side in ["Left", "Right"]:
		var wrist: Vector3 = joint.call(side + "Hand")
		var hand := 0.0
		var heel := INF
		var toe := -INF
		for v in vertices.size():
			if not names[v].begins_with(side):
				continue
			var part := names[v].trim_prefix(side)
			if HAND_PARTS.any(func(p: String) -> bool: return part.begins_with(p)):
				hand = maxf(hand, vertices[v].distance_to(wrist))
			elif part in FOOT_PARTS:
				heel = minf(heel, vertices[v].z)
				toe = maxf(toe, vertices[v].z)
		var key := "_l" if side == "Left" else "_r"
		result["hand" + key] = hand
		result["foot" + key] = toe - heel
	result["hand"] = (result["hand_l"] + result["hand_r"]) / 2.0 / head
	result["foot"] = (result["foot_l"] + result["foot_r"]) / 2.0 / head
	return result


## Ancho en X de los vértices a esa altura (± half); only: solo los de esos huesos (vacío = todos). INF si no hay
## vértices a los dos lados del centro.
static func _width(vertices: PackedVector3Array, names: PackedStringArray, y: float, half: float, only: Array) -> float:
	var low := INF
	var high := -INF
	for v in vertices.size():
		if absf(vertices[v].y - y) <= half and (only.is_empty() or names[v] in only):
			low = minf(low, vertices[v].x)
			high = maxf(high, vertices[v].x)
	return high - low if low < 0.0 and high > 0.0 else INF


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
