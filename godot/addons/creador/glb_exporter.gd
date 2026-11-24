class_name GlbExporter
extends RefCounted
## Exporta el personaje del editor a un .glb listo para un juego (paso 3.6.5).
##
## Uso:
##   var error := GlbExporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], "user://heroe.glb", true)
## - t_pose: true = pose T horneada; false = pose A.
## Sin congelar la ventana (paso P.1): job = prepare(…) → compute(job) en un hilo → write(finish(job), job["toon"], ruta).
## Hornea (character_baker.gd), pasa los anclajes a nodos (sockets.gd) y escribe con GLTFDocument.
## Normales del estilo (paso 3.16, style_normals.gd): torso suavizado y cara de elipsoide; viajan en el .glb.
## En el archivo: Character → Armature → huesos, malla y anclajes (misma estructura que los .glb de Blender).
## El personaje del editor no cambia.
## Paso AB.7: pieces (BodyPiece) salen como mallas aparte del mismo esqueleto, horneadas igual, con un
## StandardMaterial3D de su color (el toon del .tres es el del cuerpo; en el juego se puede poner también a ellas).
## Material: StandardMaterial3D con luz, sin brillo (metálico 0, rugosidad 1; paso 3.11a), para que reciba sombra fuera
## del editor, con la prenda horneada en una textura (garment_texture.gd). Con la prenda oculta, sin textura: todo color piel.
## SH.8c: en estilo anime, la piel de esa textura lleva el rubor, los labios y las pecas (skin_paint.gd).
## El estilo toon no viaja en el .glb: al lado se guarda heroe.tres (paso 3.11b), el material toon con el contorno y
## los shaders incrustados (BodyMaterial.standalone()), que funciona sin el addon. En el juego:
##   malla.material_override = load("res://heroe.tres")
## Color por vértice: en el archivo, `garment` va en el alfa y el RGB es blanco. La norma glTF multiplica el material
## por el color por vértice (Blender lo hace): con `garment` en el RGB, la piel saldría negra.

const CharacterBaker := preload("character_baker.gd")
const Sockets := preload("sockets.gd")
const BodyMaterial := preload("body_material.gd")
const GarmentTexture := preload("garment_texture.gd")
const SkinPaint := preload("skin_paint.gd")  # SH.8c
const StyleNormals := preload("style_normals.gd")
const TEXTURE_SIZE := 2048  # 1 píxel ≈ 0,9 mm en el borde de la prenda (medido en el paso 3.6.6)


## El personaje que se exporta, en memoria (quien llama lo libera). null si no se puede (ver Sockets.error).
## En pose T, los huesos salen con los ejes del perfil humanoide (D11, paso 5.16): un juego lo anima sin «Overwrite Axis».
static func build(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, t_pose: bool, pieces: Array = [],
		rigid: Array = []) -> Node3D:
	var job := prepare(mesh, skeleton, socket_names, t_pose, pieces, rigid)
	compute(job)
	return finish(job)


## Paso P.1: exportar en tres partes, para que lo pesado (compute, ~1,3 s) vaya en un hilo.
## prepare: hilo principal. Hornea y lee del editor todo lo que hace falta; lo que cambie después no entra.
static func prepare(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, t_pose: bool,
		pieces: Array = [], rigid: Array = []) -> Dictionary:
	var baked: Node3D = CharacterBaker.bake(mesh, skeleton, t_pose, t_pose, pieces, rigid)
	var character: Node3D = Sockets.to_nodes(baked, socket_names)
	baked.free()
	if character != null:
		var colored: Array = pieces.duplicate()
		for holder: Node in rigid:  # paso AB.11
			colored.append_array(holder.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D))
		_color_pieces(character, colored)
	var job := {"character": character, "toon": BodyMaterial.standalone(mesh),
		"skin": BodyMaterial.get_color(mesh, "skin_color"), "garment": BodyMaterial.get_color(mesh, "garment_color"),
		"garment_visible": BodyMaterial.is_garment_visible(mesh)}
	if BodyMaterial.is_soft(mesh):  # SH.8c: el rubor, los labios y las pecas van pintados en la textura del .glb
		var zones: Texture2D = (mesh.material_override as ShaderMaterial).get_shader_parameter("skin_zones")
		var image: Image = zones.get_image() if zones != null else null
		if image != null:
			job["paint"] = {"zones": image, "params": BodyMaterial.get_skin(mesh)}
	if character != null:
		var exported := character.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		job["arrays"] = exported.mesh.surface_get_arrays(0)
		job["head"] = StyleNormals.head_weights(job["arrays"], exported.skin, exported.get_parent() as Skeleton3D)
	return job


## compute: cualquier hilo. Solo arrays e Image: normales del estilo, `garment` al alfa y la textura de la prenda.
static func compute(job: Dictionary) -> void:
	if job["character"] == null:
		return
	var arrays: Array = job["arrays"]
	arrays[Mesh.ARRAY_NORMAL] = StyleNormals.apply(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL],
		arrays[Mesh.ARRAY_INDEX], job["head"])
	arrays[Mesh.ARRAY_TANGENT] = null  # ya no casarían con las normales (sin mapas de normales no hacen falta)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var skin_image: Image = null
	if job.has("paint"):  # SH.8c
		skin_image = SkinPaint.skin_image(TEXTURE_SIZE, job["skin"], job["paint"]["zones"], job["paint"]["params"])
	if job["garment_visible"]:  # la textura lee `garment` en el rojo: antes de pasarlo al alfa
		job["image"] = GarmentTexture.bake_arrays(arrays[Mesh.ARRAY_TEX_UV], colors, arrays[Mesh.ARRAY_INDEX],
			TEXTURE_SIZE, job["skin"], job["garment"], skin_image)
	elif skin_image != null:
		job["image"] = skin_image
	for i in colors.size():
		colors[i] = Color(1.0, 1.0, 1.0, colors[i].r)
	arrays[Mesh.ARRAY_COLOR] = colors


## finish: hilo principal. Crea la malla y el material; devuelve el personaje (null si no se pudo).
static func finish(job: Dictionary) -> Node3D:
	var character: Node3D = job["character"]
	if character != null:
		var exported := character.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, job["arrays"])
		mesh.surface_set_material(0, _material(job))
		exported.mesh = mesh
	return character


static func _material(job: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "cuerpo"
	material.metallic = 0.0  # PBR sin brillo
	material.roughness = 1.0
	if job.has("image"):
		material.albedo_texture = ImageTexture.create_from_image(job["image"])
	else:
		material.albedo_color = job["skin"]
	return material


static func save(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, path: String, t_pose: bool,
		pieces: Array = []) -> Error:
	return write(build(mesh, skeleton, socket_names, t_pose, pieces), BodyMaterial.standalone(mesh), path)


## Paso AB.7: material de cada pieza exportada (todas las mallas detrás de la primera), con el color del editor.
static func _color_pieces(character: Node3D, pieces: Array) -> void:
	var colors := {}
	for piece: MeshInstance3D in pieces:
		colors[piece.name] = BodyMaterial.get_color(piece, "skin_color")
	for exported: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false).slice(1):
		var material := StandardMaterial3D.new()
		material.resource_name = String(exported.name).to_lower()
		material.metallic = 0.0
		material.roughness = 1.0
		material.albedo_color = colors.get(exported.name, Color.WHITE)
		exported.mesh.surface_set_material(0, material)


## write: hilo principal. Escribe el .glb y, al lado, el material toon (.tres). Libera el personaje.
static func write(character: Node3D, toon: ShaderMaterial, path: String) -> Error:
	if character == null:
		return ERR_INVALID_DATA
	_add_armature_node(character)
	_set_owner(character, character)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(character, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	if error == OK:
		error = ResourceSaver.save(toon, path.get_basename() + ".tres")
	character.free()
	return error


## Mete el esqueleto en un nodo "Armature", como los .glb de Blender: así valen los mismos ajustes de
## importación de Godot (el BoneMap se asigna a la ruta Armature/Skeleton3D).
static func _add_armature_node(character: Node3D) -> void:
	var skeleton := character.get_child(0)
	var armature := Node3D.new()
	armature.name = "Armature"
	character.remove_child(skeleton)
	character.add_child(armature)
	armature.add_child(skeleton)


static func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner(child, owner)
