extends RefCounted
## TA.5a: biblioteca local del Taller. Cada pieza es un pack de una sola pieza en user://packs/taller_<id>/.
## Escribe en una carpeta temporal, comprueba lo escrito y solo entonces sustituye. Un cierre a medias se recupera solo.
## Sin interfaz. Formato y decisiones: ruta/pasos/ta.5_biblioteca_local.md.
## Uso: var store := AssetStore.new()
##   store.save({"nombre": "Espada", "receta": receta, "malla": malla, "miniatura": null})  # {error, id} o {error}
##   store.list()  # {piezas: [ficha...], avisos: [texto...]}
##   store.open("taller_espada")  # {error, id, nombre, receta, malla, contorno, ajustes, imagen, avisos} o {error}

const Library := preload("../pack_library.gd")
const Recipe := preload("asset_recipe.gd")
const ImageMask := preload("image_mask.gd")
const ImageSource := preload("image_source.gd")
const SwordGenerator := preload("sword_generator.gd")
const SilhouetteMesh := preload("silhouette_mesh.gd")

const PREFIX := "taller_"
const ID_ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789_"
const PIECE_ID := "pieza"
const PACK_FILE := "pack.json"
const GLB_FILE := "pieza.glb"
const THUMB_FILE := "pieza.png"
const EDIT_FILE := "edicion.json"
const EDIT_FORMAT := "gamemolde-asset-edicion"
const SWORD_MODE := "espada_parametrica"
const IMAGE_MODE := "extrusion_imagen"
const MAX_NAME := 40  # aprobado en TA.5
const MAX_EDIT_BYTES := 1024 * 1024  # aprobado en TA.5: un contorno de 1000 puntos ocupa unos 15 KB

var packs_folder: String
var temp_folder: String


func _init(packs := "user://packs", temp := "user://taller_temporal") -> void:
	packs_folder = ProjectSettings.globalize_path(packs)
	temp_folder = ProjectSettings.globalize_path(temp)


## Las piezas legibles, por nombre, y un aviso por cada una dañada. Las demás no se ven afectadas.
func list() -> Dictionary:
	_recover()
	var cards: Array[Dictionary] = []
	var notes := PackedStringArray()
	for id: String in _own_ids():
		var read := _read_piece(packs_folder.path_join(id), id)
		if read.error != "":
			notes.append("La pieza «%s» está dañada: %s." % [id, read.error])
			continue
		if not read.glb_ok:
			notes.append("«%s»: su archivo .glb falta o ha cambiado. Ábrela y guárdala para rehacerlo." % read.nombre)
		cards.append(_card(id, read))
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.nombre.naturalnocasecmp_to(b.nombre) < 0)
	return {"piezas": cards, "avisos": notes}


## Guarda una pieza nueva o, con "reemplaza", actualiza esa. Si algo falla, lo que había sigue intacto.
func save(entry: Dictionary) -> Dictionary:
	_recover()
	var data := _prepare(entry)
	if data.error != "":
		return {"error": data.error}
	var id: String = data.reemplaza if data.reemplaza != "" else _new_id(data.nombre)
	data.receta.id = id
	var work := temp_folder.path_join("nuevas").path_join(id)
	_remove_temp(work)
	var problem := _write_piece(work, id, data)
	if problem == "":
		problem = _verify(work, id, data.malla)
	if problem == "":
		problem = _swap(work, id)
	_remove_temp(work)
	return {"error": "", "id": id} if problem == "" else {"error": problem}


## Abre una pieza y regenera su malla. Si falta su imagen de origen, avisa y la pieza sigue abierta.
func open(id: String) -> Dictionary:
	_recover()
	if not _is_valid_id(id) or not DirAccess.dir_exists_absolute(packs_folder.path_join(id)):
		return {"error": "La pieza no existe."}
	var folder := packs_folder.path_join(id)
	var read := _read_piece(folder, id)
	if read.error != "":
		return {"error": "La pieza está dañada: %s." % read.error}
	var built := _build(read.receta, read.contorno)
	if built.error != "":
		return {"error": "No se pudo rehacer la pieza: " + built.error}
	var notes := PackedStringArray()
	if not read.glb_ok:
		notes.append("Su archivo .glb falta o ha cambiado: guarda la pieza para rehacerlo.")
	var image: Image = null
	if read.receta.modo == IMAGE_MODE:
		var source := _read_source(folder, read.receta)
		image = source.get("imagen")
		if source.has("aviso"):
			notes.append(source.aviso)
	return {"error": "", "id": id, "nombre": read.nombre, "receta": read.receta, "malla": built.malla,
		"contorno": read.contorno, "ajustes": read.ajustes, "imagen": image, "avisos": notes}


func _card(id: String, read: Dictionary) -> Dictionary:
	var thumb := packs_folder.path_join(id).path_join(THUMB_FILE)
	return {"id": id, "nombre": read.nombre, "modo": read.receta.modo, "autor": read.receta.autor,
		"licencia": read.receta.licencia, "miniatura": thumb if FileAccess.file_exists(thumb) else ""}


## Solo carpetas taller_* que son de verdad piezas del Taller: nunca se toca otro pack.
func _own_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if DirAccess.dir_exists_absolute(packs_folder):
		for folder: String in DirAccess.get_directories_at(packs_folder):
			if _is_own(folder):
				ids.append(folder)
	return ids


func _is_own(id: String) -> bool:
	if not _is_valid_id(id):
		return false
	var folder := packs_folder.path_join(id)
	if FileAccess.file_exists(folder.path_join(EDIT_FILE)):
		return true
	var pack: Variant = _read_json(folder.path_join(PACK_FILE))
	if not pack is Dictionary or not pack.get("piezas") is Array or pack.piezas.size() != 1:
		return false
	return pack.piezas[0] is Dictionary and pack.piezas[0].has("edicion_sha256")


static func _is_valid_id(id: String) -> bool:
	if not id.begins_with(PREFIX) or id.length() <= PREFIX.length():
		return false
	for ch in id:
		if not ID_ALPHABET.contains(ch):
			return false
	return true


## Comprueba la entrada y rehace la malla: lo guardado es siempre lo que la receta produce.
func _prepare(entry: Dictionary) -> Dictionary:
	var name_value: Variant = entry.get("nombre")
	var problem := _name_error(name_value)
	if problem != "":
		return {"error": problem}
	var title: String = name_value.strip_edges()
	var replaced: Variant = entry.get("reemplaza", "")
	if not replaced is String or (replaced != "" and not (_is_own(replaced)
			and DirAccess.dir_exists_absolute(packs_folder.path_join(replaced)))):
		return {"error": "La pieza que se quiere actualizar no existe."}
	if _name_taken(title, replaced):
		return {"error": "Ya hay una pieza llamada «%s»." % title}
	if not entry.get("receta") is Dictionary:
		return {"error": "Falta la receta de la pieza."}
	var normalized := Recipe.normalize(entry.receta)
	if normalized.error != "":
		return {"error": normalized.error}
	var data := {"error": "", "nombre": title, "reemplaza": replaced, "receta": normalized.receta,
		"contorno": PackedVector2Array(), "ajustes": {}, "fuente_bytes": PackedByteArray(), "miniatura": entry.get("miniatura")}
	if data.receta.modo == IMAGE_MODE:
		problem = _prepare_image(entry, data)
		if problem != "":
			return {"error": problem}
	var built := _build(data.receta, data.contorno)
	if built.error != "":
		return {"error": built.error}
	if not entry.get("malla") is ArrayMesh or not _same_mesh(entry.malla, built.malla):
		return {"error": "La malla no coincide con la receta."}
	data.malla = built.malla
	return data


static func _name_error(value: Variant) -> String:
	if not value is String or value.strip_edges().is_empty():
		return "Escribe un nombre para la pieza."
	var title: String = value.strip_edges()
	if title.length() > MAX_NAME:
		return "El nombre tiene más de %d caracteres." % MAX_NAME
	for i in title.length():
		if title.unicode_at(i) < 32:
			return "El nombre contiene un carácter no válido."
	return ""


func _name_taken(title: String, except: String) -> bool:
	for id: String in _own_ids():
		if id != except:
			var pack: Variant = _read_json(packs_folder.path_join(id).path_join(PACK_FILE))
			if pack is Dictionary and pack.get("nombre") is String and pack.nombre.to_lower() == title.to_lower():
				return true
	return false


func _prepare_image(entry: Dictionary, data: Dictionary) -> String:
	if not entry.get("contorno") is PackedVector2Array or not entry.get("fuente_bytes") is PackedByteArray:
		return "Faltan el contorno o la imagen de origen."
	if entry.contorno.size() < 3 or entry.contorno.size() > ImageMask.MAX_VERTICES:
		return "El contorno no tiene un número de puntos válido."
	if _sha256(entry.fuente_bytes) != data.receta.fuente.sha256.to_lower():
		return "La imagen de origen no coincide con la receta."
	var options: Variant = entry.get("ajustes", {})
	if options is not Dictionary:
		return "Ajustes del contorno no válidos."
	var settings: Dictionary = ImageMask._settings(options)
	if settings.has("error"):
		return "Ajustes del contorno no válidos: " + settings.error
	data.contorno = entry.contorno
	data.fuente_bytes = entry.fuente_bytes
	data.ajustes = settings
	return ""


static func _build(recipe: Dictionary, contour: PackedVector2Array) -> Dictionary:
	if recipe.modo == SWORD_MODE:
		return SwordGenerator.generate(recipe)
	if recipe.modo == IMAGE_MODE:
		return SilhouetteMesh.generate(recipe, contour)
	return {"error": "Este tipo de pieza aún no se puede guardar."}


static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for i in a.get_surface_count():
		if a.surface_get_arrays(i) != b.surface_get_arrays(i):
			return false
		var first := a.surface_get_material(i) as StandardMaterial3D
		var second := b.surface_get_material(i) as StandardMaterial3D
		if first == null or second == null or first.albedo_color != second.albedo_color:
			return false
	return true


## Un id libre a partir del nombre, con número si ya existe.
func _new_id(title: String) -> String:
	var slug := ""
	for ch in title.to_lower():
		slug += ch if ID_ALPHABET.contains(ch) else "_"
	while slug.contains("__"):
		slug = slug.replace("__", "_")
	slug = slug.strip_edges().trim_prefix("_").trim_suffix("_").left(MAX_NAME).trim_suffix("_")
	if slug == "":
		slug = PIECE_ID
	var id := PREFIX + slug
	var number := 2
	while DirAccess.dir_exists_absolute(packs_folder.path_join(id)) \
			or DirAccess.dir_exists_absolute(temp_folder.path_join("viejas").path_join(id)):  # una apartada sigue siendo suya
		id = "%s%s_%d" % [PREFIX, slug, number]
		number += 1
	return id


func _write_piece(work: String, id: String, data: Dictionary) -> String:
	if DirAccess.make_dir_recursive_absolute(work) != OK:
		return "No se pudo preparar la carpeta temporal."
	var mesh: ArrayMesh = data.malla
	for i in mesh.get_surface_count():  # el .glb solo conserva el nombre de la región en su material
		mesh.surface_get_material(i).resource_name = mesh.surface_get_name(i)
	if _write_glb(mesh, work.path_join(GLB_FILE)) != OK:
		return "No se pudo escribir el .glb."
	var thumb: Variant = data.miniatura
	var has_thumb: bool = thumb is Image and not thumb.is_empty() and thumb.save_png(work.path_join(THUMB_FILE)) == OK
	if data.receta.modo == IMAGE_MODE:
		var source := work.path_join(data.receta.fuente.archivo)
		if DirAccess.make_dir_recursive_absolute(source.get_base_dir()) != OK or not _store(source, data.fuente_bytes):
			return "No se pudo copiar la imagen de origen."
	var glb_sha := FileAccess.get_sha256(work.path_join(GLB_FILE))
	var edition := JSON.stringify(_edition_data(data, glb_sha), "\t", false, true).to_utf8_buffer()
	if edition.size() > MAX_EDIT_BYTES:
		return "Los datos de edición ocupan más de 1 MB."
	if not _store(work.path_join(EDIT_FILE), edition):
		return "No se pudieron escribir los datos de edición."
	var pack_data := _pack_data(id, data.nombre, data.receta, glb_sha, THUMB_FILE if has_thumb else "",
		FileAccess.get_sha256(work.path_join(EDIT_FILE)))
	return "" if _store(work.path_join(PACK_FILE), JSON.stringify(pack_data, "\t", false).to_utf8_buffer()) \
		else "No se pudo escribir pack.json."


## edicion.json guarda también el nombre y el hash del .glb: así se detecta cualquier cambio en pack.json.
static func _edition_data(data: Dictionary, glb_sha: String) -> Dictionary:
	var edition := {"formato": EDIT_FORMAT, "version": 1, "nombre": data.nombre, "glb_sha256": glb_sha, "receta": data.receta}
	if data.receta.modo == IMAGE_MODE:
		var points := []
		for point: Vector2 in data.contorno:
			points.append([point.x, point.y])
		edition.contorno = points
		edition.ajustes = data.ajustes
	return edition


## Formato de ruta/ARQUITECTURA.md §6. Sin especies: no sale en Accesorios hasta que TA.6 sepa equiparla.
static func _pack_data(id: String, title: String, recipe: Dictionary, glb_sha: String, thumb: String,
		edit_sha: String) -> Dictionary:
	return {"formato": Library.FORMAT, "version": Library.VERSION, "id": id, "nombre": title,
		"autor": recipe.autor, "licencia": recipe.licencia, "origen": "",
		"piezas": [{"id": PIECE_ID, "nombre": title, "tipo": "accesorio", "ranura": "accesorio", "especies": [],
			"archivo": GLB_FILE, "sha256": glb_sha, "miniatura": thumb, "edicion_sha256": edit_sha}]}


static func _write_glb(mesh: ArrayMesh, path: String) -> Error:
	var holder := Node3D.new()
	holder.name = "pieza"
	var instance := MeshInstance3D.new()
	instance.name = "malla"
	instance.mesh = mesh
	holder.add_child(instance)
	instance.owner = holder
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(holder, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	holder.free()
	return error


## Relee lo escrito como lo hará el programa antes de darlo por bueno.
func _verify(work: String, id: String, mesh: ArrayMesh) -> String:
	var library := Library.new()
	library.scan(PackedStringArray([work.get_base_dir()]))
	if not library.packs.has(id):
		return "El pack escrito no es válido."
	var read := _read_piece(work, id)
	if read.error != "" or not read.glb_ok:
		return "Lo escrito no se pudo releer."
	if read.receta.modo == IMAGE_MODE and _read_source(work, read.receta).has("aviso"):
		return "La imagen de origen copiada no se pudo releer."
	var scene: Node3D = library.load_piece(id, PIECE_ID)
	if scene == null:
		return "El .glb escrito no se pudo abrir."
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	var same: bool = found.size() == 1 and found[0].mesh.get_surface_count() == mesh.get_surface_count()
	scene.free()
	return "" if same else "El .glb escrito no tiene las mismas superficies."


## Aparta la pieza vieja, mueve la nueva y borra la vieja. Si mover falla, la vieja vuelve a su sitio.
func _swap(work: String, id: String) -> String:
	var final := packs_folder.path_join(id)
	var old := temp_folder.path_join("viejas").path_join(id)
	if DirAccess.make_dir_recursive_absolute(packs_folder) != OK \
			or DirAccess.make_dir_recursive_absolute(old.get_base_dir()) != OK:
		return "No se pudo preparar la biblioteca."
	var had_old := DirAccess.dir_exists_absolute(final)
	if had_old and DirAccess.rename_absolute(final, old) != OK:
		return "No se pudo sustituir la pieza."
	if DirAccess.rename_absolute(work, final) != OK:
		if had_old:
			DirAccess.rename_absolute(old, final)
		return "No se pudo guardar la pieza."
	_remove_temp(old)
	return ""


## Tras un cierre a medias: devuelve la pieza apartada si no llegó la nueva y limpia lo temporal.
func _recover() -> void:
	var new_folder := temp_folder.path_join("nuevas")
	if DirAccess.dir_exists_absolute(new_folder):
		for name: String in DirAccess.get_directories_at(new_folder):
			_remove_temp(new_folder.path_join(name))
	var old_folder := temp_folder.path_join("viejas")
	if not DirAccess.dir_exists_absolute(old_folder):
		return
	for id: String in DirAccess.get_directories_at(old_folder):
		if not _is_valid_id(id):
			continue
		var final := packs_folder.path_join(id)
		if DirAccess.dir_exists_absolute(final):
			_remove_temp(old_folder.path_join(id))
		else:
			DirAccess.make_dir_recursive_absolute(packs_folder)
			DirAccess.rename_absolute(old_folder.path_join(id), final)


## Lee y valida una pieza sin regenerarla. Un .glb dañado no impide editarla: se rehace desde la receta.
func _read_piece(folder: String, id: String) -> Dictionary:
	var pack: Variant = _read_json(folder.path_join(PACK_FILE))
	if not pack is Dictionary:
		return {"error": "no se puede leer pack.json"}
	var card := _pack_card(pack, id)
	if card.is_empty():
		return {"error": "pack.json no es válido"}
	var edit_path := folder.path_join(EDIT_FILE)
	if not FileAccess.file_exists(edit_path) or FileAccess.get_sha256(edit_path) != card.edicion_sha256:
		return {"error": "sus datos de edición faltan o han cambiado"}
	var edition := _parse_edition(_read_json(edit_path), id)
	if edition.has("error"):
		return edition
	var expected := _pack_data(id, edition.nombre, edition.receta, edition.glb_sha256, card.miniatura, card.edicion_sha256)
	if JSON.parse_string(JSON.stringify(expected)) != pack:  # por JSON: los números vuelven como en el archivo
		return {"error": "pack.json no coincide con sus datos de edición"}
	var glb_path := folder.path_join(GLB_FILE)
	edition.error = ""
	edition.glb_ok = FileAccess.file_exists(glb_path) and FileAccess.get_sha256(glb_path) == edition.glb_sha256
	return edition


static func _pack_card(pack: Dictionary, id: String) -> Dictionary:
	if pack.get("formato") is not String or pack.formato != Library.FORMAT or pack.get("id") is not String or pack.id != id:
		return {}
	if pack.get("piezas") is not Array or pack.piezas.size() != 1 or pack.piezas[0] is not Dictionary:
		return {}
	var card: Dictionary = pack.piezas[0]
	for key: String in ["id", "archivo", "sha256", "miniatura", "edicion_sha256"]:
		if card.get(key) is not String:
			return {}
	if card.id != PIECE_ID or card.archivo != GLB_FILE or card.miniatura not in ["", THUMB_FILE]:
		return {}
	return card


static func _parse_edition(doc: Variant, id: String) -> Dictionary:
	if doc is not Dictionary or doc.get("formato") is not String or doc.formato != EDIT_FORMAT:
		return {"error": "sus datos de edición no son válidos"}
	if typeof(doc.get("version")) not in [TYPE_INT, TYPE_FLOAT] or doc.version != 1 or doc.get("receta") is not Dictionary:
		return {"error": "sus datos de edición tienen otra versión"}
	if _name_error(doc.get("nombre")) != "" or doc.get("glb_sha256") is not String:
		return {"error": "sus datos de edición no son válidos"}
	var normalized := Recipe.normalize(doc.receta)
	if normalized.error != "" or normalized.receta.id != id:
		return {"error": "su receta no es válida"}
	var result := {"nombre": doc.nombre, "glb_sha256": doc.glb_sha256, "receta": normalized.receta,
		"contorno": PackedVector2Array(), "ajustes": {}}
	if normalized.receta.modo != IMAGE_MODE:
		return result
	var contour := _parse_contour(doc.get("contorno"))
	var options: Variant = doc.get("ajustes")
	if contour.size() < 3 or options is not Dictionary:
		return {"error": "su contorno no es válido"}
	var settings: Dictionary = ImageMask._settings(options)
	if settings.has("error"):
		return {"error": "sus ajustes de contorno no son válidos"}
	result.contorno = contour
	result.ajustes = settings
	return result


static func _parse_contour(value: Variant) -> PackedVector2Array:
	var contour := PackedVector2Array()
	if value is not Array or value.size() > ImageMask.MAX_VERTICES:
		return contour
	for pair: Variant in value:
		if pair is not Array or pair.size() != 2 or typeof(pair[0]) != TYPE_FLOAT and typeof(pair[0]) != TYPE_INT \
				or typeof(pair[1]) != TYPE_FLOAT and typeof(pair[1]) != TYPE_INT:
			return PackedVector2Array()
		contour.append(Vector2(pair[0], pair[1]))
	return contour


## La imagen de origen, o un aviso si falta o no es la que se guardó.
static func _read_source(folder: String, recipe: Dictionary) -> Dictionary:
	var path := folder.path_join(recipe.fuente.archivo)
	if not FileAccess.file_exists(path):
		return {"aviso": "Falta la imagen de origen: el contorno queda bloqueado hasta elegirla de nuevo."}
	var loaded: Dictionary = ImageSource.load_png(path)
	if loaded.error != "" or loaded.sha256 != recipe.fuente.sha256.to_lower():
		return {"aviso": "La imagen de origen ha cambiado: el contorno queda bloqueado hasta elegirla de nuevo."}
	return {"imagen": loaded.imagen}


static func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_EDIT_BYTES:
		return null
	var json := JSON.new()
	return json.data if json.parse(file.get_as_text()) == OK else null


static func _store(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	var ok := file.get_error() == OK
	file.close()
	return ok


static func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## Borra una carpeta de trabajo. Nunca sale de la carpeta temporal.
func _remove_temp(path: String) -> void:
	if not path.begins_with(temp_folder + "/") or not DirAccess.dir_exists_absolute(path):
		return
	for folder: String in DirAccess.get_directories_at(path):
		_remove_temp(path.path_join(folder))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
