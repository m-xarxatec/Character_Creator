extends SceneTree
# Paso 13.3b: GlbInspect valida y limpia un .glb ajeno (D59). Los .glb se fabrican aquí (una caja), sin assets; escribe
# solo en user://glb_ajeno, que borra al acabar. Cualquier línea ERROR es un fallo aunque ponga TODO BIEN.
# Uso: (prlimit --as=4096000000 timeout 120 godot --headless --path pruebas/godot -s probar_glb_ajeno.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en GlbInspect._check_nodes, no sumar los bytes por nodo -> falla «2.000 nodos × 1 malla:
# rechazado». En GlbInspect._clean_images, no saltar las imágenes malas -> falla «firma falsa: pasa sin la textura».
# Mide (MEDIDA) cuánto tardan check y clean con un .glb de 250 MB.

const GlbInspect := preload("res://../../godot/addons/creador/glb_inspect.gd")
const DIR := "user://glb_ajeno"
const COLOR := Color(0.5, 0.25, 1.0)  # lineal, como en glTF
const COLOR_MAX := 1.0 / 255.0  # (13.3b): diferencia del color leído de la copia limpia

const HEAVY_BYTES := 250 * 1024 * 1024  # cerca del tope de 256 MB, para medir

var failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_check_good()
	_check_bad_files()
	_check_bad_json()
	_check_bad_images()
	_check_clean()
	_check_silent()
	_measure_heavy()
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


# --- Casos ---

func _check_good() -> void:
	var r := GlbInspect.read(_write("caja.glb", _box()))
	check("caja con PNG dentro: pasa", r["error"] == "" and r["triangulos"] == 12 and r["avisos"].is_empty(), str(r["error"], r["avisos"]))
	var scene := _load(r["bytes"])
	var material := _material(scene)
	check("la copia limpia carga con su textura", material != null and material.albedo_texture != null
			and material.albedo_texture.get_size() == Vector2(4, 4))
	if material:
		var color := COLOR.linear_to_srgb()
		check("y con su color", absf(material.albedo_color.r - color.r) < COLOR_MAX
				and absf(material.albedo_color.g - color.g) < COLOR_MAX, str(material.albedo_color))
	if scene:
		scene.free()
	var g := _box(_jpg(8, 4))
	g["json"]["images"][0] = {"uri": "textura.jpg"}
	g["json"]["bufferViews"].pop_back()  # la vista de la imagen era la última
	var file := FileAccess.open(DIR.path_join("textura.jpg"), FileAccess.WRITE)
	file.store_buffer(_jpg(8, 4))
	file.close()
	r = GlbInspect.read(_write("caja_jpg.glb", g))
	scene = _load(r["bytes"])
	material = _material(scene)
	check("caja con JPG al lado: pasa y la textura va dentro", r["error"] == "" and material != null
			and material.albedo_texture != null and material.albedo_texture.get_size() == Vector2(8, 4), r["error"])
	if scene:
		scene.free()
	r = GlbInspect.read(_write("grande.glb", _soup(600000, 1)))
	check("200.000 triángulos: pasa (sin límite de triángulos, P5)", r["error"] == "" and r["triangulos"] == 200000, r["error"])
	r = GlbInspect.read(_write("una_vez.glb", _soup(21000, 1)))
	check("1 nodo × la malla de 21.000 vértices: pasa", r["error"] == "", r["error"])
	r = GlbInspect.read(_write("mil_nodos.glb", _soup(21000, 1000)))
	check("1.000 nodos × 1 malla (252 MB repetidos): pasa", r["error"] == "", r["error"])
	_reject("2.000 nodos × 1 malla", _write("dos_mil_nodos.glb", _soup(21000, 2000)))  # 504 MB repetidos
	var shared := _soup(99999, 1)  # 1,2 MB que leen 256 primitivas: 307 MB
	shared["json"]["meshes"][0]["primitives"] = _copies(shared["json"]["meshes"][0]["primitives"][0], 256)
	_reject("256 primitivas que comparten un accessor de 1,2 MB", _write("compartido.glb", shared))


func _check_bad_files() -> void:
	var file := FileAccess.open(DIR.path_join("enorme.glb"), FileAccess.WRITE)
	file.seek(GlbInspect.MAX_FILE_BYTES)  # disperso: no ocupa disco ni memoria
	file.store_8(0)
	file.close()
	_reject("256 MB + 1", DIR.path_join("enorme.glb"))
	_reject("texto", _store("texto.glb", "hola, esto no es un glb aunque lo diga su nombre".to_utf8_buffer()))
	_reject("extensión .gltf", _write("caja.gltf", _box()))
	var good := _pack(_box()["json"], _box()["bin"])
	_reject("cabecera cortada", _store("cortado.glb", good.slice(0, 12)))
	var liar := good.duplicate()
	liar.encode_u32(8, good.size() + 4)
	_reject("longitud falsa", _store("longitud.glb", liar))
	_reject("JSON roto", _store("json_roto.glb", _pack_text("{\"asset\": {\"version\": ", PackedByteArray())))
	_reject("JSON con 100.000 corchetes", _store("profundo.glb", _pack_text("[".repeat(100000), PackedByteArray())))


func _check_bad_json() -> void:
	var cases := {
		"nodes: 5": func(j: Dictionary) -> void: j["nodes"] = 5,
		"count 10⁹": func(j: Dictionary) -> void: j["accessors"][0]["count"] = 1e9,
		"vista fuera de BIN": func(j: Dictionary) -> void: j["bufferViews"][0]["byteLength"] = 1e6,
		"buffer con uri": func(j: Dictionary) -> void: j["buffers"][0]["uri"] = "otro.bin",
		"Draco": func(j: Dictionary) -> void: j["extensionsRequired"] = ["KHR_draco_mesh_compression"],
		"ciclo": func(j: Dictionary) -> void: j["nodes"] = [{"children": [1.0]}, {"children": [0.0], "mesh": 0}],
		"dos padres": func(j: Dictionary) -> void: j["nodes"] = [{"children": [2.0]}, {"children": [2.0]}, {"mesh": 0}],
		"índice decimal": func(j: Dictionary) -> void: j["meshes"][0]["primitives"][0]["indices"] = 3.5,
		"257 primitivas": func(j: Dictionary) -> void: j["meshes"][0]["primitives"] = _copies(j["meshes"][0]["primitives"][0], 257),
		"líneas": func(j: Dictionary) -> void: j["meshes"][0]["primitives"][0]["mode"] = 1,
		"POSITION con enteros": func(j: Dictionary) -> void: j["accessors"][0]["componentType"] = 5123,
	}
	for label: String in cases:
		var g := _box()
		cases[label].call(g["json"])
		_reject(label, _write("malo.glb", g))
	var g := _box()
	var bin: PackedByteArray = g["bin"]
	bin.encode_u16(g["json"]["bufferViews"][3]["byteOffset"] + 2, 99)  # la vista 3 son los índices; la caja tiene 8 vértices
	g["bin"] = bin
	_reject("índice fuera de rango", _write("indice.glb", g))


func _sorted(list: Array) -> Array:
	var out := list.duplicate()
	out.sort()
	return out


func _copies(item: Dictionary, count: int) -> Array:
	return range(count).map(func(_i: int) -> Dictionary: return item.duplicate(true))


func _check_bad_images() -> void:
	_store("vacia.png", PackedByteArray())
	for uri: String in ["../fuera.png", "data:image/png;base64,iVBORw0KGgo=", "falta.png", "sub/textura.png", "vacia.png"]:
		var g := _box()
		g["json"]["images"][0] = {"uri": uri}
		_without_texture("imagen «%s»" % uri, _write("uri.glb", g))
	_without_texture("firma falsa", _write("firma.glb", _box(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))))
	var wide := Image.create(20000, 1, false, Image.FORMAT_L8)
	_without_texture("20.000 px de lado", _write("ancha.glb", _box(wide.save_png_to_buffer())))
	var webp := _box()
	webp["json"]["textures"][0] = {"extensions": {"EXT_texture_webp": {"source": 0}}}
	_without_texture("textura WebP (sin source)", _write("webp.glb", webp), 1)  # la imagen PNG es buena y se queda
	var g := _box(_jpg(16, 16))
	g["json"]["images"][0]["mimeType"] = "image/png"  # miente: el tipo sale de la firma
	var r := GlbInspect.read(_write("mime.glb", g))
	check("JPG que dice ser PNG: pasa como JPG", r["error"] == "" and _json_of(r["bytes"])["images"][0]["mimeType"] == "image/jpeg", r["error"])


func _check_clean() -> void:
	var g := _box()
	var json: Dictionary = g["json"]
	json["nodes"][0]["skin"] = 0
	json["skins"] = [{"joints": [0]}]
	json["animations"] = [{"channels": [], "samplers": []}]
	json["meshes"][0]["primitives"][0]["targets"] = [{"POSITION": 0}]
	json["meshes"][0]["primitives"][0]["attributes"]["COLOR_0"] = 1
	json["extensionsUsed"] = ["KHR_lights_punctual"]
	json["extensions"] = {"KHR_lights_punctual": {"lights": [{"type": "point"}]}}
	var r := GlbInspect.read(_write("sucio.glb", g))
	var notes := " | ".join(r["avisos"])
	check("con piel, animación, formas y color por vértice: pasa con 4 avisos (las luces, en silencio)",
			r["error"] == "" and r["avisos"].size() == 4, notes)
	if r["error"] != "":
		return
	var clean := _json_of(r["bytes"])
	var primitive: Dictionary = clean["meshes"][0]["primitives"][0]
	check("clean quita piel, animación y luces", not clean.has("skins") and not clean.has("animations")
			and not clean.has("extensions") and not clean["nodes"][0].has("skin"))
	check("clean quita formas y color por vértice", not primitive.has("targets")
			and _sorted(primitive["attributes"].keys()) == ["NORMAL", "POSITION", "TEXCOORD_0"], str(primitive["attributes"].keys()))
	check("clean quita los nombres", not clean["nodes"][0].has("name") and not clean["materials"][0].has("name")
			and not clean["asset"].has("generator"))
	var scene := _load(r["bytes"])
	check("la copia limpia carga", scene != null)
	if scene:
		scene.free()


## Decisión del líder (2026-11-28): solo se avisa de lo que el usuario vería; lo demás se quita en silencio.
func _check_silent() -> void:
	var root := MeshInstance3D.new()
	root.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	var png := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	png.fill(Color.WHITE)
	material.albedo_texture = ImageTexture.create_from_image(png)
	root.mesh.material = material
	var state := GLTFState.new()
	var doc := GLTFDocument.new()
	doc.append_from_scene(root, state)
	var path := _store("godot.glb", doc.generate_buffer(state))
	root.free()
	var r := GlbInspect.read(path)
	check("un .glb exportado por Godot (con textura): sin avisos y con su textura", r["error"] == "" and r["avisos"].is_empty()
			and _json_of(r["bytes"])["images"].size() == 1, str(r["error"], r["avisos"]))
	var g := _box()
	var json: Dictionary = g["json"]
	var attributes: Dictionary = json["meshes"][0]["primitives"][0]["attributes"]
	attributes["TANGENT"] = attributes["POSITION"]
	attributes["TEXCOORD_2"] = attributes["TEXCOORD_0"]
	json["materials"][0]["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": 2.0}}
	json["textures"][0]["extensions"] = {"EXT_algo": {}}
	json["extensionsUsed"] = ["KHR_materials_emissive_strength", "EXT_algo"]
	r = GlbInspect.read(_write("silencio.glb", g))
	check("tangentes, UV extra y extensiones no obligatorias: se quitan sin avisos", r["error"] == "" and r["avisos"].is_empty()
			and not _json_of(r["bytes"])["meshes"][0]["primitives"][0]["attributes"].has("TANGENT"), str(r["error"], r["avisos"]))
	json["extensionsRequired"] = ["EXT_algo"]
	_reject("extensión obligatoria desconocida", _write("obligatoria.glb", g))
	g = _box()
	g["json"]["images"][0] = {"uri": "falta.png"}
	r = GlbInspect.read(_write("sin_textura.glb", g))
	check("quitar una textura sí avisa", GlbInspect.NOTES["texture"] in r["avisos"] and r["avisos"].size() == 1, str(r["avisos"]))


## Unos 250 MB solo de geometría: 70.000 vértices y el resto índices u32 (hay que mirarlos todos). Se acepta (D59).
func _measure_heavy() -> void:
	var g := _empty()
	var vertices := 70000
	var count := (HEAVY_BYTES - vertices * 12) / 12 * 3
	var points := PackedByteArray()
	points.resize(vertices * 12)
	var indices := PackedByteArray()
	indices.resize(count * 4)
	g["json"]["meshes"] = [{"primitives": [{"attributes": {"POSITION": _accessor(g, points, 5126, vertices, "VEC3")},
		"indices": _accessor(g, indices, 5125, count, "SCALAR")}]}]
	g["json"]["nodes"] = [{"mesh": 0}]
	var path := _write("pesado.glb", g)
	g.clear()
	var start := Time.get_ticks_msec()
	var parsed: Dictionary = GlbInspect._parse(path)
	var read_ms := Time.get_ticks_msec() - start
	start = Time.get_ticks_msec()
	var checked: Dictionary = GlbInspect.check(parsed["json"], parsed["bin"])
	GlbInspect.clean(parsed["json"], checked["imagenes"])
	var check_ms := Time.get_ticks_msec() - start
	print("MEDIDA glb de %d MB: leer %d ms, check+clean %d ms" % [FileAccess.get_size(path) / 1048576, read_ms, check_ms])
	check("el pesado pasa", checked["error"] == "", checked["error"])


## Decisión del líder (2026-11-28): una textura que falta o está mal no rechaza el archivo; se quita, con aviso, y
## queda el color base.
func _without_texture(label: String, path: String, kept_images := 0) -> void:
	var r := GlbInspect.read(path)
	var ok: bool = r["error"] == "" and GlbInspect.NOTES["texture"] in r["avisos"]
	if ok:
		var clean := _json_of(r["bytes"])
		ok = clean["images"].size() == kept_images and clean["textures"].is_empty() \
				and not clean["materials"][0]["pbrMetallicRoughness"].has("baseColorTexture")
	var scene := _load(r["bytes"])
	var material := _material(scene)
	check(label + ": pasa sin la textura, con aviso y su color", ok and material != null and material.albedo_texture == null
			and absf(material.albedo_color.r - COLOR.linear_to_srgb().r) < COLOR_MAX, str(r["error"], r["avisos"]))
	if scene:
		scene.free()


func _reject(label: String, path: String) -> void:
	var r := GlbInspect.read(path)
	check(label + ": rechazado", r["error"] != "" and r["bytes"].is_empty(), r["error"])


# --- Fabricar .glb ---

## Caja de 8 vértices (12 triángulos, índices u16) con normales, UV y un material con textura (PNG de 4×4).
func _box(image := PackedByteArray()) -> Dictionary:
	if image.is_empty():
		var png := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		png.fill(Color.WHITE)
		image = png.save_png_to_buffer()
	var g := _empty()
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	for i: int in 8:
		var p := Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1) - Vector3.ONE * 0.5
		points.append(p)
		normals.append(p.normalized())
		uv.append(Vector2(p.x, p.y) + Vector2.ONE * 0.5)
	var indices := PackedByteArray()
	for face: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		for k: int in [0, 1, 2, 0, 2, 3]:
			indices.resize(indices.size() + 2)
			indices.encode_u16(indices.size() - 2, face[k])
	var attributes := {"POSITION": _accessor(g, points.to_byte_array(), 5126, 8, "VEC3"),
		"NORMAL": _accessor(g, normals.to_byte_array(), 5126, 8, "VEC3"),
		"TEXCOORD_0": _accessor(g, uv.to_byte_array(), 5126, 8, "VEC2")}
	var json: Dictionary = g["json"]
	json["meshes"] = [{"name": "caja", "primitives": [{"attributes": attributes, "material": 0,
		"indices": _accessor(g, indices, 5123, 36, "SCALAR")}]}]
	json["nodes"] = [{"name": "Caja", "mesh": 0, "translation": [0.0, 1.0, 0.0]}]
	json["materials"] = [{"name": "lila", "pbrMetallicRoughness": {"baseColorFactor": [COLOR.r, COLOR.g, COLOR.b, 1.0],
		"baseColorTexture": {"index": 0}}}]
	json["textures"] = [{"source": 0, "sampler": 0}]
	json["samplers"] = [{"magFilter": 9729}]
	json["images"] = [{"bufferView": _view(g, image), "mimeType": "image/png"}]
	return g


## Sopa de triángulos sin índices (vértices en el origen), repetida en `copies` nodos.
func _soup(vertices: int, copies: int) -> Dictionary:
	var g := _empty()
	var zeros := PackedByteArray()
	zeros.resize(vertices * 12)
	g["json"]["meshes"] = [{"primitives": [{"attributes": {"POSITION": _accessor(g, zeros, 5126, vertices, "VEC3")}}]}]
	g["json"]["nodes"] = range(copies).map(func(_i: int) -> Dictionary: return {"mesh": 0})
	g["json"]["scenes"] = [{"nodes": range(copies)}]
	return g


func _empty() -> Dictionary:
	return {"bin": PackedByteArray(), "json": {"asset": {"version": "2.0", "generator": "probar_glb_ajeno"}, "scene": 0,
		"scenes": [{"nodes": [0]}], "accessors": [], "bufferViews": [], "buffers": [{"byteLength": 0}]}}


func _view(g: Dictionary, bytes: PackedByteArray) -> int:
	var bin: PackedByteArray = g["bin"]
	while bin.size() % 4:
		bin.append(0)
	g["json"]["bufferViews"].append({"buffer": 0, "byteOffset": bin.size(), "byteLength": bytes.size()})
	bin.append_array(bytes)
	g["bin"] = bin
	g["json"]["buffers"][0]["byteLength"] = bin.size()
	return g["json"]["bufferViews"].size() - 1


func _accessor(g: Dictionary, bytes: PackedByteArray, component: int, count: int, kind: String) -> int:
	g["json"]["accessors"].append({"bufferView": _view(g, bytes), "componentType": component, "count": count, "type": kind})
	return g["json"]["accessors"].size() - 1


func _jpg(width: int, height: int) -> PackedByteArray:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	return image.save_jpg_to_buffer()


func _pack(json: Dictionary, bin: PackedByteArray) -> PackedByteArray:
	return _pack_text(JSON.stringify(json), bin)


func _pack_text(text: String, bin: PackedByteArray) -> PackedByteArray:
	var data := text.to_utf8_buffer()
	while data.size() % 4:
		data.append(0x20)
	var body := bin.duplicate()
	while body.size() % 4:
		body.append(0)
	var out := PackedByteArray()
	out.resize(20)
	out.encode_u32(0, 0x46546C67)
	out.encode_u32(4, 2)
	out.encode_u32(8, 20 + data.size() + (8 + body.size() if body.size() else 0))
	out.encode_u32(12, data.size())
	out.encode_u32(16, 0x4E4F534A)
	out.append_array(data)
	if body.size():
		var head := PackedByteArray()
		head.resize(8)
		head.encode_u32(0, body.size())
		head.encode_u32(4, 0x004E4942)
		out.append_array(head)
		out.append_array(body)
	return out


func _write(file_name: String, g: Dictionary) -> String:
	return _store(file_name, _pack(g["json"], g["bin"]))


func _store(file_name: String, bytes: PackedByteArray) -> String:
	var path := DIR.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return path


# --- Leer el resultado ---

func _load(bytes: PackedByteArray) -> Node:
	if bytes.is_empty():
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	return document.generate_scene(state) if document.append_from_buffer(bytes, "", state) == OK else null


func _material(scene: Node) -> StandardMaterial3D:
	if scene == null:
		return null
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	return null if meshes.is_empty() else (meshes[0] as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D


func _json_of(bytes: PackedByteArray) -> Dictionary:
	return JSON.parse_string(bytes.slice(20, 20 + bytes.decode_u32(12)).get_string_from_utf8())
