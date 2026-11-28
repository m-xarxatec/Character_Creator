extends SceneTree
# Paso SH.9: la tela oscura tiene sombra (SHADE_MIN_DROP, bloque común de toon_soft) y la línea se lee sobre el negro puro
# (DARK_FLOOR). Esfera con una luz: de frente da la luz; de espaldas, la sombra pura. Compara con «antes»: el mismo código
# sin los dos cambios. Medidas en luminancia sRGB (/255). Con ventana. En Forward+ además guarda la hoja A/B.
# Uso: (ulimit -v 4000000; timeout 400 godot [--rendering-method mobile] --path pruebas/godot -s probar_tela_oscura.gd [-- --shader=<ruta>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# --shader=<ruta>: usa el código de ese archivo en lugar de toon_soft (para romper una copia, nunca el núcleo).
# Escribe pruebas/capturas/sh9_tela_oscura/hoja_ab.png: filas ropa 0,10, negro puro (ropa y pelo) y piel oscura con ropa
# 0,10; columnas A (antes) y B (después) de frente, y A y B de espaldas.
# Que detecta el fallo (en una copia): SHADE_MIN_DROP = 0.0; DARK_FLOOR = 0.0; SHADE_MIN_DROP = 0.06 (cambia la piel oscura).

const OUT_DIR := "pruebas/capturas/sh9_tela_oscura"
const SIZE := 96
const EDGE_X := 72  # un píxel de la línea, fuera de la silueta de la esfera (radio ≈ 22 px), en la fila central
const LINE_PX := 6.0
const MIN_DROP := 4.5  # /255 PROVISIONAL: luz - sombra de la tela oscura (6/255 de valor); medido 5,1 a 7,0
const SAME := 1.0  # /255 PROVISIONAL: la piel no cambia frente a antes; medido 0,0
const LINE_LIT := 8.0  # /255 PROVISIONAL: negro puro con luz menos la línea; medido 10,8 a 11,7
const LINE_SHADE := 4.0  # /255 PROVISIONAL: negro puro en sombra menos la línea; medido 4,7 a 4,8
const OLD_SHADE := "hsv.z * value);"
const NEW_SHADE := "max(min(hsv.z * value, hsv.z - SHADE_MIN_DROP), 0.0));"
const NEW_FLOOR := "\tcolor = floor_dark(color);\n"
const DARK_CLOTHES := {"ropa_0,10": Color(0.10, 0.10, 0.11), "ropa_preset": Color(0.20, 0.20, 0.23), "negro_puro": Color(0, 0, 0)}
const SKINS := {"piel_oscura": Color(0.30, 0.19, 0.14), "piel_oscura_linea": Color(0.27, 0.17, 0.13),
	"piel_media": Color(0.72, 0.50, 0.36), "piel_clara": Color(0.96, 0.80, 0.70)}
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const CLOTHES := [["overscore", "os_tank_top"], ["overscore", "os_golf_shorts"]]
const HAIR := ["makehuman", "toigo_blunt_bob_with_bangs"]
const ROWS := [
	{"skin": Color(0.96, 0.80, 0.70), "hair": Color(0.20, 0.55, 0.35), "clothes": Color(0.10, 0.10, 0.11)},
	{"skin": Color(0.96, 0.80, 0.70), "hair": Color(0, 0, 0), "clothes": Color(0, 0, 0)},
	{"skin": Color(0.27, 0.17, 0.13), "hair": Color(0.20, 0.55, 0.35), "clothes": Color(0.10, 0.10, 0.11)},
]
const SHOTS := [[25.0, 8.0, Vector3(0, 0.95, 0), 4.0], [205.0, 8.0, Vector3(0, 0.95, 0), 4.0]]

var repo: String
var body_material
var preset
var new_code: String
var old_code: String
var old_shader := Shader.new()
var sphere_view: SubViewport
var sphere: MeshInstance3D
var light: DirectionalLight3D
var view
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	preset = load(repo.path_join("godot/addons/creador/preset.gd"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shader="):
			body_material.SOFT_SHADER.code = FileAccess.get_file_as_string(argument.trim_prefix("--shader="))
	new_code = body_material.SOFT_SHADER.code
	old_code = new_code.replace(NEW_SHADE, OLD_SHADE).replace(NEW_FLOOR, "")
	old_shader.code = old_code
	print("MEDIDA renderizador: ", RenderingServer.get_current_rendering_method())
	_check(new_code.contains(NEW_SHADE) and new_code.contains(NEW_FLOOR), "toon_soft lleva la sombra mínima y el suelo de valor")
	_make_sphere()
	await _check_clothes()
	await _check_skins()
	await _check_line()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheet()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


func _make_sphere() -> void:
	sphere_view = SubViewport.new()
	sphere_view.size = Vector2i(SIZE, SIZE)
	sphere_view.own_world_3d = true
	sphere_view.transparent_bg = true
	sphere_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sphere_view)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 4)
	camera.fov = 30.0
	sphere_view.add_child(camera)
	light = DirectionalLight3D.new()
	sphere_view.add_child(light)
	sphere = MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var material := ShaderMaterial.new()
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("show_garment", false)
	material.set_shader_parameter("ground_weight", 0.0)  # sin suelo ni rim: la luz es el color tal cual
	material.set_shader_parameter("rim_strength", 0.0)
	var outline := ShaderMaterial.new()
	outline.shader = body_material.OUTLINE_SHADER
	for name: String in body_material.OUTLINE_DEFAULTS:
		outline.set_shader_parameter(name, body_material.OUTLINE_DEFAULTS[name])
	outline.set_shader_parameter("show_garment", false)
	outline.set_shader_parameter("outline_tint", body_material.SKIN_START["outline_tint"])  # la línea anime
	outline.set_shader_parameter("width_px", LINE_PX)
	material.next_pass = outline
	sphere.material_override = material
	sphere_view.add_child(sphere)


## [centro de la esfera, píxel de la línea] con el color dado, la luz de frente o de espaldas y el shader de antes o el nuevo.
func _shot(color: Color, back: bool, old := false) -> Array:
	var material := sphere.material_override as ShaderMaterial
	material.shader = old_shader if old else body_material.SOFT_SHADER
	material.set_shader_parameter("skin_color", color)
	(material.next_pass as ShaderMaterial).set_shader_parameter("skin_color", color)
	light.rotation_degrees = Vector3(0, 180 if back else 0, 0)
	for i in 4:
		await process_frame
	var image := sphere_view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return [image.get_pixel(SIZE / 2, SIZE / 2), image.get_pixel(EDGE_X, SIZE / 2)]


func _luma(color: Color) -> float:
	return color.get_luminance() * 255.0


func _check_clothes() -> void:
	for name: String in DARK_CLOTHES:
		var color: Color = DARK_CLOTHES[name]
		var drops := []
		for old in [true, false]:
			var lit: Color = (await _shot(color, false, old))[0]
			var shade: Color = (await _shot(color, true, old))[0]
			drops.append([_luma(lit), _luma(shade)])
		print("MEDIDA %s: antes luz %.1f sombra %.1f (%.1f) | ahora luz %.1f sombra %.1f (%.1f)" % [name,
			drops[0][0], drops[0][1], drops[0][0] - drops[0][1], drops[1][0], drops[1][1], drops[1][0] - drops[1][1]])
		_check(drops[1][0] - drops[1][1] >= MIN_DROP, "%s: la sombra se distingue de la luz (%.1f/255)" % [name, drops[1][0] - drops[1][1]])


func _check_skins() -> void:
	for name: String in SKINS:
		var worst := 0.0
		var text := ""
		for back in [false, true]:
			var before: Color = (await _shot(SKINS[name], back, true))[0]
			var after: Color = (await _shot(SKINS[name], back))[0]
			worst = maxf(worst, absf(_luma(after) - _luma(before)))
			text += " %s %.1f → %.1f" % ["sombra" if back else "luz", _luma(before), _luma(after)]
		print("MEDIDA %s:%s" % [name, text])
		_check(worst <= SAME, "%s no cambia (%.1f/255)" % [name, worst])


func _check_line() -> void:
	for old in [true, false]:
		var lit: Array = await _shot(Color(0, 0, 0), false, old)
		var shade: Array = await _shot(Color(0, 0, 0), true, old)
		var line: Color = lit[1]
		var on_lit := _luma(lit[0]) - _luma(line)
		var on_shade := _luma(shade[0]) - _luma(line)
		print("MEDIDA negro puro %s: línea %.1f, ropa con luz %.1f (%.1f), en sombra %.1f (%.1f)" % ["antes" if old else "ahora",
			_luma(line), _luma(lit[0]), on_lit, _luma(shade[0]), on_shade])
		if not old:
			_check(line.a > 0.9, "hay línea junto a la esfera")
			_check(on_lit >= LINE_LIT, "negro puro con luz: la línea se distingue (%.1f/255)" % on_lit)
			_check(on_shade >= LINE_SHADE, "negro puro en sombra: la línea se distingue (%.1f/255)" % on_shade)


# --- Hoja A/B ---

func _use(code: String) -> void:
	body_material.SOFT_SHADER.code = code
	body_material.piece_shader(true).code = code.replace("void fragment()", body_material.PULL_CODE + "void fragment()")


func _make_sheet() -> void:
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
	var cells: Array[Image] = []
	for row: Dictionary in ROWS:
		await _dress(row)
		for shot: Array in SHOTS:
			for code in [old_code, new_code]:
				_use(code)
				cells.append(await _cell(shot))
	_use(new_code)
	var path := out.path_join("hoja_ab.png")
	var sheet := Image.create(CELL.x * 4, CELL.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % 4, i / 4) * CELL)
	sheet.save_png(path)
	_check(FileAccess.file_exists(path), "existe hoja_ab.png")


## El preset anime en estilo anime (SKIN_START), con pelo, camiseta y pantalón cortos de los colores de la fila.
func _dress(row: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(repo.path_join("godot/datos/humana/presets/anime.json"))
	var loaded: Dictionary = preset.from_text(text, view.SPECIES, view.species.sliders)
	view.set_anime_style(false)
	preset.apply_look(view.species.mesh, loaded)
	view.set_values(loaded["valores"])
	for key: String in view.pieces.keys():
		view.set_piece(key.get_base_dir(), key.get_file(), false)
	for piece: Array in [HAIR] + CLOTHES:
		if view.set_piece(piece[0], piece[1], true):
			view.set_piece_color(String(piece[0]).path_join(piece[1]), row["hair"] if piece == HAIR else row["clothes"])
	view.set_anime_style(true)
	body_material.set_color(view.species.mesh, "skin_color", row["skin"])
	body_material.set_color(view.species.mesh, "garment_color", row["clothes"])
	view.style.refresh()
	await _wait(10)


func _cell(shot: Array) -> Image:
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


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	failures += 0 if ok else 1
	return ok


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
