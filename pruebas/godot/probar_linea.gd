extends SceneTree
# Paso SH.4b: contorno teñido y más fino en la cara (outline.gdshader). Con outline_tint 0 la línea es outline_color,
# como siempre; con 1, el color de la zona (piel o prenda) oscuro. face_line solo adelgaza donde el canal A de
# skin_zones es 0 (la cara); sin textura no cambia el grosor. set_color y la prenda llegan también al contorno, y la vista
# copia el tinte a las piezas. Con ventana. En Forward+ guarda las hojas.
# Uso: (ulimit -v 4000000; timeout 900 godot [--rendering-method mobile] --path pruebas/godot -s probar_linea.gd 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# Escribe en pruebas/capturas/shader_linea/: hoja_linea.png (cara; outline_tint 0 / 0,5 / 0,8 / 1) y hoja_colores.png
# (el estilo anime completo, de SKIN_START, con 8 colores de piel, cuerpo y cara).
# Que detecta el fallo (en una copia de outline.gdshader): `ALBEDO = outline_color;`; quitar `mix(face_line, …)`.

const OUT_DIR := "pruebas/capturas/shader_linea"
const SIZE := 96
const EDGE_X := 72  # un píxel de la línea, fuera de la silueta de la esfera (radio ≈ 22 px), en la fila central
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const SKIN := Color(0.96, 0.80, 0.70)
const SAME := 2  # /255 PROVISIONAL
const ROWS := [
	{"preset": "anime", "skin": Color(0.96, 0.80, 0.70), "hair": ["makehuman", "toigo_blunt_bob_with_bangs"],
		"hair_color": Color(0.20, 0.55, 0.35), "clothes": Color(0.10, 0.10, 0.11)},
	{"preset": "femenino", "skin": Color(0.30, 0.19, 0.14), "hair": ["quaternius", "hair_long"],
		"hair_color": Color(0.30, 0.20, 0.15), "clothes": Color(0.28, 0.33, 0.45)},
	{"preset": "masculino", "skin": Color(0.72, 0.50, 0.36), "hair": ["makehuman", "short02"],
		"hair_color": Color(0.62, 0.46, 0.22), "clothes": Color(0.85, 0.85, 0.82)},
	{"preset": "anime", "skin": Color(0.35, 0.55, 0.85), "hair": ["makehuman", "short02"],
		"hair_color": Color(0.16, 0.20, 0.42), "clothes": Color(0.85, 0.85, 0.82)},
]
## Colores que un usuario podría elegir: pálido rosado, melocotón, oliva, canela, oscuro, lavanda, verde menta y gris.
const SKINS := [Color(0.98, 0.86, 0.84), Color(0.97, 0.80, 0.66), Color(0.80, 0.64, 0.46), Color(0.62, 0.40, 0.27),
	Color(0.27, 0.17, 0.13), Color(0.74, 0.66, 0.92), Color(0.62, 0.86, 0.72), Color(0.62, 0.62, 0.64)]
const CLOTHES := [["overscore", "os_tank_top"], ["overscore", "os_golf_shorts"]]
const SHOT_FACE := [25.0, 4.0, Vector3(0, 1.55, 0), 1.25]
const SHOT_BODY := [25.0, 8.0, Vector3(0, 0.95, 0), 4.0]
const TINTS := [0.0, 0.5, 0.8, 1.0]

var repo: String
var body_material
var preset
var view
var outline_shader: Shader
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	preset = load(repo.path_join("godot/addons/creador/preset.gd"))
	outline_shader = body_material.OUTLINE_SHADER
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--outline="):
			outline_shader = Shader.new()
			outline_shader.code = FileAccess.get_file_as_string(argument.trim_prefix("--outline="))
	print("MEDIDA renderizador: ", RenderingServer.get_current_rendering_method())
	_check(body_material.OUTLINE_DEFAULTS["outline_tint"] == 0.0 and body_material.OUTLINE_DEFAULTS["face_line"] == 1.0,
		"por defecto, línea negra y del mismo grosor en la cara (el clásico no cambia)")
	await _check_sphere()
	await _check_view()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


## Esfera con toon_soft y contorno de 6 px; devuelve la imagen. face: canal A de las zonas (null = sin textura).
func _image(outline_params: Dictionary, face: Variant = null, garment := false) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 4)
	camera.fov = 30.0
	viewport.add_child(camera)
	viewport.add_child(DirectionalLight3D.new())
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var material := ShaderMaterial.new()
	material.shader = body_material.SOFT_SHADER
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("skin_color", SKIN)
	var outline := ShaderMaterial.new()
	outline.shader = outline_shader
	for name: String in body_material.OUTLINE_DEFAULTS:
		outline.set_shader_parameter(name, body_material.OUTLINE_DEFAULTS[name])
	outline.set_shader_parameter("skin_color", SKIN)
	outline.set_shader_parameter("garment_color", Color(0.2, 0.3, 0.8))
	outline.set_shader_parameter("show_garment", garment)
	material.set_shader_parameter("show_garment", garment)
	outline.set_shader_parameter("width_px", 6.0)
	if face != null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, face))
		outline.set_shader_parameter("skin_zones", ImageTexture.create_from_image(image))
	for name: String in outline_params:
		outline.set_shader_parameter(name, outline_params[name])
	material.next_pass = outline
	sphere.material_override = material
	viewport.add_child(sphere)
	for i in 4:
		await process_frame
	var shot := viewport.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return shot


func _line(image: Image) -> Color:
	return image.get_pixel(EDGE_X, SIZE / 2)


func _check_sphere() -> void:
	var black := _line(await _image({}))
	var tinted := _line(await _image({"outline_tint": 1.0}))
	var dressed := _line(await _image({"outline_tint": 1.0}, null, true))
	print("MEDIDA línea: negra %s, teñida de piel %s, teñida de prenda azul %s" % [_bytes(black), _bytes(tinted), _bytes(dressed)])
	_check(_distance(black, body_material.OUTLINE_DEFAULTS["outline_color"]) <= SAME, "tinte 0: la línea de siempre")
	_check(tinted.r > tinted.b + 0.05 and tinted.get_luminance() < SKIN.get_luminance() * 0.6 and tinted.a > 0.9,
		"tinte 1: la línea es del color de la piel, más oscura")
	_check(dressed.b > dressed.r + 0.05, "tinte 1 con la prenda: la línea es del color de la prenda")
	var thin := _line(await _image({"face_line": 0.0}, 0.0))
	var body := _line(await _image({"face_line": 0.0}, 1.0))
	var no_map := _line(await _image({"face_line": 0.0}))
	_check(thin.a < 0.1, "face_line 0 en la cara: sin línea (alfa %.2f)" % thin.a)
	_check(body.a > 0.9, "face_line 0 fuera de la cara: la línea sigue")
	_check(no_map.a > 0.9, "face_line 0 sin textura de zonas: la línea sigue")


func _check_view() -> void:
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	var mesh: MeshInstance3D = view.species.mesh
	var outline: ShaderMaterial = (mesh.material_override as ShaderMaterial).get_meta("outline")
	body_material.set_color(mesh, "skin_color", Color(0.3, 0.2, 0.1))
	_check(outline.get_shader_parameter("skin_color") == Color(0.3, 0.2, 0.1), "set_color llega al contorno")
	body_material.set_garment_visible(mesh, false)
	_check(outline.get_shader_parameter("show_garment") == false, "la prenda oculta llega al contorno")
	body_material.set_garment_visible(mesh, true)
	view.set_piece("makehuman", "short02", true)
	view.set_anime_style(true)
	outline = (mesh.material_override as ShaderMaterial).get_meta("outline")
	var piece: MeshInstance3D = view.pieces.values()[0]
	var piece_outline: ShaderMaterial = (piece.material_override as ShaderMaterial).get_meta("outline")
	_check(outline.get_shader_parameter("skin_color") == Color(0.3, 0.2, 0.1) and outline.get_shader_parameter("skin_zones") != null,
		"al pasar a anime, el contorno conserva el color y recibe las zonas")
	_check(is_equal_approx(piece_outline.get_shader_parameter("outline_tint"), body_material.SKIN_START["outline_tint"]),
		"la pieza lleva la línea teñida como el cuerpo")
	body_material.set_skin(mesh, "outline_tint", 0.2)
	view.sync_lines()
	_check(is_equal_approx(piece_outline.get_shader_parameter("outline_tint"), 0.2), "sync_lines copia el tinte a las piezas")
	view.set_anime_style(false)
	_check(piece_outline.get_shader_parameter("outline_tint") == 0.0 or not body_material.is_soft(piece),
		"vuelta al clásico: línea negra")
	view.set_piece("makehuman", "short02", false)
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheets()


func _make_sheets() -> void:
	var out := repo.path_join(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	var lines: Array[Image] = []
	for row: Dictionary in ROWS:
		await _dress(row, row["skin"])
		for tint: float in TINTS:
			body_material.set_skin(view.species.mesh, "outline_tint", tint)
			view.sync_lines()
			await _wait(4)
			lines.append(await _shot(SHOT_FACE))
	_save_sheet(lines, TINTS.size(), out.path_join("hoja_linea.png"))
	var colors: Array[Image] = []
	for skin: Color in SKINS:
		await _dress(ROWS[0], skin)
		colors.append(await _shot(SHOT_FACE))
	for skin: Color in SKINS:
		await _dress(ROWS[0], skin)
		colors.append(await _shot(SHOT_BODY))
	_save_sheet(colors, SKINS.size(), out.path_join("hoja_colores.png"))
	for file in ["hoja_linea.png", "hoja_colores.png"]:
		_check(FileAccess.file_exists(out.path_join(file)), "existe " + file)


## El preset, estilo anime con SKIN_START (lo que verá quien lo encienda) y la piel del color dado.
func _dress(row: Dictionary, skin: Color) -> void:
	var text := FileAccess.get_file_as_string(repo.path_join("godot/datos/humana/presets/%s.json" % row["preset"]))
	var loaded: Dictionary = preset.from_text(text, view.SPECIES, view.species.sliders)
	view.set_anime_style(false)
	preset.apply_look(view.species.mesh, loaded)
	view.set_values(loaded["valores"])
	for key: String in view.pieces.keys():
		view.set_piece(key.get_base_dir(), key.get_file(), false)
	for piece: Array in [row["hair"]] + CLOTHES:
		if view.set_piece(piece[0], piece[1], true):
			view.set_piece_color(String(piece[0]).path_join(piece[1]), row["hair_color"] if piece == row["hair"] else row["clothes"])
	view.set_anime_style(true)
	body_material.set_color(view.species.mesh, "skin_color", skin)
	body_material.set_color(view.species.mesh, "garment_color", row["clothes"])
	view.style.refresh()
	await _wait(10)


func _shot(shot: Array) -> Image:
	var camera = view.camera
	camera.yaw = shot[0]
	camera.pitch = shot[1]
	camera.zoom = 1.0
	camera.goal_target = shot[2]
	camera.target = shot[2]
	camera.goal_distance = shot[3]
	camera.fit_distance = shot[3]
	camera.distance = shot[3]
	camera.snap()
	await _wait(12)
	var image: Image = view.viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var cell := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	cell.fill(BACKGROUND)
	cell.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return cell


func _save_sheet(cells: Array[Image], columns: int, path: String) -> void:
	var rows := cells.size() / columns
	var sheet := Image.create(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % columns, i / columns) * CELL)
	sheet.save_png(path)


func _bytes(color: Color) -> String:
	return "(%d,%d,%d,%d)" % [color.r8, color.g8, color.b8, color.a8]


func _distance(a: Color, b: Color) -> int:
	return maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), absi(a.b8 - b.b8))


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	failures += 0 if ok else 1
	return ok


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
