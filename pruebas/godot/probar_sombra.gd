extends SceneTree
# Paso SH.4: sombra proyectada en toon_soft. La sombra nunca baja del color de sombra calculado; con shadow_receive 0
# desaparece; face_shadow_receive solo actúa en la cara (canal A de skin_zones); el contorno no agranda la sombra
# (IN_SHADOW_PASS); la luz del editor proyecta sombra solo en estilo anime. Con ventana. En Forward+ guarda las hojas.
# Uso: (ulimit -v 4000000; timeout 600 godot [--rendering-method mobile] --path pruebas/godot -s probar_sombra.gd [-- --shader=<ruta>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# Escribe en pruebas/capturas/shader_sombra/: hoja_cara.png (4 filas; A sin sombra, B con sombra, C cara 0,5, D cara 0)
# y hoja_borde.png (primer plano del cuello y el flequillo; blur 0 / 1 / 2 y PSSM de 2 cortes con blur 1).
# Que detecta el fallo (en una copia, con --shader): `lit *= smoothstep(0.15, 0.85, ATTENUATION);` (sin receive);
# `receive = shadow_receive;` en toon_soft (sin la cara). En outline.gdshader: ensanchar también en IN_SHADOW_PASS.

const OUT_DIR := "pruebas/capturas/shader_sombra"
const SIZE := 96
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const SKIN := Color(0.72, 0.50, 0.36)
const SAME := 1  # /255 PROVISIONAL
const SHADE_TOLERANCE := 2  # /255 PROVISIONAL: tapado = luz de espalda (color de sombra calculado)
const OUTLINE_GROWTH := 0.002  # PROVISIONAL: la sombra con contorno de 10 px crece como mucho esto (fracción; con el contorno viejo, +0,012)
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
const SHOT_FACE := [25.0, 4.0, Vector3(0, 1.55, 0), 1.25]
const SHOT_EDGE := [35.0, 0.0, Vector3(0, 1.45, 0), 0.6]
const FACE_COLUMNS := [{"shadow": false}, {}, {"face_shadow_receive": 0.5}, {"face_shadow_receive": 0.0}]
const EDGE_COLUMNS := [{"blur": 0.0}, {"blur": 1.0}, {"blur": 2.0}, {"blur": 1.0, "pssm": true}]

var repo: String
var out: String
var body_material
var preset
var view
var current: Shader
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	out = repo.path_join(OUT_DIR)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	preset = load(repo.path_join("godot/addons/creador/preset.gd"))
	print("MEDIDA renderizador: ", RenderingServer.get_current_rendering_method())
	current = body_material.SOFT_SHADER
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shader="):
			current = Shader.new()
			current.code = FileAccess.get_file_as_string(argument.trim_prefix("--shader="))
	_check(body_material.SOFT_DEFAULTS["shadow_receive"] == 1.0 and body_material.SOFT_DEFAULTS["face_shadow_receive"] == 1.0,
		"shadow_receive y face_shadow_receive a 1 por defecto (el aspecto de SH.3)")
	await _check_receive()
	await _check_outline()
	await _check_view()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


# --- Esfera con una caja que solo proyecta sombra sobre su centro ---

## El píxel central. yaw: giro de la luz (0 de frente). blocked: caja delante. face: canal A de las zonas (0 = cara).
func _pixel(yaw: float, params := {}, blocked := false, face := 1.0) -> Color:
	var viewport := _viewport()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(0, yaw, 0)
	light.shadow_enabled = true
	viewport.add_child(light)
	if blocked:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.scale = Vector3(0.3, 0.3, 0.05)
		box.position = Vector3(0, 0, 1.5)
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		viewport.add_child(box)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, face))
	var all := {"skin_zones": ImageTexture.create_from_image(image)}
	all.merge(params, true)
	viewport.add_child(_sphere(Vector3.ZERO, 0.5, all, 0.0))
	return (await _render(viewport)).get_pixel(SIZE / 2, SIZE / 2)


func _viewport() -> SubViewport:
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
	return viewport


## Esfera con toon_soft (y contorno de outline_px píxeles si es > 0).
func _sphere(at: Vector3, radius: float, params: Dictionary, outline_px: float) -> MeshInstance3D:
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	sphere.mesh = mesh
	sphere.position = at
	var material := ShaderMaterial.new()
	material.shader = current
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("skin_color", SKIN)
	material.set_shader_parameter("show_garment", false)
	material.set_shader_parameter("ground_weight", 0.0)
	material.set_shader_parameter("rim_strength", 0.0)
	for name: String in params:
		material.set_shader_parameter(name, params[name])
	if outline_px > 0.0:
		var outline := ShaderMaterial.new()
		outline.shader = body_material.OUTLINE_SHADER
		outline.set_shader_parameter("width_px", outline_px)
		material.next_pass = outline
	sphere.material_override = material
	return sphere


func _render(viewport: SubViewport) -> Image:
	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return image


func _check_receive() -> void:
	var lit: Color = await _pixel(0.0)
	var shade: Color = await _pixel(180.0)
	var blocked: Color = await _pixel(0.0, {}, true)
	print("MEDIDA luz=%s sombra calculada=%s tapado=%s" % [_bytes(lit), _bytes(shade), _bytes(blocked)])
	_check(_distance(blocked, shade) <= SHADE_TOLERANCE, "tapado = color de sombra calculado (%d/255)" % _distance(blocked, shade))
	_check(blocked.get_luminance() >= shade.get_luminance() - 1.0 / 255.0, "la sombra nunca baja del color de sombra calculado")
	var none: Color = await _pixel(0.0, {"shadow_receive": 0.0}, true)
	_check(_distance(none, lit) <= SAME, "shadow_receive 0: la sombra desaparece (%d/255)" % _distance(none, lit))
	var half: Color = await _pixel(0.0, {"shadow_receive": 0.5}, true)
	_check(half.get_luminance() > blocked.get_luminance() and half.get_luminance() < lit.get_luminance(),
		"shadow_receive 0,5: entre la sombra y la luz")
	var face: Color = await _pixel(0.0, {"face_shadow_receive": 0.0}, true, 0.0)
	_check(_distance(face, lit) <= SAME, "face_shadow_receive 0 en la cara: sin sombra (%d/255)" % _distance(face, lit))
	var body: Color = await _pixel(0.0, {"face_shadow_receive": 0.0}, true, 1.0)
	_check(_distance(body, blocked) <= SAME, "face_shadow_receive 0 fuera de la cara: la sombra sigue (%d/255)" % _distance(body, blocked))


## Una esfera pequeña con contorno proyecta sombra sobre una grande detrás: el contorno no la agranda.
func _check_outline() -> void:
	var shares: Array[float] = []
	for outline_px: float in [0.0, 10.0]:
		var viewport := _viewport()
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = 8.0
		viewport.add_child(light)
		viewport.add_child(_sphere(Vector3(0, 0, -1.0), 1.0, {}, 0.0))
		var blocker := _sphere(Vector3(0.35, 0.35, 1.4), 0.12, {}, outline_px)
		blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY  # solo su sombra cuenta
		viewport.add_child(blocker)
		var image: Image = await _render(viewport)
		var dark := 0
		var inside := 0
		for y in SIZE:
			for x in SIZE:
				var p := image.get_pixel(x, y)
				if p.a > 0.0 and Vector2(x - SIZE / 2.0, y - SIZE / 2.0).length() < SIZE * 0.2:
					inside += 1
					dark += 1 if p.get_luminance() < 0.4 else 0
		shares.append(float(dark) / maxi(inside, 1))
	print("MEDIDA sombra de la esfera pequeña: sin contorno %.4f, con contorno de 10 px %.4f" % shares)
	_check(shares[0] > 0.0, "la esfera pequeña proyecta sombra")
	_check(shares[1] - shares[0] <= OUTLINE_GROWTH, "el contorno no agranda la sombra (+%.4f)" % (shares[1] - shares[0]))


# --- La vista: sombra solo en estilo anime, coste y hojas ---

func _check_view() -> void:
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	_check(view.light.shadow_enabled, "SH.7: el personaje nuevo es anime y la luz del editor proyecta sombra")
	view.set_anime_style(false)
	_check(not view.light.shadow_enabled, "estilo clásico: la luz del editor no proyecta sombra")
	view.set_anime_style(true)
	_check(view.light.shadow_enabled, "estilo anime: la luz del editor proyecta sombra")
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	await _dress(ROWS[0])
	await _measure_cost()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheets()
	view.set_anime_style(false)
	_check(not view.light.shadow_enabled, "vuelta al clásico: sin sombra")


## Tiempo medio por fotograma con y sin sombra (solo orientativo en esta máquina).
func _measure_cost() -> void:
	var times := []
	for on: bool in [false, true]:
		view.light.shadow_enabled = on
		await _wait(10)
		var start := Time.get_ticks_usec()
		await _wait(60)
		times.append((Time.get_ticks_usec() - start) / 60000.0)
	view.light.shadow_enabled = true
	print("MEDIDA %s ms por fotograma: sin sombra %.2f, con sombra %.2f" % [RenderingServer.get_current_rendering_method(), times[0], times[1]])


func _make_sheets() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var faces: Array[Image] = []
	for row: Dictionary in ROWS:
		await _dress(row)
		for column: Dictionary in FACE_COLUMNS:
			view.light.shadow_enabled = column.get("shadow", true)
			body_material.set_finish(view.species.mesh, "softness", body_material.SOFT_DEFAULTS["softness"])
			(view.species.mesh.material_override as ShaderMaterial).set_shader_parameter("face_shadow_receive",
				column.get("face_shadow_receive", 1.0))
			await _wait(4)
			faces.append(await _shot(SHOT_FACE))
	(view.species.mesh.material_override as ShaderMaterial).set_shader_parameter("face_shadow_receive", 1.0)
	view.light.shadow_enabled = true
	_save_sheet(faces, FACE_COLUMNS.size(), "hoja_cara.png")
	var edges: Array[Image] = []
	for row: Dictionary in [ROWS[0], ROWS[2]]:
		await _dress(row)
		for column: Dictionary in EDGE_COLUMNS:
			view.light.shadow_blur = column["blur"]
			view.light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if column.get("pssm", false) \
				else DirectionalLight3D.SHADOW_ORTHOGONAL
			await _wait(4)
			edges.append(await _shot(SHOT_EDGE))
	view.light.shadow_blur = view.SHADOW["blur"]
	view.light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_save_sheet(edges, EDGE_COLUMNS.size(), "hoja_borde.png")
	for file in ["hoja_cara.png", "hoja_borde.png"]:
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


func _save_sheet(cells: Array[Image], columns: int, file: String) -> void:
	var rows := cells.size() / columns
	var sheet := Image.create(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % columns, i / columns) * CELL)
	sheet.save_png(out.path_join(file))


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
