extends SceneTree
# Paso X.7: cara sin escalón en la sien (StyleNormals.temple_blend) y umbral propio de la cara (face_light en toon_soft).
# Con temple_blend 0 las normales son las de antes; con más, el giro de la normal alrededor de la sien no da un salto.
# face_light solo actúa en la cara (canal A de skin_zones = 0) y la ilumina más; fuera de ella no cambia nada.
# Con ventana. En Forward+ guarda las hojas.
# Uso: (ulimit -v 4000000; timeout 600 godot [--rendering-method mobile] --path pruebas/godot -s probar_cara_x7.gd 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# Escribe en pruebas/capturas/cara_x7/: hoja_sien.png (perfil a tres cuartos; temple_blend 0 / 0,35 / 0,6) y
# hoja_luz_cara.png (face_light 0 / 0,15 / 0,3), con las 4 filas de SH.2 en estilo anime.
# Que detecta el fallo (en una copia): en StyleNormals.face, `r.z *= depth if offset.z > 0.0 else 1.0` siempre;
# en toon_soft, `edge_from = threshold;`.

const OUT_DIR := "pruebas/capturas/cara_x7"
const SIZE := 48
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const SKIN := Color(0.72, 0.50, 0.36)
const SAME := 1  # /255 PROVISIONAL
const KINK_DROP := 0.5  # PROVISIONAL: con 0,35, el salto del giro en la sien baja al menos a la mitad
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
const CLOTHES := [["overscore", "os_tank_top"], ["overscore", "os_golf_shorts"]]
const SHOT_SIDE := [55.0, 4.0, Vector3(0, 1.55, 0), 1.0]
const SHOT_FACE := [25.0, 4.0, Vector3(0, 1.55, 0), 1.25]
const TEMPLES := [0.0, 0.35, 0.6]
const FACE_LIGHTS := [0.0, 0.15, 0.3]

var repo: String
var body_material
var style_normals
var preset
var view
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	style_normals = load(repo.path_join("godot/addons/creador/style_normals.gd"))
	preset = load(repo.path_join("godot/addons/creador/preset.gd"))
	print("MEDIDA renderizador: ", RenderingServer.get_current_rendering_method())
	_check(style_normals.temple_blend == 0.35 and body_material.SOFT_DEFAULTS["face_light"] == 0.0,
		"temple_blend 0,35 (D54) y face_light 0 en el shader (el estilo anime parte de SKIN_START)")
	_check_temple()
	await _check_face_light()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheets()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


## Un arco horizontal alrededor de una cabeza (elipsoide), de la nuca a la cara: el mayor salto entre giros seguidos
## de la normal (en grados), junto a la sien.
func _kink(temple: float) -> float:
	var vertices := PackedVector3Array()
	var weights := PackedFloat32Array()
	var radii := Vector3(0.08, 0.11, 0.1)
	for i in 181:
		var angle := deg_to_rad(float(i))  # 0: nuca; 90: sien; 180: cara
		vertices.append(Vector3(radii.x * sin(angle), 0.0, -radii.z * cos(angle)))
		weights.append(1.0)
	for corner: Vector3 in [Vector3(-radii.x, 0, 0), Vector3(0, radii.y, 0), Vector3(0, -radii.y, 0)]:  # la caja entera
		vertices.append(corner)
		weights.append(1.0)
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var result: PackedVector3Array = style_normals.face(vertices, normals, weights, 1.0, style_normals.FACE_DEPTH, temple)
	var worst := 0.0
	for i in range(2, 181):
		var a := result[i - 2].angle_to(result[i - 1])
		var b := result[i - 1].angle_to(result[i])
		worst = maxf(worst, rad_to_deg(absf(b - a)))
	return worst


func _check_temple() -> void:
	var before := _kink(0.0)
	var after := _kink(0.35)
	print("MEDIDA salto del giro de la normal en la sien: temple_blend 0 → %.3f°, 0,35 → %.3f°, 0,6 → %.3f°" % [before, after, _kink(0.6)])
	_check(after <= before * KINK_DROP, "temple_blend 0,35: la sien sin escalón (%.3f° frente a %.3f°)" % [after, before])


## Esfera; la luz girada 87,13° (en el centro, dot(N, L) = threshold: la mitad del paso). face: canal A (0 = cara).
func _pixel(face: float, params := {}) -> Color:
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
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(0, 87.13, 0)
	viewport.add_child(light)
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var material := ShaderMaterial.new()
	material.shader = body_material.SOFT_SHADER
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("skin_color", SKIN)
	material.set_shader_parameter("show_garment", false)
	material.set_shader_parameter("rim_strength", 0.0)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, face))
	material.set_shader_parameter("skin_zones", ImageTexture.create_from_image(image))
	for name: String in params:
		material.set_shader_parameter(name, params[name])
	sphere.material_override = material
	viewport.add_child(sphere)
	for i in 4:
		await process_frame
	var shot := viewport.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return shot.get_pixel(SIZE / 2, SIZE / 2)


func _check_face_light() -> void:
	var face_off: Color = await _pixel(0.0)
	var face_on: Color = await _pixel(0.0, {"face_light": 0.3})
	var body_off: Color = await _pixel(1.0)
	var body_on: Color = await _pixel(1.0, {"face_light": 0.3})
	print("MEDIDA borde de la luz: cara %s → %s con face_light 0,3; cuerpo %s → %s" % [_bytes(face_off), _bytes(face_on),
		_bytes(body_off), _bytes(body_on)])
	_check(face_on.get_luminance() > face_off.get_luminance() + 0.02, "face_light: la cara recibe más luz")
	_check(_distance(body_off, body_on) <= SAME, "face_light: fuera de la cara no cambia (%d/255)" % _distance(body_off, body_on))


func _make_sheets() -> void:
	var out := repo.path_join(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	var sides: Array[Image] = []
	var faces: Array[Image] = []
	for row: Dictionary in ROWS:
		await _dress(row)
		for temple: float in TEMPLES:
			style_normals.temple_blend = temple
			view.style.refresh()
			await _wait(6)
			sides.append(await _shot(SHOT_SIDE))
		style_normals.temple_blend = 0.35
		view.style.refresh()
		for amount: float in FACE_LIGHTS:
			(view.species.mesh.material_override as ShaderMaterial).set_shader_parameter("face_light", amount)
			await _wait(4)
			faces.append(await _shot(SHOT_FACE))
		(view.species.mesh.material_override as ShaderMaterial).set_shader_parameter("face_light", 0.0)
	_save_sheet(sides, TEMPLES.size(), out.path_join("hoja_sien.png"))
	_save_sheet(faces, FACE_LIGHTS.size(), out.path_join("hoja_luz_cara.png"))
	for file in ["hoja_sien.png", "hoja_luz_cara.png"]:
		_check(FileAccess.file_exists(out.path_join(file)), "existe " + file)


func _dress(row: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(repo.path_join("godot/datos/humana/presets/%s.json" % row["preset"]))
	var loaded: Dictionary = preset.from_text(text, view.SPECIES, view.species.sliders)
	preset.apply_look(view.species.mesh, loaded)
	view.set_anime_style(true)
	view.set_values(loaded["valores"])
	body_material.set_color(view.species.mesh, "skin_color", row["skin"])
	body_material.set_color(view.species.mesh, "garment_color", row["clothes"])
	for key: String in view.pieces.keys():
		view.set_piece(key.get_base_dir(), key.get_file(), false)
	for piece: Array in [row["hair"]] + CLOTHES:
		if view.set_piece(piece[0], piece[1], true):
			view.set_piece_color(String(piece[0]).path_join(piece[1]), row["hair_color"] if piece == row["hair"] else row["clothes"])
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
	return "(%d,%d,%d)" % [color.r8, color.g8, color.b8]


func _distance(a: Color, b: Color) -> int:
	return maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), absi(a.b8 - b.b8))


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	failures += 0 if ok else 1
	return ok


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
