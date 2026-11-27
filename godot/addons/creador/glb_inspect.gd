class_name GlbInspect
extends RefCounted
## Paso 13.3b: valida y limpia un .glb ajeno antes de que Godot lo abra (D59). Solo protege contra archivos rotos o
## maliciosos (bombas de memoria): no limita triángulos ni tamaño de la pieza. Las texturas PNG o JPG se conservan (las
## de junto al .glb, solo con un nombre de archivo, van dentro de la copia limpia); una que no se puede leer se quita
## con un aviso y queda el color base. El JSON limpio es nuevo, con una lista blanca: ningún texto del archivo se usa
## como ruta ni como nombre.
## Uso:
##   var r := GlbInspect.read(path)   # {error, avisos, bytes (GLB limpio), triangulos}
##   if r["error"] == "": GLTFDocument.new().append_from_buffer(r["bytes"], "", state)

const MAX_FILE_BYTES := 256 * 1024 * 1024  # líder (D59): el archivo y también la copia limpia con sus texturas
const MAX_JSON_BYTES := 32 * 1024 * 1024  # contra bombas, no contra piezas grandes (y los de abajo)
const MAX_NODES := 16384
const MAX_ITEMS := 65536  # por lista: accessors, bufferViews, mallas, materiales, texturas, imágenes…
const MAX_PRIMITIVES := 4096  # en total
const MESH_SURFACES := 256  # por malla: límite de ArrayMesh (comprobado en Godot 4.7.2)
## Sin tope de geometría (D59, líder 2026-11-28): los bytes de geometría que leen las primitivas (sumados por malla
## definida y por nodo que la usa) no pasan de MAX_FILE_BYTES; solo los multiplica un accessor compartido o repetido.
const MAX_IMAGE_SIDE := 16384
const MAX_PIXELS := 16384 * 16384 # todas las imágenes juntas (cada una se decodifica en RGBA)
const GLB_MAGIC := 0x46546C67
const CHUNK_JSON := 0x4E4F534A
const CHUNK_BIN := 0x004E4942
const EXTENSIONS := ["KHR_materials_unlit", "KHR_texture_transform"]
const COMPRESSION := ["KHR_draco_mesh_compression", "EXT_meshopt_compression", "KHR_meshopt_compression",
	"KHR_mesh_quantization"]
const KIND_SIZE := {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
const COMPONENT_SIZE := {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
const FLOAT := 5126
const INDEX_TOP := {5121: 256, 5123: 65536}  # con menos vértices que esto hay que mirar cada índice
const ATTRIBUTES := {"POSITION": "VEC3", "NORMAL": "VEC3", "TEXCOORD_0": "VEC2", "TEXCOORD_1": "VEC2"}
const TRANSFORMS := {"matrix": 16, "translation": 3, "rotation": 4, "scale": 3}
const SAMPLER := {"magFilter": [9728, 9729], "minFilter": [9728, 9729, 9984, 9985, 9986, 9987],
	"wrapS": [33071, 33648, 10497], "wrapT": [33071, 33648, 10497]}
const PNG_SIGNATURE := [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52]
const NOTES := {
	"skins": "se quita el esqueleto: la pieza queda rígida, en su pose de enlace",
	"animations": "se quitan las animaciones",
	"cameras": "se quitan las cámaras",
	"targets": "se quitan las formas (morph targets)",
	"color": "se quita el color por vértice",
	"other": "se quitan otros datos de los vértices",
	"extensions": "se quitan extensiones de glTF que GameMolde no usa",
	"texture": "se quita una textura que no se puede leer (ha de ser PNG o JPG, dentro del .glb o junto a él): queda su color base",
}


static func read(path: String) -> Dictionary:
	var parsed := _parse(path)
	if parsed["error"] != "":
		return _result(parsed["error"])
	var bin := embed(parsed["json"], parsed["bin"], path.get_base_dir())
	var checked := check(parsed["json"], bin)
	if checked["error"] != "":
		return _result(checked["error"])
	var cleaned := clean(parsed["json"], checked["imagenes"])
	var bytes := to_glb(cleaned["json"], bin)
	if bytes.size() > MAX_FILE_BYTES:
		return _result("con sus texturas pasa de 256 MB")
	return {"error": "", "avisos": cleaned["avisos"], "bytes": bytes, "triangulos": checked["triangulos"]}


## Mete en BIN las imágenes con «uri» que están junto al .glb y les da su bufferView (cambia json). Las que no puede
## las deja como están: check las marca como malas.
static func embed(json: Dictionary, bin: PackedByteArray, dir: String) -> PackedByteArray:
	var images: Variant = json.get("images")
	var views: Variant = json.get("bufferViews", [])
	var buffers: Variant = json.get("buffers")
	if not (images is Array and views is Array and buffers is Array and buffers.size() == 1 and buffers[0] is Dictionary
			and _int(buffers[0].get("byteLength"), bin.size() + 1) >= 0):
		return bin
	var out := bin.duplicate()
	for image: Variant in images:
		var file_name: Variant = image.get("uri") if image is Dictionary else null
		var path := dir.path_join(file_name) if file_name is String and _safe_name(file_name) else ""
		var file: FileAccess = FileAccess.open(path, FileAccess.READ) if path != "" and FileAccess.file_exists(path) else null
		if file == null or file.get_length() == 0 or out.size() + 3 + file.get_length() > MAX_FILE_BYTES:
			continue
		out.resize((out.size() + 3) / 4 * 4)
		views.append({"buffer": 0, "byteOffset": out.size(), "byteLength": file.get_length()})
		out.append_array(file.get_buffer(file.get_length()))
		image.erase("uri")
		image["bufferView"] = views.size() - 1
	json["bufferViews"] = views
	if out.size() > bin.size():
		buffers[0]["byteLength"] = out.size()
	return out


## Comprueba la estructura sin tocar nada. {error, triangulos (los que se ven, por nodo), imagenes (tipo MIME de cada
## una; "" si no se puede leer)}
static func check(json: Dictionary, bin: PackedByteArray) -> Dictionary:
	var info := {"triangulos": 0, "imagenes": []}
	for step: Callable in [_check_header, _check_views, _check_accessors, _check_meshes, _check_nodes, _check_scenes,
			_check_images]:
		var error: String = step.call(json, bin, info)
		if error != "":
			return {"error": error, "triangulos": 0, "imagenes": []}
	return {"error": "", "triangulos": info["triangulos"], "imagenes": info["imagenes"]}


## JSON nuevo con la lista blanca (pide un json que haya pasado check). {json, avisos}
static func clean(json: Dictionary, image_types: Array) -> Dictionary:
	var ctx := {"avisos": {}, "usadas": {}, "texturas": {}}
	var out := {"asset": {"version": "2.0"}, "images": _clean_images(json, image_types, ctx)}
	out["textures"] = _clean_textures(json, ctx)
	if json.has("scene"):
		out["scene"] = int(json["scene"])
	out["scenes"] = json.get("scenes", []).map(func(s: Dictionary) -> Dictionary: return {"nodes": _ints(s.get("nodes", []))})
	out["nodes"] = json.get("nodes", []).map(func(n: Dictionary) -> Dictionary: return _clean_node(n, ctx))
	out["meshes"] = json.get("meshes", []).map(func(m: Dictionary) -> Dictionary: return _clean_mesh(m, ctx))
	out["materials"] = json.get("materials", []).map(func(m: Dictionary) -> Dictionary: return _clean_material(m, ctx))
	out["samplers"] = json.get("samplers", []).map(func(s: Dictionary) -> Dictionary: return _clean_sampler(s))
	out["accessors"] = json.get("accessors", []).map(func(a: Dictionary) -> Dictionary: return _clean_accessor(a))
	var view_keys := ["buffer", "byteOffset", "byteLength", "byteStride"]
	out["bufferViews"] = json.get("bufferViews", []).map(func(v: Dictionary) -> Dictionary: return _pick_ints(v, view_keys))
	out["buffers"] = [{"byteLength": int(json["buffers"][0]["byteLength"])}]
	for key: String in ["animations", "skins", "cameras"]:
		if json.has(key) and not (json[key] is Array and json[key].is_empty()):
			ctx["avisos"][key] = true
	_clean_extensions(json, out, ctx)
	var notes: Array[String] = []
	notes.assign(ctx["avisos"].keys().map(func(k: String) -> String: return NOTES[k]))
	return {"json": out, "avisos": notes}


static func to_glb(json: Dictionary, bin: PackedByteArray) -> PackedByteArray:
	var text := JSON.stringify(json, "", false, true).to_utf8_buffer()
	while text.size() % 4:
		text.append(0x20)
	var padding := (4 - bin.size() % 4) % 4
	var out := PackedInt32Array([GLB_MAGIC, 2, 28 + text.size() + bin.size() + padding, text.size(), CHUNK_JSON]).to_byte_array()
	out.append_array(text)
	out.append_array(PackedInt32Array([bin.size() + padding, CHUNK_BIN]).to_byte_array())
	out.append_array(bin)
	out.resize(out.size() + padding)
	return out


# --- Lectura ---

static func _parse(path: String) -> Dictionary:
	if path.get_extension().to_lower() != "glb":
		return _result("solo se admiten archivos .glb")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
	if file == null:
		return _result("no se puede abrir el archivo")
	var size := file.get_length()
	if size > MAX_FILE_BYTES:
		return _result("el archivo pasa de 256 MB")
	var head := file.get_buffer(20)
	if head.size() < 20 or head.decode_u32(0) != GLB_MAGIC or head.decode_u32(4) != 2:
		return _result("el archivo no es un .glb de glTF 2.0")
	var json_size := head.decode_u32(12)
	if head.decode_u32(8) != size or head.decode_u32(16) != CHUNK_JSON or json_size > MAX_JSON_BYTES or 20 + json_size > size:
		return _result("el .glb está cortado o dice longitudes falsas")
	var parser := JSON.new()
	if parser.parse(file.get_buffer(json_size).get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _result("el JSON del .glb está roto")
	var chunk := file.get_buffer(8)
	var bin_size := chunk.decode_u32(0) if chunk.size() == 8 else 0
	if chunk.size() == 8 and (chunk.decode_u32(4) != CHUNK_BIN or 28 + json_size + bin_size > size):
		return _result("el trozo BIN del .glb no es válido")
	return {"error": "", "json": parser.data, "bin": file.get_buffer(bin_size)}


static func _result(error: String) -> Dictionary:
	return {"error": error, "avisos": [] as Array[String], "bytes": PackedByteArray(), "triangulos": 0}


static func _safe_name(file_name: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z0-9_-][A-Za-z0-9_.-]{0,99}$").search(file_name) != null \
			and not ".." in file_name and file_name.get_extension().to_lower() in ["png", "jpg", "jpeg"]


# --- Comprobaciones: cada una recibe (json, bin, info) y devuelve el error o "" ---

static func _check_header(json: Dictionary, _bin: PackedByteArray, _info: Dictionary) -> String:
	var asset: Variant = json.get("asset")
	var version: Variant = asset.get("version") if asset is Dictionary else null
	var minimum: Variant = asset.get("minVersion", "2.0") if asset is Dictionary else null
	if not (version is String and version.begins_with("2.") and minimum is String and minimum == "2.0"):
		return "no es glTF 2.0"
	var required: Variant = json.get("extensionsRequired", [])
	if not required is Array:
		return "la lista extensionsRequired no es válida"
	if required.any(func(e: Variant) -> bool: return e in COMPRESSION):
		return "está comprimido: expórtalo sin compresión"
	if required.any(func(e: Variant) -> bool: return not e in EXTENSIONS):
		return "necesita una extensión de glTF que GameMolde no admite"
	return ""


static func _check_views(json: Dictionary, bin: PackedByteArray, info: Dictionary) -> String:
	var buffers: Variant = _items(json, "buffers")
	if buffers == null or buffers.size() != 1 or buffers[0].has("uri"):
		return "ha de tener un solo buffer, dentro del .glb"
	var length := _int(buffers[0].get("byteLength"), bin.size() + 1)
	var views: Variant = _items(json, "bufferViews")
	if length < 1 or views == null:
		return "el buffer no cabe en el trozo BIN"
	info["views"] = []
	for view: Dictionary in views:
		var offset := _opt(view, "byteOffset", length, 0)
		var size := _int(view.get("byteLength"), length + 1)
		var stride := _opt(view, "byteStride", 253, 0)
		if _int(view.get("buffer"), 1) != 0 or offset < 0 or size < 1 or offset + size > length or stride < 0 \
				or view.has("byteStride") and (stride < 4 or stride % 4 != 0):
			return "una vista (bufferView) se sale del buffer"
		info["views"].append([offset, offset + size, stride])
	return ""


static func _check_accessors(json: Dictionary, _bin: PackedByteArray, info: Dictionary) -> String:
	var accessors: Variant = _items(json, "accessors")
	if accessors == null:
		return "la lista accessors no es válida"
	info["accessors"] = []
	for accessor: Dictionary in accessors:
		var component := _int(accessor.get("componentType"), 5127)
		var count := _int(accessor.get("count"), MAX_FILE_BYTES + 1)
		if not COMPONENT_SIZE.has(component) or not KIND_SIZE.has(accessor.get("type")) or count < 1:
			return "un accessor no es válido"
		var element: int = COMPONENT_SIZE[component] * KIND_SIZE[accessor["type"]]
		var entry := {"component": component, "kind": accessor["type"], "count": count, "view": -1, "bytes": count * element,
			"sparse": accessor.has("sparse"), "normalized": accessor.get("normalized") is bool and accessor["normalized"]}
		var index := _opt(accessor, "bufferView", info["views"].size(), -2)
		var offset := _opt(accessor, "byteOffset", MAX_FILE_BYTES, 0)
		if count * element > MAX_FILE_BYTES or index == -1 or offset < 0:
			return "un accessor no es válido"
		if index >= 0:
			var view: Array = info["views"][index]
			entry.merge({"view": index, "start": view[0] + offset, "stride": view[2] if view[2] > 0 else element}, true)
			if entry["start"] + (count - 1) * entry["stride"] + element > view[1]:
				return "un accessor se sale de su vista"
		info["accessors"].append(entry)
	return ""


static func _check_meshes(json: Dictionary, bin: PackedByteArray, info: Dictionary) -> String:
	var meshes: Variant = _items(json, "meshes")
	var materials: Variant = _items(json, "materials")
	if meshes == null or materials == null:
		return "la lista de mallas o de materiales no es válida"
	info.merge({"max_index": {}, "materials": materials.size(), "mesh_bytes": [], "mesh_triangles": []})
	var primitives := 0
	var defined := 0
	for mesh: Dictionary in meshes:
		var list: Variant = _items(mesh, "primitives", MESH_SURFACES)
		if list == null or list.is_empty():
			return "una malla no tiene primitivas válidas (como mucho %d)" % MESH_SURFACES
		primitives += list.size()
		var counts := [0, 0]
		for primitive: Dictionary in list:
			var result: Variant = _check_primitive(primitive, bin, info)
			if result is String:
				return result
			counts = [counts[0] + result[0], counts[1] + result[1]]
		defined += counts[0]
		if primitives > MAX_PRIMITIVES or defined > MAX_FILE_BYTES:
			return "sus mallas comparten tantos datos que no caben en la memoria"
		info["mesh_bytes"].append(counts[0])
		info["mesh_triangles"].append(counts[1])
	return ""


## [bytes de geometría que lee, triángulos], o el error.
static func _check_primitive(primitive: Dictionary, bin: PackedByteArray, info: Dictionary) -> Variant:
	if _opt(primitive, "mode", 7, 4) != 4:
		return "solo se admiten triángulos"
	if _opt(primitive, "material", info["materials"], 0) < 0:
		return "una primitiva apunta a un material que no existe"
	var attributes: Variant = primitive.get("attributes")
	if not (attributes is Dictionary and attributes.has("POSITION")):
		return "una primitiva no tiene POSITION"
	var vertices: int = -1
	var bytes := 0
	for attribute: String in ATTRIBUTES:
		if not attributes.has(attribute):
			continue
		var accessor := _used(attributes[attribute], info, ATTRIBUTES[attribute])
		var ok: bool = not accessor.is_empty() and (accessor["component"] == FLOAT or attribute.begins_with("TEXCOORD")
				and accessor["component"] in [5121, 5123] and accessor["normalized"])
		if not ok or vertices >= 0 and accessor["count"] != vertices:
			return "el atributo %s no es válido" % attribute
		vertices = accessor["count"]
		bytes += accessor["bytes"]
	if not primitive.has("indices"):
		return "faltan vértices para cerrar un triángulo" if vertices % 3 else [bytes, vertices / 3]
	var index := _used(primitive["indices"], info, "SCALAR")
	if index.is_empty() or not index["component"] in [5121, 5123, 5125] or index["count"] % 3:
		return "los índices no son válidos"
	var top: Dictionary = info["max_index"]
	var key := int(primitive["indices"])
	if vertices < INDEX_TOP.get(index["component"], 1 << 33) and not top.has(key):
		top[key] = _max_index(bin, index)
	if top.get(key, 0) >= vertices:
		return "un índice apunta a un vértice que no existe"
	return [bytes + index["bytes"], index["count"] / 3]


## El accessor usado por una primitiva: con vista, sin sparse y del tipo pedido; {} si no.
static func _used(id: Variant, info: Dictionary, kind: String) -> Dictionary:
	var index := _int(id, info["accessors"].size())
	var accessor: Dictionary = info["accessors"][index] if index >= 0 else {}
	return accessor if index >= 0 and accessor["view"] >= 0 and not accessor["sparse"] and accessor["kind"] == kind else {}


static func _max_index(bin: PackedByteArray, accessor: Dictionary) -> int:
	var at: int = accessor["start"]
	var stride: int = accessor["stride"]
	var size: int = COMPONENT_SIZE[accessor["component"]]
	var top := 0
	for i: int in accessor["count"]:
		top = maxi(top, bin[at] if size == 1 else bin.decode_u16(at) if size == 2 else bin.decode_u32(at))
		at += stride
	return top


static func _check_nodes(json: Dictionary, _bin: PackedByteArray, info: Dictionary) -> String:
	var nodes: Variant = _items(json, "nodes", MAX_NODES)
	if nodes == null:
		return "tiene más de %d nodos o la lista no es válida" % MAX_NODES
	var parent := PackedInt32Array()
	parent.resize(nodes.size())
	parent.fill(-1)
	var bytes := 0
	for i: int in nodes.size():
		var node: Dictionary = nodes[i]
		if TRANSFORMS.keys().any(func(k: String) -> bool: return node.has(k) and not _numbers(node[k], TRANSFORMS[k])):
			return "un nodo tiene una transformación no válida"
		var mesh := _opt(node, "mesh", info["mesh_bytes"].size(), -2)
		if mesh == -1:
			return "un nodo apunta a una malla que no existe"
		if mesh >= 0:
			bytes += info["mesh_bytes"][mesh]
			info["triangulos"] += info["mesh_triangles"][mesh]
		if bytes > MAX_FILE_BYTES:
			return "repite tanto sus mallas que no cabe en la memoria"
		var children: Variant = node.get("children", [])
		if not children is Array:
			return "los nodos no forman un árbol"
		for child: Variant in children:
			var k := _int(child, nodes.size())
			if k < 0 or k == i or parent[k] >= 0:
				return "los nodos no forman un árbol"
			parent[k] = i
	info["parent"] = parent
	var pending: Array = range(nodes.size()).filter(func(i: int) -> bool: return parent[i] < 0)
	var reached := 0
	while not pending.is_empty():
		reached += 1
		pending.append_array(_ints(nodes[pending.pop_back()].get("children", [])))
	return "" if reached == nodes.size() else "los nodos forman un ciclo"


static func _check_scenes(json: Dictionary, _bin: PackedByteArray, info: Dictionary) -> String:
	var scenes: Variant = _items(json, "scenes")
	if scenes == null or _opt(json, "scene", scenes.size(), 0) < 0:
		return "la lista de escenas no es válida"
	var parent: PackedInt32Array = info["parent"]
	for scene: Dictionary in scenes:
		var roots: Variant = scene.get("nodes", [])
		if not roots is Array or roots.any(func(r: Variant) -> bool: return _int(r, parent.size()) < 0 or parent[int(r)] >= 0):
			return "una escena apunta a nodos que no son raíces"
	return "" if info["triangulos"] > 0 else "no tiene ninguna malla con triángulos"


## Una imagen que no se puede leer no es un error: se marca con "" y clean la quita.
static func _check_images(json: Dictionary, bin: PackedByteArray, info: Dictionary) -> String:
	var images: Variant = _items(json, "images")
	if images == null or _items(json, "textures") == null or _items(json, "samplers") == null:
		return "la lista de texturas no es válida"
	var pixels := 0
	for image: Dictionary in images:
		var index := _int(image.get("bufferView"), info["views"].size())
		var view: Array = info["views"][index] if index >= 0 else [0, 0]
		var size := _image_size(bin, view[0], view[1])
		var ok: bool = size.all(func(s: int) -> bool: return s >= 1 and s <= MAX_IMAGE_SIDE) \
				and pixels + size[0] * size[1] <= MAX_PIXELS
		pixels += size[0] * size[1] if ok else 0
		info["imagenes"].append("" if not ok else "image/png" if bin[view[0]] == 0x89 else "image/jpeg")
	return ""


## [ancho, alto] de la cabecera PNG (IHDR) o JPEG (SOFn), sin decodificar; [0, 0] si no es ninguna.
static func _image_size(bin: PackedByteArray, start: int, end: int) -> Array:
	if end - start >= 24 and Array(bin.slice(start, start + 16)) == PNG_SIGNATURE:
		return [_be(bin, start + 16, 4), _be(bin, start + 20, 4)]
	var at := start + 2
	while end - start >= 4 and bin[start] == 0xFF and bin[start + 1] == 0xD8 and at + 9 <= end and bin[at] == 0xFF:
		var marker := bin[at + 1]
		if marker == 0xFF or marker == 0x01 or marker >= 0xD0 and marker <= 0xD8:
			at += 1 if marker == 0xFF else 2
		elif marker >= 0xC0 and marker <= 0xCF and not marker in [0xC4, 0xC8, 0xCC]:
			return [_be(bin, at + 7, 2), _be(bin, at + 5, 2)]
		elif marker == 0xD9 or marker == 0xDA or _be(bin, at + 2, 2) < 2:
			break
		else:
			at += 2 + _be(bin, at + 2, 2)
	return [0, 0]


static func _be(bin: PackedByteArray, at: int, size: int) -> int:
	var value := 0
	for i: int in size:
		value = value * 256 + bin[at + i]
	return value


# --- Limpieza ---

static func _clean_images(json: Dictionary, image_types: Array, ctx: Dictionary) -> Array:
	var out: Array = []
	ctx["imagenes"] = {}
	for i: int in image_types.size():
		if image_types[i] == "":
			ctx["avisos"]["texture"] = true
			continue
		ctx["imagenes"][i] = out.size()
		out.append({"bufferView": int(json["images"][i]["bufferView"]), "mimeType": image_types[i]})
	return out


## Las texturas sin una imagen buena se quitan; ctx.texturas lleva el índice viejo al nuevo.
static func _clean_textures(json: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = []
	var textures: Array = json.get("textures", [])
	for i: int in textures.size():
		var source := _int(textures[i].get("source"), MAX_ITEMS)
		if textures[i].has("extensions"):
			ctx["avisos"]["extensions"] = true
		if not ctx["imagenes"].has(source):
			ctx["avisos"]["texture"] = true
			continue
		ctx["texturas"][i] = out.size()
		var texture := {"source": ctx["imagenes"][source]}
		if _opt(textures[i], "sampler", json.get("samplers", []).size(), -1) >= 0:
			texture["sampler"] = int(textures[i]["sampler"])
		out.append(texture)
	return out


static func _clean_node(node: Dictionary, ctx: Dictionary) -> Dictionary:
	var out := _pick_ints(node, ["mesh"])
	if node.has("children"):
		out["children"] = _ints(node["children"])
	for key: String in TRANSFORMS:
		if node.has(key):
			out[key] = node[key]
	for pair: Array in [["skin", "skins"], ["weights", "targets"]]:
		if node.has(pair[0]):
			ctx["avisos"][pair[1]] = true
	return out


static func _clean_mesh(mesh: Dictionary, ctx: Dictionary) -> Dictionary:
	var primitives: Array = []
	for primitive: Dictionary in mesh["primitives"]:
		var out := _pick_ints(primitive, ["indices", "material"])
		out.merge({"attributes": _pick_ints(primitive["attributes"], ATTRIBUTES.keys()), "mode": 4})
		for attribute: String in primitive["attributes"]:
			if not ATTRIBUTES.has(attribute):
				ctx["avisos"][_dropped_attribute(attribute)] = true
		if primitive.has("targets") or mesh.has("weights"):
			ctx["avisos"]["targets"] = true
		primitives.append(out)
	return {"primitives": primitives}


static func _dropped_attribute(attribute: String) -> String:
	if attribute.begins_with("COLOR_"):
		return "color"
	return "skins" if attribute.begins_with("JOINTS_") or attribute.begins_with("WEIGHTS_") else "other"


static func _clean_material(material: Dictionary, ctx: Dictionary) -> Dictionary:
	var out := {}
	var pbr: Variant = material.get("pbrMetallicRoughness")
	if pbr is Dictionary:
		var clean_pbr := _pick_numbers(pbr, {"baseColorFactor": 4, "metallicFactor": 0, "roughnessFactor": 0})
		for key: String in ["baseColorTexture", "metallicRoughnessTexture"]:
			_copy_texture(pbr, clean_pbr, key, ctx)
		out["pbrMetallicRoughness"] = clean_pbr
	for key: String in ["normalTexture", "occlusionTexture", "emissiveTexture"]:
		_copy_texture(material, out, key, ctx)
	out.merge(_pick_numbers(material, {"emissiveFactor": 3, "alphaCutoff": 0}))
	if material.get("alphaMode") in ["OPAQUE", "MASK", "BLEND"]:
		out["alphaMode"] = material["alphaMode"]
	if material.get("doubleSided") is bool:
		out["doubleSided"] = material["doubleSided"]
	var extensions: Variant = material.get("extensions", {})
	if extensions is Dictionary and extensions.has("KHR_materials_unlit"):
		out["extensions"] = {"KHR_materials_unlit": {}}
		ctx["usadas"]["KHR_materials_unlit"] = true
	if not extensions is Dictionary or extensions.size() > int(out.has("extensions")):
		ctx["avisos"]["extensions"] = true
	return out


## Una textura mal indicada, o cuya imagen se quitó, se deja fuera (con aviso).
static func _copy_texture(source: Dictionary, target: Dictionary, key: String, ctx: Dictionary) -> void:
	var info: Variant = source.get(key)
	if info == null:
		return
	var index := _int(info.get("index"), MAX_ITEMS) if info is Dictionary else -1
	var coord := _opt(info, "texCoord", 2, 0) if info is Dictionary else -1
	if not ctx["texturas"].has(index) or coord < 0:
		ctx["avisos"]["texture"] = true
		return
	var out := _pick_numbers(info, {"scale": 0, "strength": 0})
	out.merge({"index": ctx["texturas"][index], "texCoord": coord})
	var transform: Variant = info["extensions"].get("KHR_texture_transform") if info.get("extensions") is Dictionary else null
	if transform is Dictionary:
		var clean_transform := _pick_numbers(transform, {"offset": 2, "rotation": 0, "scale": 2})
		if _opt(transform, "texCoord", 2, -1) >= 0:
			clean_transform["texCoord"] = int(transform["texCoord"])
		out["extensions"] = {"KHR_texture_transform": clean_transform}
		ctx["usadas"]["KHR_texture_transform"] = true
	target[key] = out


static func _clean_sampler(sampler: Dictionary) -> Dictionary:
	var out := {}
	for key: String in SAMPLER:
		if _opt(sampler, key, 40000, -1) in SAMPLER[key]:
			out[key] = int(sampler[key])
	return out


static func _clean_accessor(accessor: Dictionary) -> Dictionary:
	var out := _pick_ints(accessor, ["bufferView", "byteOffset", "componentType", "count"])
	out["type"] = accessor["type"]
	if accessor.get("normalized") is bool:
		out["normalized"] = accessor["normalized"]
	return out


static func _clean_extensions(json: Dictionary, out: Dictionary, ctx: Dictionary) -> void:
	var used: Variant = json.get("extensionsUsed", [])
	if json.has("extensions") or not used is Array or used.any(func(e: Variant) -> bool: return not e in EXTENSIONS):
		ctx["avisos"]["extensions"] = true
	if ctx["usadas"].is_empty():
		return
	out["extensionsUsed"] = ctx["usadas"].keys()
	var required: Array = json.get("extensionsRequired", []).filter(func(e: Variant) -> bool: return ctx["usadas"].has(e))
	if not required.is_empty():
		out["extensionsRequired"] = required


# --- Ayudas de tipos (un JSON ajeno puede traer cualquier cosa en cualquier sitio) ---

## Entero finito en [0, top), o -1.
static func _int(value: Variant, top: int) -> int:
	if not (value is int or value is float):
		return -1
	var number := float(value)
	return int(number) if is_finite(number) and number == floorf(number) and number >= 0.0 and number < float(top) else -1


## Campo entero opcional: fallback si falta, -1 si está mal.
static func _opt(item: Dictionary, key: String, top: int, fallback: int) -> int:
	return _int(item[key], top) if item.has(key) else fallback


## Lista de diccionarios (vacía si falta), o null si está mal o pasa de top.
static func _items(item: Dictionary, key: String, top := MAX_ITEMS) -> Variant:
	var list: Variant = item.get(key, [])
	if not list is Array or list.size() > top or not list.all(func(e: Variant) -> bool: return e is Dictionary):
		return null
	return list


## size números finitos (size 0: un número suelto).
static func _numbers(value: Variant, size: int) -> bool:
	var list: Array = [value] if size == 0 else value if value is Array else []
	return list.size() == maxi(size, 1) and list.all(func(v: Variant) -> bool:
		return (v is int or v is float) and is_finite(float(v)))


## Copia de source los campos de sizes que son números bien formados.
static func _pick_numbers(source: Dictionary, sizes: Dictionary) -> Dictionary:
	var out := {}
	for key: String in sizes:
		if source.has(key) and _numbers(source[key], sizes[key]):
			out[key] = source[key]
	return out


## Copia de source, como enteros, los campos de keys que tiene (check ya los validó).
static func _pick_ints(source: Dictionary, keys: Array) -> Dictionary:
	var out := {}
	for key: String in keys:
		if source.has(key):
			out[key] = int(source[key])
	return out


static func _ints(list: Array) -> Array:
	return list.map(func(v: Variant) -> int: return int(v))
