class_name ProjectFile
extends RefCounted
## Proyecto de GameMolde (.gmolde): uno o más personajes con sus piezas y poses, y una escena (paso 10.1).
## Formato y motivos: ruta/ARQUITECTURA.md §1. No decide carpetas ni nombres de archivo. No carga packs ni mallas.
##
## Uso:
##   var project := ProjectFile.new_project("Heroína", preset_dict)     # preset_dict: lo que da Preset.to_dict
##   var text := ProjectFile.to_text(project)                           # mismo proyecto, mismo texto
##   var loaded := ProjectFile.from_text(text)                          # {error, proyecto, avisos}
##   if loaded["error"]: push_error(loaded["error"])
## - El preset de cada personaje se guarda tal cual: lo valida y lo migra Preset (from_dict), no este archivo.
##   Aquí solo se exige que sea un objeto con "version" y "especie".
## - Lo que falta toma su valor por defecto. Las claves desconocidas SE CONSERVAN y salen en "avisos"
##   (así una pieza o un bloque de una versión intermedia no se pierde al guardar).
## - Un proyecto de una versión MAYOR se rechaza (D18). Uno de una versión menor pasa por migrate().
## - Números a 6 decimales; los enteros se escriben sin decimales (JSON lee todo como float: 2 y 2.0 son lo mismo).
##
## Cómo subir de versión (cuando haga falta cambiar el formato de forma incompatible):
##   1. VERSION += 1.   2. Escribir `static func _v1_to_v2(data: Dictionary) -> String` (devuelve "" o el error).
##   3. Añadir su línea en _step().   4. NO regenerar pruebas/godot/datos/proyecto_v1.gmolde: debe seguir abriéndose.

const FORMAT := "gamemolde-proyecto"
const VERSION := 1
const DECIMALS := 0.000001
const MAX_TEXT := 5 * 1024 * 1024  # un proyecto es texto pequeño; por encima de esto no se intenta leer
const MAX_THUMBNAIL := 400 * 1024  # caracteres de base64 (PNG de 256 px)
const MAX_CHARACTERS := 8
const FIELDS := ["formato", "version", "programa", "nombre", "miniatura", "personajes", "escena"]
const CHARACTER_FIELDS := ["id", "preset", "piezas", "pose", "capas", "posicion", "giro_y"]
const PIECE_FIELDS := ["pack", "pieza", "sha256", "ranura", "hueso", "transform", "colores", "parametros"]
const SCENE_FIELDS := ["fondo", "luces", "camaras", "camara_activa"]
const LIGHT_TYPES := ["direccional", "omni", "foco"]
const BACKGROUND_TYPES := ["color", "degradado"]
const NO_TRANSFORM := [0, 0, 0, 0, 0, 0, 1, 1]  # posición (3), giro como cuaternión (4) y escala uniforme (1)


## Proyecto nuevo con un personaje y la escena por defecto.
static func new_project(project_name: String, preset: Dictionary, program_version := "") -> Dictionary:
	return {"formato": FORMAT, "version": VERSION, "programa": program_version, "nombre": project_name, "miniatura": "",
		"personajes": [new_character("p1", preset)], "escena": default_scene()}


static func new_character(id: String, preset: Dictionary) -> Dictionary:
	return {"id": id, "preset": preset.duplicate(true), "piezas": [], "pose": {"huesos": {}, "cadera": [0, 0, 0]},
		"capas": {}, "posicion": [0, 0, 0], "giro_y": 0}


## Una luz direccional blanca, una cámara de frente y fondo gris (los valores de body_view.gd y orbit_camera.gd).
static func default_scene() -> Dictionary:
	return {
		"fondo": {"tipo": "color", "color": [0.32, 0.33, 0.36], "transparente": false},
		"luces": [{"tipo": "direccional", "color": [1, 1, 1], "energia": 1, "giro": [-40, 30], "animacion": null}],
		"camaras": [{"nombre": "Frente", "objetivo": [0, 1, 0], "giro": [0, 10], "distancia": 3.2, "fov": 35, "ortografica": false}],
		"camara_activa": 0,
	}


## Texto JSON con las claves ordenadas y los números redondeados: el mismo proyecto da siempre el mismo texto.
static func to_text(project: Dictionary) -> String:
	return JSON.stringify(_rounded(project), "\t", true)


## {error: String, proyecto: Dictionary, avisos: Array[String]}. Con error, proyecto es {}.
static func from_text(text: String) -> Dictionary:
	if text.length() > MAX_TEXT:
		return _fail("el archivo es demasiado grande para ser un proyecto")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("JSON no válido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("el proyecto no es un objeto")
	return from_dict(json.data)


static func from_dict(source: Dictionary) -> Dictionary:
	var migrated := migrate(source)
	if migrated["error"]:
		return _fail(migrated["error"])
	var data: Dictionary = migrated["data"]
	var warnings: Array[String] = []
	_warn_unknown(data, FIELDS, "el proyecto", warnings)
	for field: String in ["programa", "nombre", "miniatura"]:
		if typeof(data.get(field, "")) != TYPE_STRING:
			return _fail("'%s' no es un texto" % field)
		data[field] = data.get(field, "")
	if (data["miniatura"] as String).length() > MAX_THUMBNAIL:
		data["miniatura"] = ""
		warnings.append("la miniatura era demasiado grande y se ha quitado")
	if typeof(data.get("personajes")) != TYPE_ARRAY or data["personajes"].is_empty():
		return _fail("el proyecto no tiene personajes")
	if data["personajes"].size() > MAX_CHARACTERS:
		return _fail("el proyecto tiene más de %d personajes" % MAX_CHARACTERS)
	var ids := {}
	for i in data["personajes"].size():
		var error := _check_character(data["personajes"], i, ids, warnings)
		if error:
			return _fail("personaje %d: %s" % [i + 1, error])
	if not data.has("escena"):
		data["escena"] = default_scene()
	var scene_error := _check_scene(data, warnings)
	if scene_error:
		return _fail("escena: " + scene_error)
	return {"error": "", "proyecto": _rounded(data), "avisos": warnings}


## Lleva los datos a la versión actual. {error: String, data: Dictionary}. No cambia el diccionario que recibe.
static func migrate(source: Dictionary) -> Dictionary:
	if typeof(source.get("formato")) != TYPE_STRING or source["formato"] != FORMAT:
		return {"error": "no es un proyecto de GameMolde (falta \"formato\": \"%s\")" % FORMAT, "data": {}}
	var version: Variant = source.get("version")
	if not _is_number(version) or version < 1 or version != floorf(version):
		return {"error": "versión de proyecto no válida", "data": {}}
	if version > VERSION:
		return {"error": "este proyecto es de una versión más nueva (%d); actualiza el programa (lee hasta la %d)"
			% [version, VERSION], "data": {}}
	var data := source.duplicate(true)
	for from_version in range(int(version), VERSION):
		var error := _step(from_version, data)
		if error:
			return {"error": "al pasar de la versión %d a la %d: %s" % [from_version, from_version + 1, error], "data": {}}
	data["version"] = VERSION
	return {"error": "", "data": data}


## Un salto de versión. Cada versión nueva añade aquí su línea.
static func _step(from_version: int, _data: Dictionary) -> String:
	match from_version:
		# 1: return _v1_to_v2(_data)
		_:
			return "no hay migración desde la versión %d" % from_version


static func _check_character(characters: Array, index: int, ids: Dictionary, warnings: Array[String]) -> String:
	if typeof(characters[index]) != TYPE_DICTIONARY:
		return "no es un objeto"
	var character: Dictionary = characters[index]
	_warn_unknown(character, CHARACTER_FIELDS, "el personaje %d" % (index + 1), warnings)
	var id: Variant = character.get("id", "p%d" % (index + 1))
	if typeof(id) != TYPE_STRING or id == "" or ids.has(id):
		return "\"id\" vacío o repetido"
	ids[id] = true
	character["id"] = id
	var preset: Variant = character.get("preset")
	if typeof(preset) != TYPE_DICTIONARY or not _is_number(preset.get("version")) or typeof(preset.get("especie")) != TYPE_STRING:
		return "falta el preset, o no tiene \"version\" y \"especie\""
	if typeof(character.get("piezas", [])) != TYPE_ARRAY:
		return "\"piezas\" no es una lista"
	character["piezas"] = character.get("piezas", [])
	for n in character["piezas"].size():
		var error := _check_piece(character["piezas"], n, warnings)
		if error:
			return "pieza %d: %s" % [n + 1, error]
	var pose: Variant = character.get("pose", {})
	if typeof(pose) != TYPE_DICTIONARY or typeof(pose.get("huesos", {})) != TYPE_DICTIONARY:
		return "\"pose\" no es válida"
	var bones: Dictionary = pose.get("huesos", {})
	for bone: Variant in bones:
		if typeof(bone) != TYPE_STRING or not _is_numbers(bones[bone], 4):
			return "pose: el giro de '%s' no es [x, y, z, w]" % bone
	if not _is_numbers(pose.get("cadera", [0, 0, 0]), 3):
		return "pose: \"cadera\" no es [x, y, z]"
	character["pose"] = {"huesos": bones, "cadera": pose.get("cadera", [0, 0, 0])}
	if typeof(character.get("capas", {})) != TYPE_DICTIONARY:
		return "\"capas\" no es un objeto"
	character["capas"] = character.get("capas", {})
	if not _is_numbers(character.get("posicion", [0, 0, 0]), 3) or not _is_number(character.get("giro_y", 0)):
		return "\"posicion\" o \"giro_y\" no son números"
	character["posicion"] = character.get("posicion", [0, 0, 0])
	character["giro_y"] = character.get("giro_y", 0)
	return ""


static func _check_piece(pieces: Array, index: int, warnings: Array[String]) -> String:
	if typeof(pieces[index]) != TYPE_DICTIONARY:
		return "no es un objeto"
	var piece: Dictionary = pieces[index]
	_warn_unknown(piece, PIECE_FIELDS, "la pieza %d" % (index + 1), warnings)
	for field: String in ["pack", "pieza", "hueso"]:
		if typeof(piece.get(field)) != TYPE_STRING or piece[field] == "":
			return "falta '%s'" % field
	for field: String in ["sha256", "ranura"]:
		if typeof(piece.get(field, "")) != TYPE_STRING:
			return "'%s' no es un texto" % field
		piece[field] = piece.get(field, "")
	if not _is_numbers(piece.get("transform", NO_TRANSFORM), 8):
		return "\"transform\" no son 8 números"
	piece["transform"] = piece.get("transform", NO_TRANSFORM.duplicate())
	for field: String in ["colores", "parametros"]:
		if typeof(piece.get(field, {})) != TYPE_DICTIONARY:
			return "'%s' no es un objeto" % field
		piece[field] = piece.get(field, {})
	return ""


static func _check_scene(data: Dictionary, warnings: Array[String]) -> String:
	if typeof(data["escena"]) != TYPE_DICTIONARY:
		return "no es un objeto"
	var scene: Dictionary = data["escena"]
	var defaults := default_scene()
	_warn_unknown(scene, SCENE_FIELDS, "la escena", warnings)
	for field: String in SCENE_FIELDS:
		if not scene.has(field):
			scene[field] = defaults[field]
	var background: Variant = scene["fondo"]
	if typeof(background) != TYPE_DICTIONARY or not background.get("tipo") in BACKGROUND_TYPES \
			or not _is_numbers(background.get("color"), 3) or typeof(background.get("transparente", false)) != TYPE_BOOL:
		return "\"fondo\" no es válido"
	background["transparente"] = background.get("transparente", false)
	if typeof(scene["luces"]) != TYPE_ARRAY:
		return "\"luces\" no es una lista"
	for light: Variant in scene["luces"]:
		if typeof(light) != TYPE_DICTIONARY or not light.get("tipo") in LIGHT_TYPES or not _is_numbers(light.get("color"), 3) \
				or not _is_number(light.get("energia")):
			return "una luz no es válida (hacen falta \"tipo\", \"color\" y \"energia\")"
	if typeof(scene["camaras"]) != TYPE_ARRAY or scene["camaras"].is_empty():
		return "no hay ninguna cámara"
	for camera: Variant in scene["camaras"]:
		if typeof(camera) != TYPE_DICTIONARY or not _is_numbers(camera.get("objetivo"), 3) or not _is_numbers(camera.get("giro"), 2) \
				or not _is_number(camera.get("distancia")) or camera["distancia"] <= 0.0:
			return "una cámara no es válida (hacen falta \"objetivo\", \"giro\" y \"distancia\" > 0)"
	var active: Variant = scene["camara_activa"]
	if not _is_number(active) or active < 0 or active >= scene["camaras"].size() or active != floorf(active):
		scene["camara_activa"] = 0
		warnings.append("la cámara activa no existía; se usa la primera")
	return ""


static func _warn_unknown(data: Dictionary, known: Array, where: String, warnings: Array[String]) -> void:
	for key: Variant in data:
		if not key in known:
			warnings.append("%s tiene un campo que este programa no conoce: '%s' (se conserva)" % [where, key])


## Copia con los números a 6 decimales; los que no tienen decimales, como enteros.
static func _rounded(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			var number := snappedf(float(value), DECIMALS)
			return int(number) if number == floorf(number) and absf(number) < 1e15 else number
		TYPE_DICTIONARY:
			var copy := {}
			for key: Variant in value:
				copy[key] = _rounded(value[key])
			return copy
		TYPE_ARRAY:
			var list := []
			for item: Variant in value:
				list.append(_rounded(item))
			return list
	return value


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value)


static func _is_numbers(value: Variant, count: int) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != count:
		return false
	for item: Variant in value:
		if not _is_number(item):
			return false
	return true


static func _fail(message: String) -> Dictionary:
	return {"error": message, "proyecto": {}, "avisos": []}
