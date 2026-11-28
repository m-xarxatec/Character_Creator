extends SceneTree
# Paso SH.6b: banda de brillo del pelo en toon_soft. Sale a la altura hair_band_height (dirección desde el centro de la
# cabeza), no en el resto, no en la sombra; con fuerza 0 no hay nada. En la vista: solo las piezas de pelo la llevan
# (con la fuerza hair_band de la piel del cuerpo), no la piel ni la ropa, y hair_head sigue a la cabeza.
# Con ventana. En Forward+ guarda la hoja.
# Uso: (ulimit -v 4000000; timeout 900 godot [--rendering-method mobile] --path pruebas/godot -s probar_pelo.gd [-- --shader=<ruta>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# Escribe pruebas/capturas/shader_pelo/hoja_pelo.png: filas = 2 peinados (MakeHuman, Quaternius) × frente, tres
# cuartos y perfil; columnas = hair_band 0 / 0,6 / 1,2.
# Que detecta el fallo (en una copia): la banda sin `* lit`; `float off = abs(normalize(local).y);` (altura fija).

const OUT_DIR := "pruebas/capturas/shader_pelo"
const SIZE := 96
const BAND_Y := 33  # fila de la esfera donde la dirección desde el centro tiene y ≈ 0,55 (medido: la banda ocupa las filas 32–35)
const CELL := Vector2i(420, 420)
const BACKGROUND := Color8(199, 202, 204)
const HAIR := Color(0.20, 0.30, 0.55)
const SAME := 1  # /255 PROVISIONAL
const BAND_MIN := 0.04  # PROVISIONAL: con fuerza 1, la banda sube la luminancia al menos esto
const STYLES := [["makehuman", "toigo_blunt_bob_with_bangs", Color(0.32, 0.20, 0.14)], ["quaternius", "hair_long", Color(0.85, 0.75, 0.55)]]
const SHOTS := [[0.0, 4.0], [35.0, 4.0], [90.0, 4.0]]
const STRENGTHS := [0.0, 0.6, 1.2]

var repo: String
var body_material
var preset
var view
var current: Shader
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	preset = load(repo.path_join("godot/addons/creador/preset.gd"))
	current = body_material.SOFT_SHADER
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shader="):
			current = Shader.new()
			current.code = FileAccess.get_file_as_string(argument.trim_prefix("--shader="))
	print("MEDIDA renderizador: ", RenderingServer.get_current_rendering_method())
	_check(body_material.SOFT_DEFAULTS["hair_band_strength"] == 0.0, "hair_band_strength a 0 por defecto en el shader")
	await _check_sphere()
	await _check_view()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


## Esfera de «pelo» con el centro de la cabeza en su centro (hair_head = identidad). yaw: giro de la luz.
func _image(yaw: float, strength: float) -> Image:
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
	light.rotation_degrees = Vector3(0, yaw, 0)
	viewport.add_child(light)
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var material := ShaderMaterial.new()
	material.shader = current
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("skin_color", HAIR)
	material.set_shader_parameter("show_garment", false)
	material.set_shader_parameter("rim_strength", 0.0)
	material.set_shader_parameter("hair_band_strength", strength)
	sphere.material_override = material
	viewport.add_child(sphere)
	for i in 4:
		await process_frame
	var shot := viewport.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return shot


func _check_sphere() -> void:
	var off: Image = await _image(0.0, 0.0)
	var on: Image = await _image(0.0, 1.0)
	var profile: Array[int] = []
	for y in range(20, 50):
		profile.append(roundi((on.get_pixel(SIZE / 2, y).get_luminance() - off.get_pixel(SIZE / 2, y).get_luminance()) * 255.0))
	print("MEDIDA subida de la banda por fila (20–49): ", profile)
	var band_off := off.get_pixel(SIZE / 2, BAND_Y)
	var band_on := on.get_pixel(SIZE / 2, BAND_Y)
	print("MEDIDA banda: sin %s, con %s; centro sin %s, con %s" % [_bytes(band_off), _bytes(band_on),
		_bytes(off.get_pixel(SIZE / 2, SIZE / 2)), _bytes(on.get_pixel(SIZE / 2, SIZE / 2))])
	_check(band_on.get_luminance() >= band_off.get_luminance() + BAND_MIN, "la banda aclara el pelo a su altura")
	_check(_distance(off.get_pixel(SIZE / 2, SIZE / 2), on.get_pixel(SIZE / 2, SIZE / 2)) <= SAME,
		"fuera de su altura, nada (%d/255)" % _distance(off.get_pixel(SIZE / 2, SIZE / 2), on.get_pixel(SIZE / 2, SIZE / 2)))
	var dark_off: Image = await _image(180.0, 0.0)
	var dark_on: Image = await _image(180.0, 1.0)
	var difference := _distance(dark_off.get_pixel(SIZE / 2, BAND_Y), dark_on.get_pixel(SIZE / 2, BAND_Y))
	_check(difference <= SAME, "en la sombra, sin banda (%d/255)" % difference)


func _check_view() -> void:
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	view.set_piece(STYLES[0][0], STYLES[0][1], true)
	view.set_piece("overscore", "os_tank_top", true)
	view.set_anime_style(true)
	await _wait(3)
	var hair_mesh: MeshInstance3D = view.pieces[String(STYLES[0][0]).path_join(STYLES[0][1])]
	var shirt: MeshInstance3D = view.pieces["overscore/os_tank_top"]
	var strength := func(mesh: MeshInstance3D) -> float:
		return (mesh.material_override as ShaderMaterial).get_shader_parameter("hair_band_strength")
	_check(is_equal_approx(strength.call(hair_mesh), body_material.SKIN_START["hair_band"]), "el pelo lleva la banda (hair_band)")
	_check(strength.call(shirt) == 0.0 and strength.call(view.species.mesh) == 0.0, "la ropa y la piel no la llevan")
	var head: Transform3D = (hair_mesh.material_override as ShaderMaterial).get_shader_parameter("hair_head")
	var center: Vector3 = head.affine_inverse().origin
	print("MEDIDA centro de la cabeza para la banda: ", center)
	_check(center.y > 1.5 and center.y < 1.7, "hair_head: el centro de la cabeza está a la altura de la cabeza")
	body_material.set_skin(view.species.mesh, "hair_band", 1.5)
	view.sync_lines()
	_check(is_equal_approx(strength.call(hair_mesh), 1.5), "mover Brillo del pelo llega al pelo")
	view.set_anime_style(false)
	_check(not body_material.is_soft(hair_mesh), "vuelta al clásico: el pelo vuelve al toon clásico")
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheet()


func _make_sheet() -> void:
	var out := repo.path_join(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	var cells: Array[Image] = []
	for style: Array in STYLES:
		for key: String in view.pieces.keys():
			view.set_piece(key.get_base_dir(), key.get_file(), false)
		view.set_anime_style(false)
		view.set_piece(style[0], style[1], true)
		view.set_piece_color(String(style[0]).path_join(style[1]), style[2])
		view.set_anime_style(true)
		body_material.set_color(view.species.mesh, "skin_color", Color(0.96, 0.80, 0.70))
		await _wait(8)
		for shot: Array in SHOTS:
			for amount: float in STRENGTHS:
				body_material.set_skin(view.species.mesh, "hair_band", amount)
				view.sync_lines()
				await _wait(3)
				cells.append(await _shot(shot))
	var sheet := Image.create(CELL.x * STRENGTHS.size(), CELL.y * cells.size() / STRENGTHS.size(), false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % STRENGTHS.size(), i / STRENGTHS.size()) * CELL)
	sheet.save_png(out.path_join("hoja_pelo.png"))
	_check(FileAccess.file_exists(out.path_join("hoja_pelo.png")), "existe hoja_pelo.png")


func _shot(shot: Array) -> Image:
	var camera = view.camera
	camera.yaw = shot[0]
	camera.pitch = shot[1]
	camera.zoom = 1.0
	camera.goal_target = Vector3(0, 1.58, 0)
	camera.target = Vector3(0, 1.58, 0)
	camera.goal_distance = 0.9
	camera.fit_distance = 0.9
	camera.distance = 0.9
	camera.snap()
	await _wait(12)
	var image: Image = view.viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var cell := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	cell.fill(BACKGROUND)
	cell.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return cell


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
