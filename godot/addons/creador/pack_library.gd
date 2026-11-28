class_name PackLibrary
extends RefCounted
## Paso 11.1 (= AB.2): biblioteca de piezas. Un pack es una carpeta con pack.json y sus .glb (ruta/ARQUITECTURA.md §6):
## los de serie en res://packs/<id>/ y los del usuario en user://packs/<id>/. Sin interfaz.
## - Un pack sin licencia permitida (LICENSES) o con algo mal se RECHAZA entero, y scan() dice por qué.
## - Un id de pack repetido: gana el primero que se lee (las carpetas, en el orden que se pasan).
## - Las piezas se abren con GLTFDocument, como cuerpo.glb; sus .glb van con importer="keep" (viajan tal cual en el .pck).
## - Paso AB.9a: una pieza con «derivada»: {"mascara", "separacion"} no tiene archivo: la hace BodyDerived con caras
##   del cuerpo (load_piece da null; quien la pone llama a BodyDerived.build).
## - Paso 12.1b: una pieza con «oculta»: {"archivo", "sha256"} (opcional) trae un PNG RGBA sobre las UV del cuerpo con la
##   piel que tapa (A = oculta); lo da hide_image y lo une SkinHide.
## Uso:
##   var library := PackLibrary.new()
##   var warnings := library.scan(PackedStringArray(["res://packs", "user://packs"]))
##   for piece in library.pieces("ropa", "humana"): …   # fichas, con "pack", "autor" y "licencia" añadidos
##   var node := library.load_piece("base", "tights")    # null si falta o si el sha256 no coincide

const FORMAT := "gamemolde-pack"
const VERSION := 1
const LICENSES := ["CC0-1.0", "propia"]  # CC-BY solo si se aprueba D19
const TYPES := ["pelo", "ropa", "accesorio", "ojos", "cejas"]
const SLOTS := ["pelo", "cejas", "ojos", "ropa_interior", "ropa_torso", "ropa_piernas", "ropa_pies", "ropa_exterior",
	"accesorio"]
const MULTI_SLOT := "accesorio"  # la única ranura que admite varias piezas a la vez

var packs := {}  # id → {"carpeta": String, "datos": Dictionary}


## Vuelve a leer los packs de las carpetas. Devuelve los avisos (pack rechazado y por qué).
func scan(folders: PackedStringArray) -> Array[String]:
	packs.clear()
	var warnings: Array[String] = []
	for root: String in folders:
		if not DirAccess.dir_exists_absolute(root):
			continue
		for name: String in DirAccess.get_directories_at(root):
			var folder := root.path_join(name)
			var error := _add(folder)
			if error != "":
				warnings.append("pack %s: %s" % [folder, error])
	return warnings


## Fichas de las piezas (copias), del tipo y la especie pedidos ("" = todas), con el pack, el autor y la licencia.
func pieces(type := "", species := "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for pack_id: String in packs:
		var data: Dictionary = packs[pack_id]["datos"]
		for piece: Dictionary in data["piezas"]:
			if (type == "" or piece["tipo"] == type) and (species == "" or species in piece["especies"]):
				var card := piece.duplicate(true)
				card["pack"] = pack_id
				card["autor"] = data["autor"]
				card["licencia"] = data["licencia"]
				found.append(card)
	return found


## La ficha de una pieza (copia), o {} si no está.
func piece(pack_id: String, piece_id: String) -> Dictionary:
	if not packs.has(pack_id):
		return {}
	for item: Dictionary in packs[pack_id]["datos"]["piezas"]:
		if item["id"] == piece_id:
			return item.duplicate(true)
	return {}


## La escena de la pieza, o null si falta, si no se puede abrir o si su sha256 no coincide con la ficha.
func load_piece(pack_id: String, piece_id: String) -> Node3D:
	var path := piece_file(pack_id, piece_id)
	if path == "":
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D


## La ruta del archivo de la pieza, o "" si no tiene, si falta o si su sha256 no coincide con la ficha.
func piece_file(pack_id: String, piece_id: String) -> String:
	var card := piece(pack_id, piece_id)
	if card.is_empty() or card["archivo"] == "":
		return ""
	var path: String = (packs[pack_id]["carpeta"] as String).path_join(card["archivo"])
	if not FileAccess.file_exists(path) or (card["sha256"] != "" and FileAccess.get_sha256(path) != card["sha256"]):
		return ""
	return path


## Paso 12.1b: la máscara de piel oculta de la pieza (RGBA8), o null si no tiene, si falta o si su sha256 no coincide.
func hide_image(pack_id: String, piece_id: String) -> Image:
	var card := piece(pack_id, piece_id)
	if card.get("oculta") == null:  # no está la pieza o no trae máscara
		return null
	var path: String = (packs[pack_id]["carpeta"] as String).path_join(card["oculta"]["archivo"])
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != card["oculta"]["sha256"]:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _add(folder: String) -> String:
	var path := folder.path_join("pack.json")
	if not FileAccess.file_exists(path):
		return "no tiene pack.json"
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return "pack.json no es un objeto JSON válido"
	var data: Dictionary = json.data
	if data.get("formato") != FORMAT:
		return "no es un pack de GameMolde (falta \"formato\": \"%s\")" % FORMAT
	if not _is_number(data.get("version")) or data["version"] < 1 or data["version"] > VERSION:
		return "versión de pack no válida o más nueva que este programa (lee hasta la %d)" % VERSION
	for field: String in ["id", "nombre", "autor", "licencia"]:
		if typeof(data.get(field)) != TYPE_STRING or data[field] == "":
			return "falta '%s'" % field
	if not data["licencia"] in LICENSES:
		return "licencia «%s» no permitida (solo %s)" % [data["licencia"], ", ".join(LICENSES)]
	if packs.has(data["id"]):
		return "el id «%s» ya está en otro pack" % data["id"]
	if typeof(data.get("piezas")) != TYPE_ARRAY or data["piezas"].is_empty():
		return "no tiene piezas"
	var ids := {}
	for item: Variant in data["piezas"]:
		var error := _check_piece(item, folder, ids)
		if error != "":
			return error
	data["origen"] = data.get("origen", "")
	packs[data["id"]] = {"carpeta": folder, "datos": data}
	return ""


## Comprueba una ficha de pieza y le pone los valores por defecto de lo que falte.
func _check_piece(item: Variant, folder: String, ids: Dictionary) -> String:
	if typeof(item) != TYPE_DICTIONARY:
		return "una pieza no es un objeto"
	var card: Dictionary = item
	var id: Variant = card.get("id")
	if typeof(id) != TYPE_STRING or id == "" or ids.has(id):
		return "una pieza no tiene id, o está repetido"
	ids[id] = true
	if not card.get("tipo") in TYPES or not card.get("ranura") in SLOTS:
		return "pieza %s: tipo o ranura desconocidos" % id
	var generator: Variant = card.get("generador")  # paso AB.11: accesorio rígido hecho por un generador (RigidPiece)
	if generator != null and (typeof(generator) != TYPE_DICTIONARY or typeof(generator.get("tipo")) != TYPE_STRING):
		return "pieza %s: «generador» no es válido" % id
	var cut: Variant = card.get("corte")  # paso AB.5: prenda recortada de otra pieza del mismo pack (GarmentCut)
	if cut != null and (typeof(cut) != TYPE_DICTIONARY or typeof(cut.get("de")) != TYPE_STRING):
		return "pieza %s: «corte» no es válido" % id
	var derived: Variant = card.get("derivada")
	if derived != null and (typeof(derived) != TYPE_DICTIONARY or typeof(derived.get("mascara")) != TYPE_STRING
			or not _is_number(derived.get("separacion"))):
		return "pieza %s: «derivada» no es válida" % id
	if derived == null and generator == null and cut == null and (typeof(card.get("archivo")) != TYPE_STRING
			or not FileAccess.file_exists(folder.path_join(card["archivo"]))):
		return "pieza %s: falta su archivo" % id
	var hide: Variant = card.get("oculta")  # paso 12.1b: máscara de piel oculta (SkinHide)
	if hide != null and (typeof(hide) != TYPE_DICTIONARY or typeof(hide.get("archivo")) != TYPE_STRING
			or typeof(hide.get("sha256")) != TYPE_STRING or not FileAccess.file_exists(folder.path_join(hide["archivo"]))):
		return "pieza %s: «oculta» no es válida o falta su archivo" % id
	var covers: Variant = card.get("cubre", [])  # paso RE.1a: otras ranuras que esta pieza ocupa (un traje: ropa_piernas)
	if typeof(covers) != TYPE_ARRAY or covers.any(func(slot: Variant) -> bool: return not slot in SLOTS):
		return "pieza %s: «cubre» no es una lista de ranuras" % id
	card["cubre"] = covers
	card["archivo"] = card.get("archivo", "")
	if typeof(card.get("especies", [])) != TYPE_ARRAY or typeof(card.get("colores", [])) != TYPE_ARRAY \
			or typeof(card.get("fisica", [])) != TYPE_ARRAY:
		return "pieza %s: «especies», «colores» o «fisica» no son listas" % id
	var anchor: Variant = card.get("anclaje", {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]})
	if typeof(anchor) != TYPE_DICTIONARY or typeof(anchor.get("hueso", "")) != TYPE_STRING \
			or not _is_numbers(anchor.get("transform", [0, 0, 0, 0, 0, 0, 1, 1]), 8):
		return "pieza %s: «anclaje» no es válido" % id
	card["nombre"] = card.get("nombre", id)
	card["especies"] = card.get("especies", [])
	card["sha256"] = card.get("sha256", "")
	card["miniatura"] = card.get("miniatura", "")
	card["anclaje"] = {"hueso": anchor.get("hueso", ""), "transform": anchor.get("transform", [0, 0, 0, 0, 0, 0, 1, 1])}
	card["sigue_al_cuerpo"] = card.get("sigue_al_cuerpo", false) == true
	card["fisica"] = card.get("fisica", [])
	card["colores"] = card.get("colores", [])
	if not _is_numbers(card.get("color", [0.8, 0.8, 0.8]), 3):
		return "pieza %s: «color» no son 3 números" % id
	card["color"] = card.get("color", [0.8, 0.8, 0.8])  # color de partida (RGB de 0 a 1)
	return ""


## Paso RE.1a: ¿no pueden llevarse a la vez? Misma ranura (salvo accesorios), o una cubre la ranura de la otra
## (un traje completo y unos shorts). Una camiseta y unos shorts sí.
static func conflicts(a: Dictionary, b: Dictionary) -> bool:
	if a["ranura"] == MULTI_SLOT or b["ranura"] == MULTI_SLOT:
		return false
	return a["ranura"] == b["ranura"] or a["ranura"] in b.get("cubre", []) or b["ranura"] in a.get("cubre", [])


## Color de partida de una ficha.
static func color_of(card: Dictionary) -> Color:
	return to_color(card.get("color", [0.8, 0.8, 0.8]))


## [r, g, b] (de pack.json o del proyecto) como Color.
static func to_color(values: Array) -> Color:
	return Color(values[0], values[1], values[2])


static func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(value)


static func _is_numbers(value: Variant, count: int) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != count:
		return false
	for item: Variant in value:
		if not _is_number(item):
			return false
	return true
