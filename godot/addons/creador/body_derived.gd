class_name BodyDerived
extends RefCounted
## Paso AB.9a (y AB.10): piezas hechas con caras del propio cuerpo, separadas un poco por su normal (casquete,
## guantes, calcetines y botas). Mismos vértices = mismas formas, huesos y pesos: siguen al cuerpo sin medir nada, y se
## generan al vuelo (no ocupan sitio en el programa). Sin interfaz.
## La máscara elige caras del cuerpo en reposo con reglas relativas a la caja de los vértices de su hueso (fracciones de
## 0 a 1: abajo/atrás → arriba/delante; x es la distancia al centro, 1 = el borde), no con números de la humana.
## Uso:
##   var mesh := BodyDerived.build(species.mesh, species.skeleton, "casquete", 0.004)   # MeshInstance3D suelta, o null
##   (BodyPiece.hang(mesh, species.skeleton) la cuelga del esqueleto; follow() la mueve como a las demás piezas)

const MeshBaker := preload("mesh_baker.gd")
const MIN_DELTA := 0.00001  # metros: una forma que mueve menos la pieza no se guarda
const HANDS := ["LeftHand", "RightHand", "LeftThumb", "RightThumb", "LeftIndex", "RightIndex", "LeftMiddle",
	"RightMiddle", "LeftRing", "RightRing", "LeftLittle", "RightLittle"]  # prefijos: la mano y sus dedos
const LEGS := ["LeftFoot", "RightFoot", "LeftToes", "RightToes", "LeftLowerLeg", "RightLowerLeg"]
## Reglas de cada máscara: huesos (prefijos del nombre), peso mínimo de la suma de esos huesos y zonas (un vértice
## entra si cumple alguna zona entera; sin zonas, entran todos). La caja es la de los vértices de esos huesos.
const MASKS := {
	"casquete": {"huesos": ["Head"], "peso": 0.5, "zonas": [
		{"y_min": 0.755},  # la coronilla, hasta el nacimiento del pelo en la frente
		{"y_min": 0.48, "z_max": 0.40, "x_max": 0.84},  # los lados, por encima y detrás de las orejas
		{"y_min": 0.19, "z_max": 0.21}]},  # la nuca
	"guantes": {"huesos": HANDS, "peso": 0.5, "zonas": []},  # paso AB.10: hasta la muñeca
	"calcetines": {"huesos": LEGS, "peso": 0.5, "zonas": [{"y_max": 0.45}]},  # hasta media pantorrilla
	"botas": {"huesos": LEGS, "peso": 0.5, "zonas": [{"y_max": 0.85}]},  # hasta debajo de la rodilla
}


## La pieza de la máscara mask_name con sus caras separadas offset metros, o null si la máscara no existe o queda vacía.
static func build(body: MeshInstance3D, skeleton: Skeleton3D, mask_name: String, offset: float) -> MeshInstance3D:
	if not MASKS.has(mask_name):
		return null
	var keep := mask(body.mesh.surface_get_arrays(0), body.skin, skeleton, MASKS[mask_name])
	var piece := subset(body, keep, offset)
	if piece != null:
		piece.name = mask_name.capitalize()
	return piece


## Paso AB.5: la parte de source cuyos triángulos tienen los tres vértices en keep, separada offset por la normal, con
## sus formas (las que la mueven), huesos y pesos (una copia de su Skin). null si queda vacía. La usa GarmentCut.
static func subset(source: MeshInstance3D, keep: PackedByteArray, offset: float) -> MeshInstance3D:
	var arrays := source.mesh.surface_get_arrays(0)
	var source_index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var remap := {}
	var order := PackedInt32Array()
	var index := PackedInt32Array()
	for t in range(0, source_index.size(), 3):
		if keep[source_index[t]] and keep[source_index[t + 1]] and keep[source_index[t + 2]]:
			for k in 3:
				var v := source_index[t + k]
				if not remap.has(v):
					remap[v] = order.size()
					order.append(v)
				index.append(remap[v])
	if index.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = (source.mesh as ArrayMesh).blend_shape_mode
	var shapes := _shapes(source, order, offset, arrays[Mesh.ARRAY_VERTEX], mesh)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(arrays, order, index, offset), shapes)
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.skin = source.skin.duplicate()  # mismos binds y en el mismo orden: los índices de hueso siguen valiendo
	return piece


## 1 por cada vértice que entra en la máscara (en el cuerpo en reposo, sin formas).
static func mask(arrays: Array, skin: Skin, skeleton: Skeleton3D, rules: Dictionary) -> PackedByteArray:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / vertices.size()
	var wanted := {}  # índice de hueso → true, de los que empiezan por algún prefijo de la regla
	for b in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(b)
		if rules["huesos"].any(func(prefix: String) -> bool: return bone_name.begins_with(prefix)):
			wanted[b] = true
	var chosen := PackedByteArray()
	chosen.resize(vertices.size())
	var box := AABB()
	var found := false
	for i in vertices.size():
		var weight := 0.0
		for k in per:
			if wanted.has(skin.get_bind_bone(bones[i * per + k])):
				weight += weights[i * per + k]
		if weight >= rules["peso"]:
			chosen[i] = 1
			box = box.expand(vertices[i]) if found else AABB(vertices[i], Vector3.ZERO)
			found = true
	if not found or rules["zonas"].is_empty():
		return chosen
	var size := box.size.max(Vector3.ONE * 0.000001)
	var center_x := box.get_center().x
	for i in vertices.size():
		if chosen[i] == 0:
			continue
		var f := Vector3(absf(vertices[i].x - center_x) / (size.x * 0.5), (vertices[i].y - box.position.y) / size.y,
			(vertices[i].z - box.position.z) / size.z)
		chosen[i] = 1 if rules["zonas"].any(func(zone: Dictionary) -> bool: return _inside(f, zone)) else 0
	return chosen


static func _inside(f: Vector3, zone: Dictionary) -> bool:
	return f.y >= zone.get("y_min", 0.0) and f.y <= zone.get("y_max", 1.0) and f.z >= zone.get("z_min", 0.0) \
		and f.z <= zone.get("z_max", 1.0) and f.x <= zone.get("x_max", 1.0)


static func _arrays(source: Array, order: PackedInt32Array, index: PackedInt32Array, offset: float) -> Array:
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / vertices.size()
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	for i in order:
		out_vertices.append(vertices[i] + normals[i] * offset)
		out_normals.append(normals[i])
		out_uvs.append(uvs[i] if uvs.size() > i else Vector2.ZERO)
		for k in per:
			out_bones.append(bones[i * per + k])
			out_weights.append(weights[i * per + k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_vertices
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	arrays[Mesh.ARRAY_BONES] = out_bones
	arrays[Mesh.ARRAY_WEIGHTS] = out_weights
	arrays[Mesh.ARRAY_INDEX] = index
	return arrays


## Las formas del cuerpo que mueven la pieza, desplazadas igual por su normal; las añade a mesh por nombre.
static func _shapes(body: MeshInstance3D, order: PackedInt32Array, offset: float, base: PackedVector3Array,
		mesh: ArrayMesh) -> Array:
	var all := MeshBaker.shape_arrays(body.mesh)
	var shapes := []
	for s in all.size():
		var vertices: PackedVector3Array = all[s][Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = all[s][Mesh.ARRAY_NORMAL]
		var moved := false
		for i in order:
			if (vertices[i] - base[i]).length() > MIN_DELTA:
				moved = true
				break
		if not moved:
			continue
		var out_vertices := PackedVector3Array()
		var out_normals := PackedVector3Array()
		for i in order:
			out_vertices.append(vertices[i] + normals[i] * offset)
			out_normals.append(normals[i])
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = out_vertices
		shape[Mesh.ARRAY_NORMAL] = out_normals
		shapes.append(shape)
		mesh.add_blend_shape(body.mesh.get_blend_shape_name(s))
	return shapes
