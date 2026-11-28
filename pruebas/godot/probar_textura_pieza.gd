extends SceneTree
# Paso 13.3h-a: textura base de las piezas en toon, toon_soft y outline (uniform base_tex, blanco por defecto) y
# BodyMaterial.set_base_texture / get_base_texture. Sin textura nada cambia: el único uso es multiplicar el color por
# base_tex (blanco = × 1) y ningún parámetro más se pone ni se mueve. Sin ventana: compila los shaders, pero no dibuja
# (los píxeles de textura × color quedan para la parte con ventana de la ficha). No escribe nada.
# Uso: prlimit --as=4096000000 timeout 120 godot --headless --path pruebas/godot -s probar_textura_pieza.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Que detecta el fallo: quitar «base_tex» de OUTLINE_SYNC -> falla «el contorno lleva la textura»; quitar el factor en
# toon.gdshader -> falla «toon: el color × base_tex»; hint_default_black en toon_soft -> falla «toon_soft: base_tex blanco por
# defecto»; que set_base_texture ignore null -> falla «null la quita».
# Paso 13.3h-c: el .glb lleva la textura de cada parte (albedo_texture), su color y sus UV. Escribe en user://textura_pieza
# y user://packs/propia_* (los borra) y deja pruebas/capturas/13.3h/con_textura.glb. Sin textura, el .glb es igual byte a
# byte a pruebas/capturas/13.3h/antes/plano.glb, que se saca con «-- --guardar-referencia» sobre el código de antes.
# Hasta 13.3h-b, la prueba pone la textura en la vista con set_base_texture. Que detecta el fallo: en
# GlbExporter._color_pieces, no asignar albedo_texture -> falla «el .glb sale con la textura».

const BodyMaterial := preload("res://../../godot/addons/creador/body_material.gd")
const StudioView := preload("res://../../godot/app/studio_view.gd")
const PieceImport := preload("res://../../godot/addons/creador/piece_import.gd")
const DIR := "user://textura_pieza"
const USER_PACKS := "user://packs"
const REFERENCE := "res://../capturas/13.3h/antes/plano.glb"
const TEXTURED := "res://../capturas/13.3h/con_textura.glb"
const GLB_TEXEL_MAX := 1.0 / 255.0  # PROVISIONAL (13.3h-c): píxel y color releídos del .glb
const UV_MAX := 1e-5  # PROVISIONAL (13.3h-c): UV releídas del .glb
const BIG := 2048  # px de lado de la textura cuyo tiempo de exportar se mide
## Daga de tres partes: mango y hoja con textura (si la lleva), pomo liso.
const PARTS := [Color(0.4, 0.2, 0.1), Color(0.8, 0.8, 0.85), Color(0.9, 0.8, 0.3)]
const PATTERNS := [Vector2i(8, 4), Vector2i(16, 16)]  # tamaño de la textura del mango y de la hoja
const DECLARATION := "uniform sampler2D base_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;"
const FACTOR := "mix(skin_color, garment_color, garment) * texture(base_tex, UV).rgb"
## La línea entera donde se usa, en cada shader.
const USE_LINES := {
	"toon": "vec3 color = " + FACTOR + ";",
	"toon_soft": "vec3 color = " + FACTOR + ";",
	"outline": "vec3 hsv = rgb_to_hsv(to_srgb(clamp(" + FACTOR + ", 0.0, 1.0)));"}
const TINT := Color(0.2, 0.6, 0.4)

var failures := 0


func _initialize() -> void:
	_check_shader("toon", BodyMaterial.SHADER)
	_check_shader("toon_soft", BodyMaterial.SOFT_SHADER)
	_check_shader("outline", BodyMaterial.OUTLINE_SHADER)
	for soft: bool in [false, true]:
		var name := "pieza anime" if soft else "pieza clásica"
		var code := _code(BodyMaterial.piece_shader(soft))
		check(name + ": su shader compila y lleva la textura", _has_uniform(BodyMaterial.piece_shader(soft))
				and code.count(FACTOR) == 1)
		_check_untouched(soft, name + ", sin textura: ")
		_check_texture(soft, name + ": ")
	_check_without_material()
	await _check_export()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


# --- Shaders ---

## El código sin comentarios ni espacios a los lados.
func _code(shader: Shader) -> String:
	var lines: Array[String] = []
	for line: String in shader.code.split("\n"):
		lines.append(line.get_slice("//", 0).strip_edges())
	return "\n".join(lines)


## Sin ventana, un shader que no compila no da ningún uniform.
func _has_uniform(shader: Shader) -> bool:
	return shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u["name"] == "base_tex")


## Con solo la declaración y un factor, sin textura (blanco, × 1,0) el color es el de antes.
func _check_shader(name: String, shader: Shader) -> void:
	var code := _code(shader)
	var lines := code.split("\n")
	check(name + ": compila y declara base_tex", _has_uniform(shader))
	check(name + ": base_tex blanco por defecto, color sRGB", lines.count(DECLARATION) == 1)
	check(name + ": el color × base_tex", lines.count(USE_LINES[name]) == 1)
	check(name + ": base_tex no se usa en nada más", code.count("base_tex") == 2, str(code.count("base_tex")))


# --- Material ---

func _piece(soft: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	BodyMaterial.apply(mesh, true, soft)
	return mesh


func _outline(mesh: MeshInstance3D) -> ShaderMaterial:
	return (mesh.material_override as ShaderMaterial).get_meta("outline")


## Todos los parámetros del material y de su contorno, según los uniform de cada shader.
func _parameters(mesh: MeshInstance3D) -> Dictionary:
	var values := {}
	for material: ShaderMaterial in [mesh.material_override, _outline(mesh)]:
		var prefix := "contorno/" if material == _outline(mesh) else ""
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			values[prefix + uniform["name"]] = material.get_shader_parameter(uniform["name"])
	return values


## Una pieza sin textura lleva los parámetros de antes del paso: los del estilo, depth_pull y base_tex sin poner.
func _check_untouched(soft: bool, label: String) -> void:
	var mesh := _piece(soft)
	var defaults: Dictionary = BodyMaterial.SOFT_DEFAULTS if soft else BodyMaterial.DEFAULTS
	check(label + "base_tex fuera de los valores por defecto", not defaults.has("base_tex")
			and not BodyMaterial.OUTLINE_DEFAULTS.has("base_tex"))
	var values := _parameters(mesh)
	check(label + "sin poner en el material ni en el contorno", values.has("base_tex") and values["base_tex"] == null
			and values.has("contorno/base_tex") and values["contorno/base_tex"] == null
			and BodyMaterial.get_base_texture(mesh) == null)
	var expected := defaults.duplicate()
	expected["depth_pull"] = BodyMaterial.PIECE_PULL
	for name: String in BodyMaterial.OUTLINE_DEFAULTS:
		expected["contorno/" + name] = BodyMaterial.OUTLINE_DEFAULTS[name]
	var wrong: Array[String] = []
	for name: String in values:
		if values[name] != expected.get(name):
			wrong.append(name)
	check(label + "los demás parámetros, los de siempre", wrong.is_empty(), str(wrong))
	mesh.free()


func _carries(mesh: MeshInstance3D, texture: Texture2D) -> bool:
	return BodyMaterial.get_base_texture(mesh) == texture and _outline(mesh).get_shader_parameter("base_tex") == texture


func _check_texture(soft: bool, label: String) -> void:
	var mesh := _piece(soft)
	var plain := _parameters(mesh)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.1, 0.1))
	var texture := ImageTexture.create_from_image(image)
	BodyMaterial.set_base_texture(mesh, texture)
	check(label + "ida y vuelta", BodyMaterial.get_base_texture(mesh) == texture)
	check(label + "el contorno lleva la textura", _outline(mesh).get_shader_parameter("base_tex") == texture)
	var changed := _parameters(mesh).keys().filter(func(k: String) -> bool: return _parameters(mesh)[k] != plain[k])
	check(label + "solo cambia base_tex", changed == ["base_tex", "contorno/base_tex"], str(changed))
	BodyMaterial.set_color(mesh, "skin_color", TINT)
	check(label + "el color elegido tiñe y no quita la textura", BodyMaterial.get_color(mesh, "skin_color") == TINT
			and _outline(mesh).get_shader_parameter("skin_color") == TINT and _carries(mesh, texture))
	BodyMaterial.set_style(mesh, not soft, true)
	check(label + "sobrevive al cambiar de estilo", BodyMaterial.is_soft(mesh) != soft and _carries(mesh, texture))
	BodyMaterial.set_style(mesh, soft, true)
	check(label + "y al volver", BodyMaterial.is_soft(mesh) == soft and _carries(mesh, texture))
	BodyMaterial.set_base_texture(mesh, null)
	check(label + "null la quita del material y del contorno", _carries(mesh, null))
	BodyMaterial.set_color(mesh, "skin_color", plain["skin_color"])
	var left := _parameters(mesh).keys().filter(func(k: String) -> bool: return _parameters(mesh)[k] != plain[k])
	left.erase("contorno/width_px")  # set_style pone el grosor del estilo
	check(label + "quitada, queda como sin textura", left.is_empty(), str(left))
	BodyMaterial.set_base_texture(mesh, texture)
	var copy := MeshInstance3D.new()
	copy.material_override = StudioView._copy(mesh.material_override)
	check(label + "la copia del Estudio la lleva", copy.material_override != mesh.material_override
			and _outline(copy) != _outline(mesh) and _carries(copy, texture))
	check(label + "la copia para el juego (cuerpo) no la lleva",
			BodyMaterial.standalone(mesh).get_shader_parameter("base_tex") == null)
	copy.free()
	mesh.free()


func _check_without_material() -> void:
	var mesh := MeshInstance3D.new()
	var no_material := BodyMaterial.get_base_texture(mesh) == null
	mesh.material_override = StandardMaterial3D.new()
	check("get_base_texture sin ShaderMaterial: null", no_material and BodyMaterial.get_base_texture(mesh) == null)
	mesh.free()


# --- 13.3h-c: exportar ---

func _check_export() -> void:
	var view = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/body_view.gd").simplify_path()).new()
	root.add_child(view)
	await process_frame
	check("13.3h-c: la vista carga", view.error == "", view.error)
	var had_packs := DirAccess.dir_exists_absolute(USER_PACKS)
	DirAccess.make_dir_recursive_absolute(DIR)
	if view.error == "":
		_check_plain(view)
		_check_textured(view)
	view.free()
	_remove_tree(DIR)
	if not had_packs:
		DirAccess.remove_absolute(USER_PACKS)
	check("13.3h-c: lo escrito, borrado", not DirAccess.dir_exists_absolute(DIR))


## Cuerpo con base/tights, base/halo y la daga sin textura: el .glb, igual byte a byte que antes del paso.
func _check_plain(view) -> void:
	var id := _save_dagger(false)
	view.rescan_packs()
	var path := DIR.path_join("plano.glb")
	var ok: bool = id != "" and view.set_piece("base", "tights", true) and view.set_piece("base", "halo", true) \
			and view.set_piece(id, id, true) and view.export_glb(path) == OK
	check("13.3h-c: sin textura: se exporta", ok)
	var reference := ProjectSettings.globalize_path(REFERENCE)
	if ok and OS.get_cmdline_user_args().has("--guardar-referencia"):
		DirAccess.make_dir_recursive_absolute(reference.get_base_dir())
		DirAccess.copy_absolute(path, reference)
		print("  AVISO referencia guardada en ", reference)
	var found := FileAccess.file_exists(reference)
	check("13.3h-c: sin textura: el .glb, mismo sha256 que antes del paso", ok and found
			and FileAccess.get_sha256(path) == FileAccess.get_sha256(reference),
			"" if found else "falta la referencia: lanzar con -- --guardar-referencia sobre el código de antes")
	var scene := _read(path) if ok else null
	if scene != null:
		var textured := 0
		for mesh: MeshInstance3D in scene.find_children(id + "*", "MeshInstance3D", true, false):
			if (mesh.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture != null:
				textured += 1
		check("13.3h-c: sin textura: la daga sale sin textura", textured == 0, str(textured))
		scene.free()
	for key: Array in [["base", "tights"], ["base", "halo"], [id, id]]:
		view.set_piece(key[0], key[1], false)
	_remove_tree(USER_PACKS.path_join(id))


func _check_textured(view) -> void:
	var id := _save_dagger(true)
	view.rescan_packs()
	if id == "" or not view.set_piece(id, id, true):
		check("13.3h-c: se pone la daga con textura", false)
		return
	var meshes: Array = view.meshes_of(id.path_join(id))
	for k: int in PATTERNS.size():  # lo que hará 13.3h-b al ponerla
		BodyMaterial.set_base_texture(meshes[k], ImageTexture.create_from_image(_pattern(k)))
	var path := DIR.path_join("con_textura.glb")
	var scene := _read(path) if view.export_glb(path) == OK else null
	check("13.3h-c: con textura: se exporta y se lee", scene != null)
	if scene != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEXTURED).get_base_dir())
		DirAccess.copy_absolute(path, ProjectSettings.globalize_path(TEXTURED))
		for k: int in PARTS.size():
			_check_part(scene.find_child("%s_m%d" % [id, k], true, false) as MeshInstance3D, meshes[k], k)
		scene.free()
	var studio = StudioView.new()
	var baked: MeshInstance3D = studio.character.find_child(meshes[0].name, true, false) \
			if studio.enter(view) == OK else null
	check("13.3h-c: Estudio: el horneado conserva base_tex", baked != null
			and BodyMaterial.get_base_texture(baked) == BodyMaterial.get_base_texture(meshes[0]))
	if baked != null:
		studio.leave()
	_measure_big(view, meshes[0])
	view.set_piece(id, id, false)
	_remove_tree(USER_PACKS.path_join(id))


## Una parte releída: su color, y con textura, la textura (tamaño y píxeles) y las UV de la vista.
func _check_part(part: MeshInstance3D, live: MeshInstance3D, k: int) -> void:
	var material := part.mesh.surface_get_material(0) as BaseMaterial3D if part != null else null
	if material == null:
		check("13.3h-c: parte %d en el .glb con material" % k, false)
		return
	var color_gap := _gap(material.albedo_color, PARTS[k])
	check("13.3h-c: parte %d con su color" % k, color_gap <= GLB_TEXEL_MAX, "%.5f" % color_gap)
	if k >= PATTERNS.size():
		check("13.3h-c: parte %d (lisa) sin textura" % k, material.albedo_texture == null)
		return
	check("13.3h-c: parte %d: el .glb sale con la textura" % k, material.albedo_texture != null)
	if material.albedo_texture == null:
		return
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	var source := _pattern(k)
	var texel := INF
	if image.get_size() == source.get_size():
		texel = 0.0
		for y: int in source.get_height():
			for x: int in source.get_width():
				texel = maxf(texel, _gap(image.get_pixel(x, y), source.get_pixel(x, y)))
	print("  MEDIDA 13.3h-c: parte %d, píxel %.5f" % [k, texel])
	check("13.3h-c: parte %d: textura del mismo tamaño y píxeles" % k, texel <= GLB_TEXEL_MAX, str(image.get_size()))
	var uv: PackedVector2Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var wanted: PackedVector2Array = live.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var uv_gap := INF
	if uv.size() == wanted.size() and not uv.is_empty():
		uv_gap = 0.0
		for v: int in uv.size():
			uv_gap = maxf(uv_gap, maxf(absf(uv[v].x - wanted[v].x), absf(uv[v].y - wanted[v].y)))
	print("  MEDIDA 13.3h-c: parte %d, UV %.7f" % [k, uv_gap])
	check("13.3h-c: parte %d: sus UV" % k, uv_gap <= UV_MAX, "%d de %d" % [uv.size(), wanted.size()])


## Segundos de exportar con una textura de BIG px (solo medida).
func _measure_big(view, mesh: MeshInstance3D) -> void:
	var image := Image.create(BIG, BIG, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.3, 0.7))
	image.generate_mipmaps()
	BodyMaterial.set_base_texture(mesh, ImageTexture.create_from_image(image))
	var start := Time.get_ticks_msec()
	var error: Error = view.export_glb(DIR.path_join("grande.glb"))
	print("  MEDIDA 13.3h-c: exportar con una textura de %d px: %.2f s" % [BIG, (Time.get_ticks_msec() - start) / 1000.0])
	check("13.3h-c: con una textura de %d px se exporta" % BIG, error == OK)


## Textura de prueba k: un degradado (cada píxel distinto), con mipmaps como las de la vista.
func _pattern(k: int) -> Image:
	var size: Vector2i = PATTERNS[k]
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			image.set_pixel(x, y, Color(float(x) / size.x, float(y) / size.y, 0.3 + 0.4 * k, 1.0))
	image.generate_mipmaps()
	return image


## La daga importada y guardada en user://packs: su id, o "" si falla. textured: mango y hoja con textura.
func _save_dagger(textured: bool) -> String:
	var dagger := Node3D.new()
	var sizes := [Vector3(0.03, 0.15, 0.03), Vector3(0.05, 0.3, 0.01), Vector3(0.04, 0.04, 0.04)]
	var centers := [Vector3.ZERO, Vector3(0, 0.25, 0), Vector3(0, -0.095, 0)]
	for k: int in PARTS.size():
		var material := StandardMaterial3D.new()
		material.albedo_color = PARTS[k]
		if textured and k < PATTERNS.size():
			material.albedo_texture = ImageTexture.create_from_image(_pattern(k))
		_add_box(dagger, sizes[k], centers[k], material)
	var path := DIR.path_join("daga.glb")
	for child: Node in dagger.get_children():
		child.owner = dagger
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var written := document.append_from_scene(dagger, state) == OK and document.write_to_filesystem(state, path) == OK
	dagger.free()
	var r := PieceImport.read(path) if written else {"error": "no se escribe"}
	var saved := PieceImport.save(r["partes"], {"nombre": "Daga", "autor": "", "origen": "", "especie": "humana",
		"hueso": "socket_hand_r"}, USER_PACKS) if r["error"] == "" else {"error": r["error"], "pack": ""}
	check("13.3h-c: daga %s guardada en user://packs" % ("con textura" if textured else "lisa"), saved["error"] == "",
			saved["error"])
	return saved["pack"]


## Caja con la geometría desplazada a center (el nodo queda en el origen).
func _add_box(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k: int in points.size():
		points[k] += center
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)


## El .glb releído como escena (quien llama la libera); null si no se lee.
func _read(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	return document.generate_scene(state) if document.append_from_file(path, state) == OK else null


func _gap(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _remove_tree(folder: String) -> void:
	for name: String in DirAccess.get_directories_at(folder):
		_remove_tree(folder.path_join(name))
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
