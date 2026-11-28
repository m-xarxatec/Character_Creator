class_name GlbExporter
extends RefCounted
## Exporta el personaje del editor a un .glb listo para un juego (paso 3.6.5).
##
## Uso:
##   var error := GlbExporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], "user://heroe.glb", true)
## - t_pose: true = pose T horneada; false = pose A.
## Sin congelar la ventana (paso P.1): job = prepare(…) → compute(job) en un hilo → write(finish(job), job["toon"], ruta).
## OPT.3b: también el horneado va en un hilo; ver start.
## Hornea (character_baker.gd), pasa los anclajes a nodos (sockets.gd) y escribe con GLTFDocument.
## Normales del estilo (paso 3.16, style_normals.gd): torso suavizado y cara de elipsoide; viajan en el .glb.
## En el archivo: Character → Armature → huesos, malla y anclajes (misma estructura que los .glb de Blender).
## El personaje del editor no cambia.
## Paso AB.7: pieces (BodyPiece) salen como mallas aparte del mismo esqueleto, horneadas igual, con un
## StandardMaterial3D de su color (el toon del .tres es el del cuerpo; en el juego se puede poner también a ellas).
## Paso 13.3h-c: la pieza con textura (BodyMaterial.get_base_texture) la lleva en albedo_texture, con su color (glTF los
## multiplica, como la vista).
## Material: StandardMaterial3D con luz, sin brillo (metálico 0, rugosidad 1; paso 3.11a), para que reciba sombra fuera
## del editor, con la prenda horneada en una textura (garment_texture.gd). Con la prenda oculta, sin textura: todo color piel.
## SH.8c: en estilo anime, la piel de esa textura lleva el rubor, los labios y las pecas (skin_paint.gd).
## Paso 9.7.3 (D31): las expresiones salen como formas (morph targets) del cuerpo y de cada malla que las tenga, con el
## nombre VRM; solo posiciones (las normales del estilo no tienen forma). La bolsa hundida tras el ojo las conserva.
## El estilo toon no viaja en el .glb: al lado se guarda heroe.tres (paso 3.11b), el material toon con el contorno y
## los shaders incrustados (BodyMaterial.standalone()), que funciona sin el addon. En el juego:
##   malla.material_override = load("res://heroe.tres")
## Color por vértice: en el archivo, `garment` va en el alfa y el RGB es blanco. La norma glTF multiplica el material
## por el color por vértice (Blender lo hace): con `garment` en el RGB, la piel saldría negra. 9.8b (D58): justo eso
## se usa para el interior de la boca: allí el RGB es MOUTH_DARK y la boca abierta se ve oscura en cualquier visor.
## Paso AC.6b: eyes (las mallas de EyeMesh) salen como piezas, con sus capas y líneas horneadas en texturas
## (eye_texture.gd) en vez de color plano; eye_data (ojos.json) dice qué vértices del cuerpo forman cada bolsa, que en
## la copia se hunde EYE_SINK detrás del ojo (sin depth_pull, dos superficies iguales parpadearían). El lazo no se mueve.

const CharacterBaker := preload("character_baker.gd")
const Sockets := preload("sockets.gd")
const BodyMaterial := preload("body_material.gd")
const GarmentTexture := preload("garment_texture.gd")
const SkinPaint := preload("skin_paint.gd")  # SH.8c
const StyleNormals := preload("style_normals.gd")
const EyeTexture := preload("eye_texture.gd")  # AC.6b
const MeshBaker := preload("mesh_baker.gd")  # paso 9.7.3
const TEXTURE_SIZE := 2048  # 1 píxel ≈ 0,9 mm en el borde de la prenda (medido en el paso 3.6.6)
const EYE_SINK := 0.001  # metros: lo que se hunde la bolsa del cuerpo detrás del ojo (AC.3b §5.7)
const MOUTH_DARK := 0.06  # 9.8b (D58): el color por vértice del interior de la boca en el .glb (× la textura: casi negro)
const EYE_THREADS := 2  # hilos para las texturas del ojo: con más, la ventana pierde fluidez al exportar (medido)


## El personaje que se exporta, en memoria (quien llama lo libera). null si no se puede (ver Sockets.error).
## En pose T, los huesos salen con los ejes del perfil humanoide (D11, paso 5.16): un juego lo anima sin «Overwrite Axis».
static func build(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, t_pose: bool, pieces: Array = [],
		rigid: Array = [], eyes: Array = [], eye_data: Dictionary = {}) -> Node3D:
	var job := prepare(mesh, skeleton, socket_names, t_pose, pieces, rigid, eyes, eye_data)
	compute(job)
	return finish(job)


## Paso P.1: exportar en partes, para que lo pesado vaya en un hilo. Paso OPT.3b: el horneado también.
## Orden: start (principal) → compute_bake (hilo) → after_bake (principal) → compute (hilo) → finish (principal) → write.
## prepare = start + compute_bake + after_bake, todo seguido (para quien no usa hilos).
static func prepare(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, t_pose: bool,
		pieces: Array = [], rigid: Array = [], eyes: Array = [], eye_data: Dictionary = {}, cache: Variant = null) -> Dictionary:
	var job := start(mesh, skeleton, socket_names, t_pose, pieces, rigid, eyes, eye_data, cache)
	compute_bake(job)
	after_bake(job)
	return job


## start: hilo principal. Lee del editor todo lo que hace falta; lo que cambie después no entra.
## cache (paso OPT.3a): las formas del cuerpo que la vista ya tiene (StyleView.shape_cache()); así no se piden a la malla
## (335–386 ms con ventana). Solo se le añaden las que falten; el archivo sale igual.
static func start(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, t_pose: bool,
		pieces: Array = [], rigid: Array = [], eyes: Array = [], eye_data: Dictionary = {}, cache: Variant = null) -> Dictionary:
	var colors := {}  # paso AB.7 y AB.11: color del editor de cada pieza y accesorio, por nombre
	var textures := {}  # paso 13.3h-c: textura de las que la tienen, por nombre
	var colored: Array = pieces.duplicate()
	for holder: Node in rigid:
		colored.append_array(holder.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D))
	for piece: MeshInstance3D in colored:
		colors[piece.name] = BodyMaterial.get_color(piece, "skin_color")
		var texture := BodyMaterial.get_base_texture(piece)
		if texture != null:
			textures[piece.name] = texture
	var eye_values := []  # AC.6b
	for eye: MeshInstance3D in eyes:
		var is_eye := String(eye.name).begins_with("ojo_")
		eye_values.append({"name": eye.name, "is_eye": is_eye,
			"values": EyeTexture.eye_values(eye) if is_eye else EyeTexture.line_values(eye)})
	var job := {"bake": CharacterBaker.prepare_bake(mesh, skeleton, t_pose, t_pose, pieces + eyes, rigid, cache),
		"sockets": socket_names, "colors": colors, "textures": textures, "eye_values": eye_values, "eye_data": eye_data,
		"toon": BodyMaterial.standalone(mesh),
		"skin": BodyMaterial.get_color(mesh, "skin_color"), "garment": BodyMaterial.get_color(mesh, "garment_color"),
		"garment_visible": BodyMaterial.is_garment_visible(mesh)}
	if BodyMaterial.is_soft(mesh):  # SH.8c: el rubor, los labios y las pecas van pintados en la textura del .glb
		var zones: Texture2D = (mesh.material_override as ShaderMaterial).get_shader_parameter("skin_zones")
		var image: Image = zones.get_image() if zones != null else null
		if image != null:
			job["paint"] = {"zones": image, "params": BodyMaterial.get_skin(mesh)}
	return job


## compute_bake (OPT.3b): cualquier hilo. Formas y huesos de todas las mallas (CharacterBaker.compute_bake).
static func compute_bake(job: Dictionary) -> void:
	CharacterBaker.compute_bake(job["bake"])


## after_bake (OPT.3b): hilo principal. Crea el personaje horneado y lo pasa a anclajes; lee sus arrays para compute.
## Las mallas se crean aquí y se leen otra vez (como antes de OPT.3b): Godot comprime las normales al crear la malla, y
## compute tiene que partir de los mismos números para que el archivo salga idéntico.
static func after_bake(job: Dictionary) -> void:
	# Paso 9.7.3 (revisión): las expresiones de cada malla, ya calculadas en compute_bake. Leerlas otra vez de las
	# mallas horneadas serían más pasadas por todos los vértices en el hilo principal.
	var morphs := {}
	for entry: Dictionary in job["bake"]["meshes"]:
		morphs[entry["name"]] = entry["morphs"]
	var body_morphs: Dictionary = job["bake"]["meshes"][0]["morphs"]  # el cuerpo es la primera
	var baked: Node3D = CharacterBaker.finish_bake(job["bake"])
	job.erase("bake")  # ~decenas de MB de arrays y formas: ya no hacen falta
	var character: Node3D = Sockets.to_nodes(baked, job["sockets"])
	baked.free()
	job["character"] = character
	if character == null:
		return
	_color_pieces(character, job["colors"], job["eye_values"].map(func(e: Dictionary) -> StringName: return e["name"]),
		job["textures"])
	var exported := character.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	job["arrays"] = exported.mesh.surface_get_arrays(0)
	job["morphs"] = body_morphs  # paso 9.7.3: las expresiones (desplazamientos)
	job["head"] = StyleNormals.head_weights(job["arrays"], exported.skin, exported.get_parent() as Skeleton3D)
	job["eyes"] = _prepare_eyes(character, job["eye_values"], job["eye_data"], morphs)


## AC.6b: de cada malla del ojo, sus arrays horneados y sus uniforms (leídos en start); de cada ojo con datos, los
## vértices del cuerpo que se hunden (la bolsa menos el lazo) y la normal del ojo horneado. morphs (9.7.3): malla →
## sus expresiones, de compute_bake.
static func _prepare_eyes(character: Node3D, eye_values: Array, eye_data: Dictionary, morphs: Dictionary) -> Array:
	var out := []
	for read: Dictionary in eye_values:
		var exported := character.find_child(read["name"], true, false) as MeshInstance3D
		var is_eye: bool = read["is_eye"]
		var entry := {"name": read["name"], "is_eye": is_eye, "arrays": exported.mesh.surface_get_arrays(0),
			"values": read["values"], "morphs": morphs.get(read["name"], {})}
		var side := String(read["name"]).get_slice("_", 1)
		if is_eye and eye_data.has(side):
			var rim := {}
			for v: float in eye_data[side]["lazo"]:
				rim[int(v)] = true
			var sunk := PackedInt32Array()
			for v: float in eye_data[side]["bolsa"]:
				if not rim.has(int(v)):
					sunk.append(int(v))
			entry["sink"] = sunk
			entry["normal"] = (entry["arrays"][Mesh.ARRAY_NORMAL] as PackedVector3Array)[0]
		out.append(entry)
	return out


## compute: cualquier hilo. Solo arrays e Image: normales del estilo, `garment` al alfa y la textura de la prenda.
static func compute(job: Dictionary) -> void:
	if job["character"] == null:
		return
	var eyes: Array = job["eyes"]  # AC.6b: sus texturas, en paralelo con la del cuerpo (no dependen de ella)
	var eye_task := WorkerThreadPool.add_group_task(_bake_eye.bind(eyes), eyes.size(), EYE_THREADS) if not eyes.is_empty() else -1
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
	for i in colors.size():  # 9.8b: el RGB, blanco salvo en la boca (el verde de los datos es 0 en su bolsa)
		var light := lerpf(MOUTH_DARK, 1.0, colors[i].g)
		colors[i] = Color(light, light, light, colors[i].r)
	arrays[Mesh.ARRAY_COLOR] = colors
	if eye_task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(eye_task)
	_sink_eyes(eyes, arrays)


## AC.6b: hunde la bolsa del cuerpo detrás de cada ojo, después de las normales del estilo (que así no cambian).
static func _sink_eyes(eyes: Array, body_arrays: Array) -> void:
	var body_vertices: PackedVector3Array = body_arrays[Mesh.ARRAY_VERTEX]
	for entry: Dictionary in eyes:
		if entry.has("sink"):
			var normal: Vector3 = (entry["normal"] as Vector3)
			for v: int in entry["sink"]:
				body_vertices[v] -= normal * EYE_SINK
	body_arrays[Mesh.ARRAY_VERTEX] = body_vertices


## AC.6b: la textura de una malla del ojo (una tarea de WorkerThreadPool por malla) y sus UV de 0 a 1.
static func _bake_eye(index: int, eyes: Array) -> void:
	var entry: Dictionary = eyes[index]
	var arrays: Array = entry["arrays"]
	var baked: Dictionary
	if entry["is_eye"]:
		var heights := PackedFloat32Array()
		for h: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
			heights.append(h.x)
		baked = EyeTexture.bake_eye(arrays[Mesh.ARRAY_TEX_UV], heights, arrays[Mesh.ARRAY_INDEX], entry["values"])
	else:
		baked = EyeTexture.bake_line(arrays[Mesh.ARRAY_TEX_UV], entry["values"])
	arrays[Mesh.ARRAY_TEX_UV] = baked["uv"]
	arrays[Mesh.ARRAY_TEX_UV2] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	entry["image"] = baked["image"]


## finish: hilo principal. Crea la malla y el material; devuelve el personaje (null si no se pudo).
static func finish(job: Dictionary) -> Node3D:
	var character: Node3D = job["character"]
	if character != null:
		var exported := character.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mesh := MeshBaker.with_morphs(job["arrays"], job["morphs"])  # paso 9.7.3: con las expresiones
		mesh.surface_set_material(0, _material(job))
		exported.mesh = mesh
		for entry: Dictionary in job["eyes"]:  # AC.6b
			var eye := character.find_child(entry["name"], true, false) as MeshInstance3D
			var eye_mesh := MeshBaker.with_morphs(entry["arrays"], entry["morphs"])
			eye_mesh.surface_set_material(0, _eye_material(entry))
			eye.mesh = eye_mesh
	return character


## AC.6b: ojo opaco con su textura; línea con alfa y por las dos caras (como eye_line.gdshader).
static func _eye_material(entry: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = String(entry["name"])
	material.metallic = 0.0
	material.roughness = 1.0
	material.albedo_texture = ImageTexture.create_from_image(entry["image"])
	if not entry["is_eye"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


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
## colors: {nombre: color}, leído en start. skip (AC.6b): nombres de las mallas del ojo, que llevan su textura (finish).
## textures (13.3h-c): {nombre: Texture2D}, leído en start; el color la tiñe.
static func _color_pieces(character: Node3D, colors: Dictionary, skip: Array = [], textures: Dictionary = {}) -> void:
	for exported: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false).slice(1):
		if exported.name in skip:
			continue
		var material := StandardMaterial3D.new()
		material.resource_name = String(exported.name).to_lower()
		material.metallic = 0.0
		material.roughness = 1.0
		material.albedo_color = colors.get(exported.name, Color.WHITE)
		material.albedo_texture = textures.get(exported.name)
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
