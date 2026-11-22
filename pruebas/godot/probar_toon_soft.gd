extends SceneTree
# Paso SH.2: toon_soft.gdshader en el núcleo (BodyMaterial.soft_enabled, apagado por defecto) y su sombra calculada (D48).
# Comprueba el interruptor, los valores por defecto contra los `uniform` y los colores de luz y sombra sobre una esfera con
# una luz (la luz de frente da la parte iluminada; de espaldas, la sombra pura). Con ventana. En Forward+ además guarda la hoja.
# Uso: (ulimit -v 4000000; timeout 300 godot [--rendering-method mobile] --path pruebas/godot -s probar_toon_soft.gd 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# Escribe en pruebas/capturas/shader_sh2/: hoja_cuerpo.png y hoja_cara.png (filas: anime, femenino, masculino, anime fantasía;
# columnas: A = anime de SH.1 con tinte fijo, B = toon_soft con sombra calculada). La hoja solo se guarda en Forward+.
# Que detecta el fallo: `soft_enabled := true` por defecto; multiplicar shade_ratio por vec3(0.83, 0.48, 0.48);
# SHADE_VALUE_DARK = 0.70.

const OUT_DIR := "pruebas/capturas/shader_sh2"
const SPHERE_SIZE := 48
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const LIGHT_TOLERANCE := 3  # /255 PROVISIONAL: la parte iluminada conserva el color; medido <= 1
const NEUTRAL_SPREAD := 2  # /255 PROVISIONAL: blanco, gris y negro siguen neutros en sombra; medido 0
const WHITE_PINK := 2  # /255 PROVISIONAL: ropa blanca, R - G en sombra; medido 0
const WHITE_SATURATION := 0.02  # PROVISIONAL: ropa blanca, saturación de sombra menos la de luz; medido 0
const HUE_MIN := 2.0  # grados PROVISIONAL: giro hacia el rojo; medido 3,4 a 5,6
const HUE_MAX := 8.0  # grados PROVISIONAL
const DARK_SKIN_RATIO := 0.80  # PROVISIONAL: luminancia de sombra / luz en piel oscura; medido 0,84
const MEDIUM_SKIN_SATURATION := 0.58  # PROVISIONAL: saturación de sombra en piel media; medido 0,54
const NO_SHADE_TOLERANCE := 3  # /255 PROVISIONAL: con shade_strength 0, sombra = luz
const MIN_DIFF := 0.002  # aprobado por el responsable el 2026-11-22: A y B solo difieren en la sombra (medido 0,43 a 0,79 %)
const PIXEL_DIFF := 8.0 / 255.0
const SKINS := {
	"piel_clara": Color(0.96, 0.80, 0.70), "piel_media": Color(0.72, 0.50, 0.36), "piel_oscura": Color(0.30, 0.19, 0.14),
	"azul_fantasia": Color(0.35, 0.55, 0.85), "verde_fantasia": Color8(64, 128, 73)}
const NEUTRALS := {"blanco": Color(1, 1, 1), "gris": Color(0.5, 0.5, 0.5), "negro": Color(0.05, 0.05, 0.05)}
const WHITE_CLOTHES := Color(0.85, 0.85, 0.82)
const FRINGE := ["makehuman", "toigo_blunt_bob_with_bangs"]
const CLOTHES := [["overscore", "os_tank_top"], ["overscore", "os_golf_shorts"]]
const COLUMNS := [
	{"name": "anime", "shader": "suave", "softness": 0.09, "threshold": 0.05, "ground_weight": 0.025, "rim_strength": 0.075,
		"rim_width": 0.3, "shade_tint": Color(0.92, 0.72, 0.72), "outline_tint": Color(0.45, 0.30, 0.30), "width_px": 1.25},
	{"name": "soft", "shader": "soft", "softness": 0.09, "threshold": 0.05, "ground_weight": 0.025, "rim_strength": 0.075,
		"rim_width": 0.3, "shade_strength": 1.0, "outline_tint": Color(0.45, 0.30, 0.30), "width_px": 1.25},
]
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
const SHOT_BODY := [25.0, 8.0, Vector3(0, 0.95, 0), 4.0]
const SHOT_FACE := [25.0, 4.0, Vector3(0, 1.55, 0), 1.25]

var repo: String
var out: String
var body_material
var preset
var view
var soft_old: Shader
var soft_old_piece: Shader
var tinted: Shader
var sphere_view: SubViewport
var sphere: MeshInstance3D
var sphere_light: DirectionalLight3D
var failures := 0
var worst := {"luz": 0, "neutro": 0, "blanca_rg": -255, "blanca_sat": -1.0, "giro_min": 99.0, "giro_max": -99.0,
	"oscura": 9.0, "media_sat": 0.0, "sin_sombra": 0}


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
	_check_switch()
	_check_defaults_match_shader()
	_make_sphere()
	await _check_colors()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheets()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


# --- Interruptor ---

func _check_switch() -> void:
	_check(not body_material.soft_enabled, "interruptor apagado por defecto")
	var body := MeshInstance3D.new()
	var applied: ShaderMaterial = body_material.apply(body)
	_check(applied.shader == body_material.SHADER and body_material.body_shader() == body_material.SHADER, "apagado: apply() da SHADER")
	_check(applied.get_shader_parameter("shade_strength") == null, "apagado: sin parámetros del shader nuevo")
	var old_piece := MeshInstance3D.new()
	var old_piece_shader: ShaderMaterial = body_material.apply(old_piece, true)
	_check(not old_piece_shader.shader.code.contains("shade_ratio"), "apagado: la pieza usa el shader del MVP")
	body_material.soft_enabled = true
	applied = body_material.apply(body)
	_check(applied.shader == body_material.SOFT_SHADER, "encendido: apply() da SOFT_SHADER")
	var all_set := true
	for name: String in body_material.SOFT_DEFAULTS:
		all_set = all_set and applied.get_shader_parameter(name) == body_material.SOFT_DEFAULTS[name]
	_check(all_set, "encendido: apply() pone todos los valores de SOFT_DEFAULTS")
	var piece := MeshInstance3D.new()
	var piece_material: ShaderMaterial = body_material.apply(piece, true)
	_check(piece_material.shader == body_material.piece_shader() and piece_material.shader != body_material.SOFT_SHADER
		and piece_material.shader.code.contains("shade_ratio") and piece_material.shader.code.contains("depth_pull"),
		"encendido: la pieza usa la copia de toon_soft con depth_pull")
	_check(is_equal_approx(piece_material.get_shader_parameter("depth_pull"), body_material.PIECE_PULL), "encendido: la pieza lleva depth_pull")
	_check(body_material.piece_shader() == body_material.piece_shader(), "encendido: la copia de la pieza se crea una sola vez")
	body_material.set_color(body, "skin_color", Color(0.1, 0.2, 0.3))
	body_material.set_color(piece, "skin_color", Color(0.3, 0.2, 0.1))
	_check(body_material.get_color(body, "skin_color") == Color(0.1, 0.2, 0.3)
		and body_material.get_color(piece, "skin_color") == Color(0.3, 0.2, 0.1), "encendido: get_color lee cuerpo y pieza")
	body_material.set_outline_width(body, 4.0)
	body_material.set_outline_width(piece, 4.0)
	_check(body_material.get_outline_width(body) == 4.0, "encendido: get_outline_width lee el cuerpo")
	_check(body_material.get_outline_width(piece) == body_material.OUTLINE_DEFAULTS["width_px"], "encendido: get_outline_width no acepta piezas")
	_check(body_material.get_finish(body)["softness"] == body_material.SOFT_DEFAULTS["softness"], "encendido: get_finish lee el cuerpo")
	for mesh in [body, old_piece, piece]:
		mesh.free()


## Los valores de SOFT_DEFAULTS son los de los `uniform` de toon_soft.gdshader (ni uno más ni uno menos).
func _check_defaults_match_shader() -> void:
	var text := FileAccess.get_file_as_string(repo.path_join("godot/addons/creador/toon_soft.gdshader"))
	var regex := RegEx.create_from_string("uniform\\s+(\\w+)\\s+(\\w+)\\s*(?::[^=;]*)?(?:=\\s*([^;]+))?;")
	var found := {}
	for match in regex.search_all(text):
		if match.get_string(1) != "sampler2D":
			found[match.get_string(2)] = _parse(match.get_string(1), match.get_string(3).strip_edges())
	var wrong: Array[String] = []
	for name: String in body_material.SOFT_DEFAULTS:
		if not found.has(name) or not _equal(found[name], body_material.SOFT_DEFAULTS[name]):
			wrong.append(name)
	for name: String in found:
		if not body_material.SOFT_DEFAULTS.has(name):
			wrong.append(name)
	_check(wrong.is_empty(), "toon_soft.gdshader: sus %d uniform coinciden con SOFT_DEFAULTS %s" % [found.size(), wrong])


func _parse(type: String, value: String) -> Variant:
	if type == "bool":
		return value == "true"
	if type == "vec3":
		var parts := value.trim_prefix("vec3(").trim_suffix(")").split(",")
		return Color(float(parts[0]), float(parts[1]), float(parts[2]))
	return float(value)


func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a.is_equal_approx(b) if a is Color else (is_equal_approx(a, b) if a is float else a == b)


# --- Color de luz y sombra ---

func _make_sphere() -> void:
	sphere_view = SubViewport.new()
	sphere_view.size = Vector2i(SPHERE_SIZE, SPHERE_SIZE)
	sphere_view.own_world_3d = true
	sphere_view.transparent_bg = true
	sphere_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sphere_view)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 4)
	camera.fov = 30.0
	sphere_view.add_child(camera)
	sphere_light = DirectionalLight3D.new()
	sphere_view.add_child(sphere_light)
	sphere = MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	sphere_view.add_child(sphere)
	body_material.soft_enabled = true
	body_material.apply(sphere)
	body_material.set_outline_width(sphere, 0.0)
	body_material.set_garment_visible(sphere, false)
	var material := sphere.material_override as ShaderMaterial
	material.set_shader_parameter("ground_weight", 0.0)  # sin suelo ni rim: la parte iluminada es el color tal cual
	material.set_shader_parameter("rim_strength", 0.0)


## El píxel central de la esfera: con la luz de frente (iluminado), de espaldas (sombra pura) o sin luz (unlit).
func _pixel(color: Color, back: bool, unlit := false, strength := 1.0) -> Color:
	var material := sphere.material_override as ShaderMaterial
	material.set_shader_parameter("skin_color", color)
	material.set_shader_parameter("unlit", unlit)
	material.set_shader_parameter("shade_strength", strength)
	sphere_light.rotation_degrees = Vector3(0, 180 if back else 0, 0)
	for i in 3:
		await process_frame
	var image := sphere_view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2)


func _check_colors() -> void:
	var all := SKINS.duplicate()
	all.merge(NEUTRALS)
	all["ropa_blanca"] = WHITE_CLOTHES
	for name: String in all:
		var color: Color = all[name]
		var lit: Color = await _pixel(color, false)
		var shade: Color = await _pixel(color, true)
		var exact: Color = await _pixel(color, false, true)
		print("MEDIDA %s: luz=%s sombra=%s (matiz/sat/valor luz %.1f/%.3f/%.3f sombra %.1f/%.3f/%.3f)" % [name, _bytes(lit), _bytes(shade),
			lit.h * 360.0, lit.s, lit.v, shade.h * 360.0, shade.s, shade.v])
		_check_light(name, color, lit)
		_check(_distance(exact, color) <= 1, name + ": unlit devuelve el color exacto " + _bytes(exact))
		if NEUTRALS.has(name):
			_check_neutral(name, shade)
		elif name == "ropa_blanca":
			_check_white(shade, lit)
		else:
			_check_skin(name, lit, shade)
	for name: String in ["piel_media", "azul_fantasia"]:
		var lit: Color = await _pixel(SKINS[name], false, false, 0.0)
		var shade: Color = await _pixel(SKINS[name], true, false, 0.0)
		var difference := _distance(lit, shade)
		worst["sin_sombra"] = maxi(worst["sin_sombra"], difference)
		_check(difference <= NO_SHADE_TOLERANCE, "%s con shade_strength 0: sombra = luz (diferencia %d/255)" % [name, difference])
	print("MEDIDA peores: luz=%d/255 neutro=%d/255 ropa_blanca_R-G=%d/255 ropa_blanca_sat=%+.3f giro=%.1f..%.1f° oscura=%.3f media_sat=%.3f sin_sombra=%d/255" % [
		worst["luz"], worst["neutro"], worst["blanca_rg"], worst["blanca_sat"], worst["giro_min"], worst["giro_max"],
		worst["oscura"], worst["media_sat"], worst["sin_sombra"]])


func _check_light(name: String, color: Color, lit: Color) -> void:
	var difference := _distance(lit, color)
	worst["luz"] = maxi(worst["luz"], difference)
	_check(difference <= LIGHT_TOLERANCE, "%s: la parte iluminada conserva el color (diferencia %d/255)" % [name, difference])


func _check_neutral(name: String, shade: Color) -> void:
	var spread := maxi(maxi(shade.r8, shade.g8), shade.b8) - mini(mini(shade.r8, shade.g8), shade.b8)
	worst["neutro"] = maxi(worst["neutro"], spread)
	_check(spread <= NEUTRAL_SPREAD, "%s: neutro en sombra (máx - mín = %d/255)" % [name, spread])


func _check_white(shade: Color, lit: Color) -> void:
	var pink := shade.r8 - shade.g8
	var saturation := shade.s - lit.s
	worst["blanca_rg"] = maxi(worst["blanca_rg"], pink)
	worst["blanca_sat"] = maxf(worst["blanca_sat"], saturation)
	_check(pink <= WHITE_PINK and saturation <= WHITE_SATURATION, "ropa blanca sin rosa (R - G = %d/255, saturación %+.3f)" % [pink, saturation])


func _check_skin(name: String, lit: Color, shade: Color) -> void:
	var turn := _wrap(shade.h * 360.0 - lit.h * 360.0)
	var to_red := -turn if lit.h * 360.0 < 180.0 else turn
	worst["giro_min"] = minf(worst["giro_min"], to_red)
	worst["giro_max"] = maxf(worst["giro_max"], to_red)
	_check(to_red >= HUE_MIN and to_red <= HUE_MAX, "%s: el matiz gira hacia el rojo %.1f°" % [name, to_red])
	_check(shade.v < lit.v and shade.s > lit.s, "%s: sombra más oscura y más saturada" % name)
	if name == "piel_oscura":
		var ratio := shade.get_luminance() / lit.get_luminance()
		worst["oscura"] = minf(worst["oscura"], ratio)
		_check(ratio >= DARK_SKIN_RATIO, "piel oscura no casi negra (luminancia sombra / luz = %.3f)" % ratio)
	if name == "piel_media":
		worst["media_sat"] = shade.s
		_check(shade.s <= MEDIUM_SKIN_SATURATION, "piel media sin rojo-naranja saturado (saturación de sombra %.3f)" % shade.s)


func _wrap(degrees: float) -> float:
	return fposmod(degrees + 180.0, 360.0) - 180.0


func _bytes(color: Color) -> String:
	return "(%d,%d,%d)" % [color.r8, color.g8, color.b8]


func _distance(a: Color, b: Color) -> int:
	return maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), absi(a.b8 - b.b8))


# --- Hoja ---

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
	soft_old = Shader.new()
	soft_old.code = FileAccess.get_file_as_string(repo.path_join("pruebas/godot/estilo/toon_suave.gdshader"))
	soft_old_piece = Shader.new()
	soft_old_piece.code = soft_old.code.replace("void fragment()", body_material.PULL_CODE + "void fragment()")
	tinted = Shader.new()
	tinted.code = FileAccess.get_file_as_string(repo.path_join("pruebas/godot/estilo/contorno_tenido.gdshader"))
	var sheets := {"hoja_cuerpo": [] as Array[Image], "hoja_cara": [] as Array[Image]}
	for row: Dictionary in ROWS:
		if not await _dress(row):
			break
		for column: Dictionary in COLUMNS:
			_use_column(column)
			_check_shader(row, column)
			await _wait(4)
			sheets["hoja_cuerpo"].append(await _shot(SHOT_BODY))
			sheets["hoja_cara"].append(await _shot(SHOT_FACE))
	if sheets["hoja_cuerpo"].size() == ROWS.size() * COLUMNS.size():
		for sheet: String in sheets:
			_save_sheet(sheets[sheet], sheet + ".png")
			_check(FileAccess.file_exists(out.path_join(sheet + ".png")), "existe " + sheet)
		_check_differences(sheets["hoja_cuerpo"])


## Preset, colores y piezas de la fila. Se viste con toon_soft puesto: BodyView copia el acabado solo de su propio shader.
func _dress(row: Dictionary) -> bool:
	_use_column(COLUMNS[1])
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


## Después de cada preset se vuelven a poner los valores de la base (el preset trae softness 0,04 y rim_strength 0,25).
func _use_column(column: Dictionary) -> void:
	for mesh: MeshInstance3D in _meshes():
		var material: ShaderMaterial = mesh.material_override
		var piece: bool = mesh != view.species.mesh
		if column["shader"] == "suave":
			material.shader = soft_old_piece if piece else soft_old
		else:
			material.shader = body_material.piece_shader() if piece else body_material.SOFT_SHADER
		for key: String in ["softness", "threshold", "ground_weight", "rim_strength", "rim_width", "shade_tint", "shade_strength"]:
			if column.has(key):
				material.set_shader_parameter(key, column[key])
		var line: ShaderMaterial = material.get_meta("outline")
		line.shader = tinted
		for key: String in ["skin_color", "garment_color", "show_garment"]:
			line.set_shader_parameter(key, material.get_shader_parameter(key))
		line.set_shader_parameter("outline_tint", column["outline_tint"])
		line.set_shader_parameter("width_px", column["width_px"])
	_set_shadow()


func _set_shadow() -> void:
	view.light.shadow_enabled = true
	view.light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	view.light.directional_shadow_max_distance = 6.0
	view.light.shadow_bias = 0.03
	view.light.shadow_normal_bias = 1.0


func _capture(shot: Array) -> Image:
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
	return image


func _shot(shot: Array) -> Image:
	var image: Image = await _capture(shot)
	var cell := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	cell.fill(BACKGROUND)
	cell.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return cell


func _check_shader(row: Dictionary, column: Dictionary) -> void:
	var is_soft: bool = (view.species.mesh.material_override as ShaderMaterial).shader == body_material.SOFT_SHADER
	_check(is_soft == (column["shader"] == "soft"), "%s %s usa su shader" % [row["preset"], column["name"]])


func _check_differences(cells: Array[Image]) -> void:
	for r in ROWS.size():
		var diff := _different(cells[r * 2], cells[r * 2 + 1])
		print("MEDIDA diferencia fila %d (%s): anime_soft=%.4f" % [r, ROWS[r]["preset"], diff])
		_check(diff > MIN_DIFF, "fila %d: la columna soft se distingue de la anime" % r)


func _different(a: Image, b: Image) -> float:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), absf(p.b - q.b)) > PIXEL_DIFF:
				count += 1
	return float(count) / (a.get_width() * a.get_height())


func _save_sheet(cells: Array[Image], file: String) -> void:
	var columns := COLUMNS.size()
	var sheet := Image.create(CELL.x * columns, CELL.y * ROWS.size(), false, Image.FORMAT_RGBA8)
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
