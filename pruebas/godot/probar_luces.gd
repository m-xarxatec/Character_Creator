extends SceneTree
# Paso SH.3: toon_soft con varias luces y con luz ambiente. SH.3a: las luces no se suman (manda la más fuerte, sin depender
# del orden), un contraluz no cambia la cara de delante y una omni se apaga con la distancia sin salto. SH.3b: el ambiente de
# la escena se suma plano, sin luz y sin ambiente nada brilla (el rim es luz) y unlit sigue exacto. Con una sola luz
# direccional y el ambiente del editor, el aspecto es el de SH.2 (referencia congelada en estilo/toon_soft_sh2.gdshader).
# Con ventana. En Forward+ además guarda las hojas.
# Uso: (ulimit -v 4000000; timeout 400 godot [--rendering-method mobile] --path pruebas/godot -s probar_luces.gd [-- --shader=<ruta> --ambiente-editor=<energía>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# --shader=<ruta>: usa el código de ese archivo en lugar de toon_soft (para romper una copia, nunca el núcleo).
# --ambiente-editor=<energía>: fija la energía de ambiente del BodyView después de crearlo (para romper).
# Escribe en pruebas/capturas/shader_sh3/ (columnas: A = SH.2, B = actual): hoja_cuerpo.png y hoja_cara.png (4 filas, una
# luz con sombra), hoja_contraluz.png (luz del editor + contraluz de la misma energía), hoja_omni.png (solo dos omni) y
# hoja_ambiente.png (solo B: luz del editor; solo ambiente 0,15; solo ambiente 0,4; sin luz y sin ambiente).
# Que detecta el fallo (sobre una copia, con --shader): light() con `DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(...)`;
# `DIFFUSE_LIGHT = max(DIFFUSE_LIGHT + full * lit, tone)`; `reach = 1.0`; `reach` sin LIGHT_IS_DIRECTIONAL;
# `render_mode ambient_light_disabled, ...`; el rim de vuelta en EMISSION; el rim sumado después del max();
# --ambiente-editor=0.4.

const OUT_DIR := "pruebas/capturas/shader_sh3"
const REFERENCE := "pruebas/godot/estilo/toon_soft_sh2.gdshader"
const SPHERE_SIZE := 48
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const SKIN := Color(0.72, 0.50, 0.36)  # piel media
const FRONT_STABLE := 1  # /255 PROVISIONAL: un contraluz no cambia la cara de delante
const STACK_TOLERANCE := 1  # /255 PROVISIONAL: dos luces de espalda = una
const ORDER_TOLERANCE := 1  # /255 PROVISIONAL: el orden de las luces no cambia el color
const OMNI_MONOTONE := 1  # /255 PROVISIONAL: la omni no sube al alejarse
const DARK_MAX := 1  # /255 PROVISIONAL: fuera de alcance, nada
const OMNI_EDGE_JUMP := 16  # /255 PROVISIONAL: salto entre 5,8 y 6,2 m
const AMBIENT_TOLERANCE := 3  # /255 PROVISIONAL: solo ambiente = to_srgb(to_linear(color) · energía)
const FLAT_TOLERANCE := 2  # /255 PROVISIONAL: ambiente de color, centro = arriba
const SUM_TOLERANCE := 3  # /255 PROVISIONAL: luz + ambiente = luz sola + ambiente solo (en lineal)
const RIM_TOLERANCE := 3  # /255 PROVISIONAL: rim con una luz de frente = el de SH.2
const DARK_SKIN := Color(0.20, 0.13, 0.10)  # para la suma: no satura
const RIM_X := 34  # columna del borde de la esfera (radio ≈ 11 px), fila central
const SAME_LOOK := 0.001  # PROVISIONAL: fracción de píxeles distintos con una sola luz direccional
const PIXEL_DIFF := 8.0 / 255.0
const OMNI_RANGE := 6.0
const OMNI_DISTANCES := [0.5, 2.0, 4.0, 5.0, 5.8, 6.2]
const OMNI_COLOR := Color(1.0, 0.72, 0.45)
const OMNIS := [[Vector3(-1.6, 1.9, 1.2), 3.0, 6.0], [Vector3(-1.2, 0.7, 0.6), 1.5, 5.0]]
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
const SHOT_BODY := [25.0, 8.0, Vector3(0, 0.95, 0), 4.0]
const SHOT_FACE := [25.0, 4.0, Vector3(0, 1.55, 0), 1.25]
const SHOT_OMNI := [0.0, 8.0, Vector3(0, 0.95, 0), 4.0]

var repo: String
var out: String
var body_material
var preset
var view
var reference: Shader
var reference_piece: Shader
var current: Shader
var current_piece: Shader
var editor_ambient := -1.0  # < 0: el del BodyView
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
	_load_shaders()
	await _check_lights()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheets()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


## A = SH.2 congelado; B = toon_soft del núcleo, o el de --shader. Cada uno con su copia de pieza (depth_pull).
func _load_shaders() -> void:
	reference = _shader(FileAccess.get_file_as_string(repo.path_join(REFERENCE)))
	reference_piece = _shader(reference.code.replace("void fragment()", body_material.PULL_CODE + "void fragment()"))
	current = body_material.SOFT_SHADER
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shader="):
			current = _shader(FileAccess.get_file_as_string(argument.trim_prefix("--shader=")))
			print("MEDIDA shader de --shader: ", argument.trim_prefix("--shader="))
		if argument.begins_with("--ambiente-editor="):
			editor_ambient = float(argument.trim_prefix("--ambiente-editor="))
	current_piece = _shader(current.code.replace("void fragment()", body_material.PULL_CODE + "void fragment()"))


func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


# --- Esfera: cada medida es una escena nueva con sus luces, creadas en el orden de la lista ---

## lights: [[tipo, energía, giro en Y o distancia]]: ["dir", 1.0, 0] luz de frente, ["dir", 1.0, 180] de espalda,
## ["omni", 1.0, 2.0] omni delante a 2 m de la superficie (alcance OMNI_RANGE, sin sombra).
## params: uniform distintos de los de la prueba; ambient: energía del ambiente blanco; sky: ambiente de cielo con degradado.
func _image(shader: Shader, lights: Array, params := {}, ambient := 0.0, sky := false) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SPHERE_SIZE, SPHERE_SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 4)
	camera.fov = 30.0
	viewport.add_child(camera)
	var world := WorldEnvironment.new()
	world.environment = _environment(ambient, sky)
	viewport.add_child(world)
	for data: Array in lights:
		viewport.add_child(_light(data))
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var material := ShaderMaterial.new()
	material.shader = shader
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("skin_color", SKIN)
	material.set_shader_parameter("show_garment", false)
	material.set_shader_parameter("ground_weight", 0.0)
	material.set_shader_parameter("rim_strength", 0.0)
	for name: String in params:
		material.set_shader_parameter(name, params[name])
	sphere.material_override = material
	viewport.add_child(sphere)
	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return image


func _pixel(shader: Shader, lights: Array, params := {}, ambient := 0.0, sky := false) -> Color:
	var image: Image = await _image(shader, lights, params, ambient, sky)
	return image.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2)


func _environment(ambient: float, sky: bool) -> Environment:
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = ambient
	if sky:
		var material := ProceduralSkyMaterial.new()
		material.sky_top_color = Color(0.4, 0.6, 1.0)
		material.sky_horizon_color = Color(0.8, 0.8, 0.8)
		material.ground_bottom_color = Color(0.1, 0.08, 0.06)
		material.ground_horizon_color = Color(0.5, 0.45, 0.4)
		environment.background_mode = Environment.BG_SKY
		environment.sky = Sky.new()
		environment.sky.sky_material = material
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	return environment


func _light(data: Array) -> Light3D:
	if data[0] == "omni":
		var omni := OmniLight3D.new()
		omni.position = Vector3(0, 0, 0.5 + data[2])
		omni.omni_range = OMNI_RANGE
		omni.light_energy = data[1]
		return omni
	var light := DirectionalLight3D.new()
	light.light_energy = data[1]
	light.rotation_degrees = Vector3(0, data[2], 0)
	return light


func _check_lights() -> void:
	var front: Color = await _pixel(current, [["dir", 1.0, 0]])
	var back: Color = await _pixel(current, [["dir", 1.0, 180]])
	var both: Color = await _pixel(current, [["dir", 1.0, 0], ["dir", 1.0, 180]])
	_compare(both, front, FRONT_STABLE, "luz de frente + contraluz: la cara de delante no cambia")
	var two_back: Color = await _pixel(current, [["dir", 1.0, 180], ["dir", 1.0, 180]])
	_compare(two_back, back, STACK_TOLERANCE, "dos luces de espalda = una (los suelos de sombra no se suman)")
	var old_back: Color = await _pixel(reference, [["dir", 1.0, 180]])
	_compare(back, old_back, 1, "una luz de espalda da la sombra de SH.2")
	var main_first: Color = await _pixel(current, [["dir", 1.0, 0], ["dir", 0.5, 180]])
	var back_first: Color = await _pixel(current, [["dir", 0.5, 180], ["dir", 1.0, 0]])
	_compare(main_first, back_first, ORDER_TOLERANCE, "principal + contraluz: mismo color en los dos órdenes")
	_compare(main_first, front, ORDER_TOLERANCE, "principal + contraluz = principal sola")
	var strong: Color = await _pixel(current, [["dir", 0.8, 0]])
	var low_first: Color = await _pixel(current, [["dir", 0.4, 0], ["dir", 0.8, 0]])
	var high_first: Color = await _pixel(current, [["dir", 0.8, 0], ["dir", 0.4, 0]])
	_compare(low_first, strong, ORDER_TOLERANCE, "dos luces de frente (0,4 y 0,8): manda la más fuerte")
	_compare(high_first, strong, ORDER_TOLERANCE, "dos luces de frente, en el otro orden: manda la más fuerte")
	await _check_omni()
	await _check_ambient()


func _check_omni() -> void:
	var values: Array[int] = []
	var old: Array[int] = []
	for distance: float in OMNI_DISTANCES:
		values.append(_luma(await _pixel(current, [["omni", 1.0, distance]])))
		old.append(_luma(await _pixel(reference, [["omni", 1.0, distance]])))
	print("MEDIDA omni luminancia (0,5 2 4 5 5,8 6,2 m): actual=%s SH.2=%s" % [values, old])
	var rise := 0
	for i in range(1, values.size()):
		rise = maxi(rise, values[i] - values[i - 1])
	_check(rise <= OMNI_MONOTONE, "la omni no sube al alejarse (sube %d/255)" % rise)
	_check(values[-1] <= DARK_MAX, "la omni fuera de alcance no ilumina (%d/255)" % values[-1])
	var jump: int = values[-2] - values[-1]
	_check(jump <= OMNI_EDGE_JUMP, "la omni se apaga sin salto al llegar a su alcance (salto %d/255)" % jump)


# --- SH.3b: ambiente ---

func _check_ambient() -> void:
	var dark: Image = await _image(current, [], {"rim_strength": 1.0, "rim_width": 1.0})
	var brightest := 0
	for y in SPHERE_SIZE:
		for x in SPHERE_SIZE:
			var p := dark.get_pixel(x, y)
			if p.a > 0.0:
				brightest = maxi(brightest, maxi(maxi(p.r8, p.g8), p.b8))
	_check(brightest <= DARK_MAX, "sin luz y sin ambiente nada brilla, ni el rim (máx. %d/255)" % brightest)
	var expected := _srgb(_linear(SKIN) * 0.4)
	var ambient: Image = await _image(current, [], {}, 0.4)
	var center := ambient.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2)
	_compare(center, expected, AMBIENT_TOLERANCE, "solo ambiente blanco 0,4: to_srgb(to_linear(color)·0,4)")
	var top := ambient.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2 - 8)
	_compare(center, top, FLAT_TOLERANCE, "ambiente de color plano: centro = arriba")
	var sky: Image = await _image(current, [], {}, 1.0, true)
	print("MEDIDA ambiente de cielo (no es plano): centro=%s arriba=%s abajo=%s" % [_bytes(sky.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2)),
		_bytes(sky.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2 - 8)), _bytes(sky.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2 + 8))])
	var dark_skin := {"skin_color": DARK_SKIN}
	var both: Color = await _pixel(current, [["dir", 1.0, 0]], dark_skin, 0.4)
	var light_only: Color = await _pixel(current, [["dir", 1.0, 0]], dark_skin)
	var ambient_only: Color = await _pixel(current, [], dark_skin, 0.4)
	_compare(both, _srgb(_linear(light_only) + _linear(ambient_only)), SUM_TOLERANCE, "luz + ambiente = luz sola + ambiente solo")
	var exact: Color = await _pixel(current, [], {"unlit": true}, 1.0)
	_compare(exact, SKIN, 1, "unlit con ambiente 1: color exacto")
	var rim := {"rim_strength": 0.3, "rim_width": 0.8}
	var new_rim: Image = await _image(current, [["dir", 1.0, 0]], rim)
	var old_rim: Image = await _image(reference, [["dir", 1.0, 0]], rim)
	_compare(new_rim.get_pixel(RIM_X, SPHERE_SIZE / 2), old_rim.get_pixel(RIM_X, SPHERE_SIZE / 2), RIM_TOLERANCE,
		"rim con una luz de frente: el de SH.2")
	var main_first: Image = await _image(current, [["dir", 1.0, 0], ["dir", 0.5, 180]], rim)
	var back_first: Image = await _image(current, [["dir", 0.5, 180], ["dir", 1.0, 0]], rim)
	_compare(main_first.get_pixel(RIM_X, SPHERE_SIZE / 2), back_first.get_pixel(RIM_X, SPHERE_SIZE / 2), ORDER_TOLERANCE,
		"rim con principal + contraluz: mismo color en los dos órdenes")


func _linear(color: Color) -> Color:
	return color.srgb_to_linear()


func _srgb(color: Color) -> Color:
	return color.linear_to_srgb()


func _luma(color: Color) -> int:
	return roundi(color.get_luminance() * 255.0)


func _compare(a: Color, b: Color, limit: int, text: String) -> void:
	var difference := _distance(a, b)
	print("MEDIDA %s: %s frente a %s (%d/255)" % [text, _bytes(a), _bytes(b), difference])
	_check(difference <= limit, "%s (%d/255)" % [text, difference])


func _bytes(color: Color) -> String:
	return "(%d,%d,%d)" % [color.r8, color.g8, color.b8]


func _distance(a: Color, b: Color) -> int:
	return maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), absi(a.b8 - b.b8))


# --- Hojas: A = SH.2, B = actual ---

func _make_sheets() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	body_material.soft_enabled = true  # antes de crear BodyView
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	if editor_ambient >= 0.0:
		_environment_of_view().ambient_light_energy = editor_ambient
	_set_shadow()
	var sheets := {"hoja_cuerpo": [] as Array[Image], "hoja_cara": [] as Array[Image]}
	for row: Dictionary in ROWS:
		if not await _dress(row):
			return
		for use_current in [false, true]:
			_use(use_current)
			await _wait(4)
			sheets["hoja_cuerpo"].append(await _shot(SHOT_BODY))
			sheets["hoja_cara"].append(await _shot(SHOT_FACE))
	for sheet: String in sheets:
		_save_sheet(sheets[sheet], ROWS.size(), sheet + ".png")
	var worst := 0.0
	for r in ROWS.size():
		for sheet: String in sheets:
			var diff := _different(sheets[sheet][r * 2], sheets[sheet][r * 2 + 1])
			worst = maxf(worst, diff)
			print("MEDIDA %s fila %d (%s): píxeles distintos A/B = %.4f %%" % [sheet, r, ROWS[r]["preset"], diff * 100.0])
	_check(worst <= SAME_LOOK, "una luz direccional con sombra y el ambiente del editor (%.2f): el aspecto es el de SH.2 (peor %.4f %%)" % [
		_environment_of_view().ambient_light_energy, worst * 100.0])
	await _dress(ROWS[0])
	await _measure_old_ambient()
	await _save_pair(await _backlit(), "hoja_contraluz.png")
	await _save_pair(await _omni(), "hoja_omni.png")
	await _save_ambient_sheet()


func _environment_of_view() -> Environment:
	return (view.viewport.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment


## Lo que se evita al bajar el ambiente del editor a 0: con el 0,4 de antes, B se aclara frente a A.
func _measure_old_ambient() -> void:
	var environment := _environment_of_view()
	var energy := environment.ambient_light_energy
	var cells: Array[Image] = []
	environment.ambient_light_energy = 0.4
	for use_current in [false, true]:
		_use(use_current)
		await _wait(4)
		cells.append(await _shot(SHOT_BODY))
	environment.ambient_light_energy = energy
	print("MEDIDA con el ambiente viejo del editor (0,4): píxeles distintos A/B = %.4f %%" % (_different(cells[0], cells[1]) * 100.0))


## Fila anime, columna B: luz del editor; solo ambiente 0,15; solo ambiente 0,4; sin luz y sin ambiente.
func _save_ambient_sheet() -> void:
	var environment := _environment_of_view()
	var energy := environment.ambient_light_energy
	_use(true)
	var cells: Array[Image] = []
	for setting: Array in [[true, energy], [false, 0.15], [false, 0.4], [false, 0.0]]:
		view.light.visible = setting[0]
		environment.ambient_light_energy = setting[1]
		await _wait(4)
		cells.append(await _shot(SHOT_BODY))
	view.light.visible = true
	environment.ambient_light_energy = energy
	_save_sheet(cells, 1, "hoja_ambiente.png", 4)
	_check(FileAccess.file_exists(out.path_join("hoja_ambiente.png")), "existe hoja_ambiente.png")


func _save_pair(cells: Array[Image], file: String) -> void:
	_save_sheet(cells, 1, file)
	_check(FileAccess.file_exists(out.path_join(file)), "existe " + file)


## Luz del editor y una segunda direccional de la misma energía, girada 180°.
func _backlit() -> Array[Image]:
	var back := DirectionalLight3D.new()
	back.rotation_degrees = view.light.rotation_degrees + Vector3(0, 180, 0)
	view.viewport.add_child(back)
	var cells: Array[Image] = []
	for use_current in [false, true]:
		_use(use_current)
		await _wait(4)
		cells.append(await _shot(SHOT_BODY))
	back.queue_free()
	return cells


## Solo las dos omni de la escena tipo mazmorra de SH.1.
func _omni() -> Array[Image]:
	var omnis: Array[OmniLight3D] = []
	for data: Array in OMNIS:
		var omni := OmniLight3D.new()
		omni.position = data[0]
		omni.light_energy = data[1]
		omni.omni_range = data[2]
		omni.light_color = OMNI_COLOR
		view.viewport.add_child(omni)
		omnis.append(omni)
	view.light.visible = false
	var cells: Array[Image] = []
	for use_current in [false, true]:
		_use(use_current)
		await _wait(4)
		cells.append(await _shot(SHOT_OMNI))
	view.light.visible = true
	for omni in omnis:
		omni.queue_free()
	return cells


## Preset, colores y piezas de la fila, con toon_soft puesto (BodyView copia el acabado solo de su propio shader).
func _dress(row: Dictionary) -> bool:
	for mesh: MeshInstance3D in _meshes():
		(mesh.material_override as ShaderMaterial).shader = body_material.piece_shader() if mesh != view.species.mesh else body_material.SOFT_SHADER
	var text := FileAccess.get_file_as_string(repo.path_join("godot/datos/humana/presets/%s.json" % row["preset"]))
	var loaded: Dictionary = preset.from_text(text, view.SPECIES, view.species.sliders)
	if loaded["error"]:
		return _check(false, "preset " + row["preset"] + ": " + str(loaded["error"]))
	preset.apply_look(view.species.mesh, loaded)
	view.set_values(loaded["valores"])
	body_material.set_color(view.species.mesh, "skin_color", row["skin"])
	body_material.set_color(view.species.mesh, "garment_color", row["clothes"])
	if not _put_piece(row["hair"], row["hair_color"]):
		return false
	for piece: Array in CLOTHES:
		if not _put_piece(piece, row["clothes"]):
			return false
	view.style.refresh()
	await _wait(10)
	return true


func _put_piece(piece: Array, color: Color) -> bool:
	var placed: bool = view.set_piece(piece[0], piece[1], true)
	if placed:
		view.set_piece_color(String(piece[0]).path_join(piece[1]), color)
	return placed or _check(false, "pieza %s/%s" % piece)


func _meshes() -> Array:
	var list: Array = [view.species.mesh]
	list.append_array(view.pieces.values())
	return list


## Los valores de la base de SH.1 (el preset trae los del MVP) y el shader de la columna.
func _use(use_current: bool) -> void:
	for mesh: MeshInstance3D in _meshes():
		var material: ShaderMaterial = mesh.material_override
		var piece: bool = mesh != view.species.mesh
		if use_current:
			material.shader = current_piece if piece else current
		else:
			material.shader = reference_piece if piece else reference
		for key: String in body_material.SOFT_DEFAULTS:  # SH.7: la vista arranca con la piel anime; aquí, la base de SH.2
			if not key in ["skin_color", "garment_color", "show_garment", "unlit"]:
				material.set_shader_parameter(key, body_material.SOFT_DEFAULTS[key])
		var outline := material.get_meta("outline") as ShaderMaterial
		outline.set_shader_parameter("width_px", 1.25)
		outline.set_shader_parameter("outline_tint", 0.0)
		outline.set_shader_parameter("face_line", 1.0)


func _set_shadow() -> void:
	view.light.shadow_enabled = true
	view.light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	view.light.directional_shadow_max_distance = 6.0
	view.light.shadow_bias = 0.03
	view.light.shadow_normal_bias = 1.0


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


func _different(a: Image, b: Image) -> float:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), absf(p.b - q.b)) > PIXEL_DIFF:
				count += 1
	return float(count) / (a.get_width() * a.get_height())


## `columns` columnas (por defecto A y B) y `rows` filas.
func _save_sheet(cells: Array[Image], rows: int, file: String, columns := 2) -> void:
	var sheet := Image.create(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % columns, i / columns) * CELL)
	sheet.save_png(out.path_join(file))


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	failures += 0 if ok else 1
	return ok


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
