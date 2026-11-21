class_name RigidPiece
extends RefCounted
## Paso AB.11: accesorio rígido hecho por un generador (pack.json: «generador»: {tipo, parametros, simetria}; hoy, cuernos)
## (cuernos y aros: orejas de gato, halo) y colgado de un hueso con un BoneAttachment3D: sigue su pose, su escala (Cabeza › Tamaño) y el reajuste del esqueleto.
## «anclaje.transform» lo coloca respecto al hueso (posición, giro como cuaternión y escala uniforme); con «simetria»,
## una segunda copia reflejada en X (geometría reflejada, sin escala negativa). Sin assets: la malla sale de los
## parámetros (se regenera igual al abrir).
## Uso:
##   var holder := RigidPiece.build(card, species.skeleton)   # BoneAttachment3D ya colgado, o null
##   for mesh in RigidPiece.meshes(holder): …                  # sus mallas (una o dos)
## Al exportar, CharacterBaker.bake(…, rigid) las pasa a mallas con piel, al 100 % de su hueso.

const HornGenerator := preload("horn_generator.gd")
const RingGenerator := preload("ring_generator.gd")
const GENERATORS := {"cuernos": HornGenerator, "aro": RingGenerator}


static func build(card: Dictionary, skeleton: Skeleton3D) -> BoneAttachment3D:
	var generator: Dictionary = card.get("generador", {})
	var script: GDScript = GENERATORS.get(generator.get("tipo", ""))
	var bone: String = card["anclaje"]["hueso"]
	if script == null or skeleton.find_bone(bone) < 0:
		return null
	var mesh: ArrayMesh = script.build(generator.get("parametros", {}))
	var holder := BoneAttachment3D.new()
	holder.name = card["id"]
	skeleton.add_child(holder)
	holder.bone_name = bone
	var t: Array = card["anclaje"]["transform"]
	var place := Transform3D(Basis(Quaternion(t[3], t[4], t[5], t[6]).normalized()).scaled(Vector3.ONE * t[7]),
		Vector3(t[0], t[1], t[2]))
	var sides: Array = [1.0, -1.0] if generator.get("simetria", false) == true else [1.0]
	var mirror := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	for side: float in sides:
		var instance := MeshInstance3D.new()
		instance.name = "%s_%s" % [card["id"], "d" if side > 0.0 else "i"]
		# La copia reflejada lleva la malla reflejada y mirror·place·mirror (sin escala negativa): con escala negativa
		# el contorno (outline.gdshader, caras de atrás) no salía.
		instance.mesh = mesh if side > 0.0 else _mirrored(mesh)
		instance.transform = place if side > 0.0 else mirror * place * mirror
		holder.add_child(instance)
	return holder


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
