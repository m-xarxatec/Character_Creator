class_name RigidPiece
extends RefCounted
## Paso AB.11: accesorio rígido hecho por un generador (pack.json: «generador»: {tipo, parametros, simetria}; hoy, cuernos)
## (cuernos y aros: halo) y colgado de un hueso con un BoneAttachment3D: sigue su pose, su escala (Cabeza › Tamaño) y el reajuste del esqueleto.
## «anclaje.transform» lo coloca respecto al hueso (posición, giro como cuaternión y escala uniforme); con «simetria»,
## una segunda copia reflejada en X (geometría reflejada, sin escala negativa). Sin assets: la malla sale de los
## parámetros (se regenera igual al abrir).
## Paso 13.3d: o una pieza importada (is_rigid), sin generador: una malla por parte de PieceImport.read.
## Uso:
##   var holder := RigidPiece.build(card, species.skeleton)   # BoneAttachment3D ya colgado, o null
##   var holder := RigidPiece.build(card, species.skeleton, PieceImport.read(path)["partes"])   # importada
##   for mesh in RigidPiece.meshes(holder): …                  # sus mallas (una o dos)
##   RigidPiece.set_place(holder, "RightHand", place)          # paso 13.1a: otro hueso u otro sitio (false si no existe)
## Al exportar, CharacterBaker.bake(…, rigid) las pasa a mallas con piel, al 100 % de su hueso.

const HornGenerator := preload("horn_generator.gd")
const RingGenerator := preload("ring_generator.gd")
const GENERATORS := {"cuernos": HornGenerator, "aro": RingGenerator}


## Paso 13.3d: ¿es un accesorio rígido? Con generador, o accesorio con archivo que no sigue al cuerpo (pieza importada).
static func is_rigid(card: Dictionary) -> bool:
	return card.get("generador") != null or (card.get("tipo") == "accesorio" and card.get("sigue_al_cuerpo") != true
		and card.get("archivo", "") != "")


## parts (paso 13.3d): las de PieceImport.read, para una pieza sin generador. null si no hay mallas o falta el hueso.
static func build(card: Dictionary, skeleton: Skeleton3D, parts := []) -> BoneAttachment3D:
	var made := _generated(card) if card.get("generador") != null else _imported(card["id"], parts)
	var bone: String = card["anclaje"]["hueso"]
	if made.is_empty() or skeleton.find_bone(bone) < 0:
		return null
	var holder := BoneAttachment3D.new()
	holder.name = card["id"]
	skeleton.add_child(holder)
	for mesh_name: String in made:
		var instance := MeshInstance3D.new()
		instance.name = mesh_name
		instance.mesh = made[mesh_name]
		holder.add_child(instance)
	var anchor := default_place(card)
	set_place(holder, anchor["hueso"], anchor["place"])
	return holder


## {nombre: malla} del generador de la ficha («<id>_d» y, con simetría, «<id>_i»); {} si no se conoce.
static func _generated(card: Dictionary) -> Dictionary:
	var generator: Dictionary = card["generador"]
	var script: GDScript = GENERATORS.get(generator.get("tipo", ""))
	if script == null:
		return {}
	var mesh: ArrayMesh = script.build(generator.get("parametros", {}))
	var made := {card["id"] + "_d": mesh}
	if generator.get("simetria", false) == true:
		made[card["id"] + "_i"] = _mirrored(mesh)
	return made


## {nombre: malla} de las partes importadas, en su orden: «<id>_m<k>» (nunca «_i», que set_place reflejaría).
static func _imported(id: String, parts: Array) -> Dictionary:
	var made := {}
	for k: int in parts.size():
		made["%s_m%d" % [id, k]] = parts[k]["mesh"]
	return made


## Paso 13.1a: [px, py, pz, qx, qy, qz, qw, escala] → Transform3D.
static func to_place(numbers: Array) -> Transform3D:
	var t := numbers
	return Transform3D(Basis(Quaternion(t[3], t[4], t[5], t[6]).normalized()).scaled(Vector3.ONE * t[7]),
		Vector3(t[0], t[1], t[2]))


## Al revés, redondeado a 6 decimales (como ProjectFile). Escala = media de get_scale(); giro de basis.orthonormalized().
static func to_array(place: Transform3D) -> Array:
	var q := place.basis.orthonormalized().get_rotation_quaternion()
	var s := place.basis.get_scale()
	var numbers := [place.origin.x, place.origin.y, place.origin.z, q.x, q.y, q.z, q.w, (s.x + s.y + s.z) / 3.0]
	return numbers.map(func(n: float) -> float: return snappedf(n, 1e-6))


## El anclaje de serie de la ficha (card["anclaje"]).
static func default_place(card: Dictionary) -> Dictionary:
	return {"hueso": card["anclaje"]["hueso"], "place": to_place(card["anclaje"]["transform"])}


## Cuelga el accesorio de bone (si existe) y coloca sus mallas: «_d» = place; «_i» = mirror·place·mirror (la malla
## ya va reflejada: sin escala negativa, que quitaba el contorno de outline.gdshader). Guarda place en la meta
## "place". false si el hueso no existe (no cambia nada).
static func set_place(holder: BoneAttachment3D, bone: String, place: Transform3D) -> bool:
	var skeleton := holder.get_parent() as Skeleton3D
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return false
	holder.bone_name = bone
	var mirror := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	for instance in meshes(holder):
		instance.transform = mirror * place * mirror if String(instance.name).ends_with("_i") else place
	holder.set_meta("place", place)
	return true


static func get_place(holder: BoneAttachment3D) -> Transform3D:
	return holder.get_meta("place", Transform3D())


## La malla reflejada en X, con las normales reflejadas y los triángulos al revés (siguen mirando hacia fuera).
static func _mirrored(source: ArrayMesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		vertices[i].x = -vertices[i].x
		normals[i].x = -normals[i].x
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, index.size(), 3):
		var keep := index[t + 1]
		index[t + 1] = index[t + 2]
		index[t + 2] = keep
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = index
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func meshes(holder: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in holder.get_children():
		if child is MeshInstance3D:
			found.append(child)
	return found


## Una malla del accesorio como malla con piel del esqueleto horneado: vértices en el espacio del esqueleto con la pose
## posed (con escala), al 100 % de su hueso; bind pose = inversa de rest (el reposo nuevo). Si la copia está reflejada,
## se da la vuelta a los triángulos para que sigan mirando hacia fuera.
static func to_skinned(instance: MeshInstance3D, bone: int, posed: Transform3D, rest: Transform3D, shift: Vector3) -> MeshInstance3D:
	var place := posed * instance.transform
	var arrays := instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normal_basis := place.basis.inverse().transposed()
	for i in vertices.size():
		vertices[i] = place * vertices[i] + shift
		normals[i] = (normal_basis * normals[i]).normalized()
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if place.basis.determinant() < 0.0:
		for t in range(0, index.size(), 3):
			var keep := index[t + 1]
			index[t + 1] = index[t + 2]
			index[t + 2] = keep
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for i in vertices.size():
		bones.append_array([0, 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = index
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var skin := Skin.new()
	skin.add_bind(bone, rest.affine_inverse())
	var out := MeshInstance3D.new()
	out.name = instance.name
	out.mesh = mesh
	out.skin = skin
	return out
