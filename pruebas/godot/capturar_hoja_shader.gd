extends SceneTree
# Paso SH.1: hojas A/B del shader (MVP, suave y anime) sin tocar el programa: los shaders de prueba se ponen en memoria.
# Mide el lado sin luz con solo luces omni, en luminancia sRGB (Color.get_luminance sobre la imagen final). Con ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s capturar_hoja_shader.gd 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# Escribe en pruebas/capturas/shader_ab/: hoja_cuerpo, hoja_cara, hoja_flequillo y hoja_omni (filas: anime, femenino,
# masculino; columnas: MVP, suave, anime). Que detecta el fallo: dar a una columna el shader o los valores de otra.

const OUT_DIR := "pruebas/capturas/shader_ab"
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const MIN_DIFF := 0.01  # aprobado el 2026-11-22; margen medido entre columnas: 2,82–8,60 % de los píxeles
const PIXEL_DIFF := 8.0 / 255.0  # aprobado el 2026-11-22, con el mismo margen medido
const BLACK_LUMINANCE := 0.03  # sRGB
const FRINGE := ["makehuman", "toigo_blunt_bob_with_bangs"]
const CLOTHES := [["overscore", "os_tank_top"], ["overscore", "os_golf_shorts"]]
const COLUMNS := [
	{"name": "mvp", "shader": "mvp", "softness": 0.04, "rim_strength": 0.25, "width_px": 2.5, "shadow": false},
	{"name": "suave", "shader": "soft", "softness": 0.28, "threshold": 0.05, "ground_weight": 0.2, "rim_strength": 0.08,
		"shade_tint": Color(0.70, 0.55, 0.58), "outline_tint": Color(0.28, 0.22, 0.22), "width_px": 1.5, "shadow": true},
	{"name": "anime", "shader": "soft", "softness": 0.09, "threshold": 0.05, "ground_weight": 0.025, "rim_strength": 0.075,
		"shade_tint": Color(0.92, 0.72, 0.72), "outline_tint": Color(0.45, 0.30, 0.30), "width_px": 1.25, "shadow": true},
]
const ROWS := [
	{"preset": "anime", "skin": Color(0.96, 0.80, 0.70), "hair": ["makehuman", "toigo_blunt_bob_with_bangs"],
		"hair_color": Color(0.20, 0.55, 0.35), "clothes": Color(0.10, 0.10, 0.11)},
	{"preset": "femenino", "skin": Color(0.30, 0.19, 0.14), "hair": ["quaternius", "hair_long"],
		"hair_color": Color(0.30, 0.20, 0.15), "clothes": Color(0.28, 0.33, 0.45)},
	{"preset": "masculino", "skin": Color(0.72, 0.50, 0.36), "hair": ["makehuman", "short02"],
		"hair_color": Color(0.62, 0.46, 0.22), "clothes": Color(0.85, 0.85, 0.82)},
]
const SHOT_BODY := [25.0, 8.0, Vector3(0, 0.95, 0), 4.0]
const SHOT_FACE := [25.0, 4.0, Vector3(0, 1.55, 0), 1.25]
const SHOT_FRINGE := [0.0, 2.0, Vector3(0, 1.60, 0), 0.75]
const SHOT_OMNI := [0.0, 8.0, Vector3(0, 0.95, 0), 4.0]
const OMNI_COLOR := Color(1.0, 0.72, 0.45)
const OMNIS := [[Vector3(-1.6, 1.9, 1.2), 3.0, 6.0], [Vector3(-1.2, 0.7, 0.6), 1.5, 5.0]]

var repo: String
var out: String
var view
var body_material
var preset
var soft: Shader
var soft_piece: Shader
var tinted: Shader
var omnis: Array[OmniLight3D] = []
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	out = repo.path_join(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	preset = load(repo.path_join("godot/addons/creador/preset.gd"))
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	_load_shaders()
	_add_omnis()
	var sheets := {}
	for sheet: String in ["hoja_cuerpo", "hoja_cara", "hoja_flequillo", "hoja_omni"]:
		sheets[sheet] = [] as Array[Image]
	for row: Dictionary in ROWS:
		if not await _capture_row(row, sheets):
			break
	if failures == 0:
		_check_differences(sheets["hoja_cuerpo"])
		for sheet: String in sheets:
			_save_sheet(sheets[sheet], sheet + ".png")
			_check(FileAccess.file_exists(out.path_join(sheet + ".png")), "existe " + sheet)
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


func _capture_row(row: Dictionary, sheets: Dictionary) -> bool:
	if not await _dress(row, row["hair"]):
		return false
	for column: Dictionary in COLUMNS:
		_use_column(column)
		_check_shader(row, column)
		await _wait(4)
		sheets["hoja_cuerpo"].append(await _shot(SHOT_BODY))
		sheets["hoja_cara"].append(await _shot(SHOT_FACE))
		sheets["hoja_omni"].append(await _omni_shot(row, column))
	if not await _dress(row, FRINGE):
		return false
	for column: Dictionary in COLUMNS:
		_use_column(column)
		await _wait(4)
		sheets["hoja_flequillo"].append(await _shot(SHOT_FRINGE))
	return true


func _load_shaders() -> void:
	soft = Shader.new()
	soft.code = FileAccess.get_file_as_string(repo.path_join("pruebas/godot/estilo/toon_suave.gdshader"))
	soft_piece = Shader.new()
	soft_piece.code = soft.code.replace("void fragment()", body_material.PULL_CODE + "void fragment()")
	tinted = Shader.new()
	tinted.code = FileAccess.get_file_as_string(repo.path_join("pruebas/godot/estilo/contorno_tenido.gdshader"))


func _add_omnis() -> void:
	for data: Array in OMNIS:
		var omni := OmniLight3D.new()
		omni.position = data[0]
		omni.light_energy = data[1]
		omni.omni_range = data[2]
		omni.light_color = OMNI_COLOR
		omni.shadow_enabled = false
		omni.visible = false
		view.viewport.add_child(omni)
		omnis.append(omni)


## Preset, colores y piezas de la fila. Se viste con el MVP puesto: BodyView copia el acabado solo de su propio shader.
func _dress(row: Dictionary, hair: Array) -> bool:
	_use_column(COLUMNS[0])
	var text := FileAccess.get_file_as_string(repo.path_join("godot/datos/humana/presets/%s.json" % row["preset"]))
	var loaded: Dictionary = preset.from_text(text, view.SPECIES, view.species.sliders)
	if loaded["error"]:
		return _check(false, "preset " + row["preset"] + ": " + str(loaded["error"]))
	preset.apply_look(view.species.mesh, loaded)
	view.set_values(loaded["valores"])
	body_material.set_color(view.species.mesh, "skin_color", row["skin"])
	body_material.set_color(view.species.mesh, "garment_color", row["clothes"])
	if not _put_piece(hair, row["hair_color"]):
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


func _use_column(column: Dictionary) -> void:
	for mesh: MeshInstance3D in _meshes():
		var material: ShaderMaterial = mesh.material_override
		var piece: bool = mesh != view.species.mesh
		if column["shader"] == "mvp":
			material.shader = body_material.piece_shader() if piece else body_material.SHADER
		else:
			material.shader = soft_piece if piece else soft
		for key: String in ["softness", "threshold", "ground_weight", "rim_strength", "shade_tint"]:
			if column.has(key):
				material.set_shader_parameter(key, column[key])
		var line: ShaderMaterial = material.get_meta("outline")
		line.shader = tinted if column.has("outline_tint") else body_material.OUTLINE_SHADER
		if column.has("outline_tint"):
			_copy_zone_colors(mesh)
			line.set_shader_parameter("outline_tint", column["outline_tint"])
		line.set_shader_parameter("width_px", column["width_px"])
	_set_shadow(column["shadow"])


func _copy_zone_colors(mesh: MeshInstance3D) -> void:
	var material: ShaderMaterial = mesh.material_override
	var line: ShaderMaterial = material.get_meta("outline")
	for key: String in ["skin_color", "garment_color", "show_garment"]:
		line.set_shader_parameter(key, material.get_shader_parameter(key))


func _set_shadow(on: bool) -> void:
	view.light.shadow_enabled = on
	if on:
		view.light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		view.light.directional_shadow_max_distance = 6.0
		view.light.shadow_bias = 0.03
		view.light.shadow_normal_bias = 1.0


## La celda de la hoja omni y la medida del lado sin luz (sin contorno ni sombra del suelo).
func _omni_shot(row: Dictionary, column: Dictionary) -> Image:
	view.light.visible = false
	for omni in omnis:
		omni.visible = true
	await _wait(4)
	var cell: Image = await _shot(SHOT_OMNI)
	_set_outline_width(0.0)
	view.floor_shadow.visible = false
	var measure: Array = _measure_unlit(await _capture(SHOT_OMNI))
	print("MEDIDA omni %s %s: luminancia_srgb_media=%.4f negro=%.1f%%" % [row["preset"], column["name"], measure[0], measure[1]])
	_set_outline_width(column["width_px"])
	view.floor_shadow.visible = true
	for omni in omnis:
		omni.visible = false
	view.light.visible = true
	await _wait(4)
	return cell


func _set_outline_width(pixels: float) -> void:
	for mesh: MeshInstance3D in _meshes():
		((mesh.material_override as ShaderMaterial).get_meta("outline") as ShaderMaterial).set_shader_parameter("width_px", pixels)


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


## [luminancia sRGB media, % de píxeles negros] en la mitad derecha (las omni están en −X), solo píxeles del personaje.
func _measure_unlit(shot: Image) -> Array:
	var total := 0
	var black := 0
	var sum := 0.0
	for y in shot.get_height():
		for x in range(shot.get_width() / 2, shot.get_width()):
			var pixel := shot.get_pixel(x, y)
			if pixel.a <= 0.5:
				continue
			var luminance := pixel.get_luminance()
			total += 1
			sum += luminance
			black += 1 if luminance < BLACK_LUMINANCE else 0
	return [sum / maxi(total, 1), 100.0 * black / maxi(total, 1)]


func _check_shader(row: Dictionary, column: Dictionary) -> void:
	var is_mvp: bool = (view.species.mesh.material_override as ShaderMaterial).shader == body_material.SHADER
	_check(is_mvp == (column["name"] == "mvp"), "%s %s usa su shader" % [row["preset"], column["name"]])


func _check_differences(cells: Array[Image]) -> void:
	for r in ROWS.size():
		var name: String = ROWS[r]["preset"]
		var soft_diff := _different(cells[r * 3], cells[r * 3 + 1])
		var anime_diff := _different(cells[r * 3 + 1], cells[r * 3 + 2])
		print("MEDIDA diferencia %s: mvp_suave=%.4f suave_anime=%.4f" % [name, soft_diff, anime_diff])
		_check(soft_diff > MIN_DIFF, name + ": suave igual a MVP" if soft_diff <= MIN_DIFF else name + ": suave distinto de MVP")
		_check(anime_diff > MIN_DIFF, name + ": anime igual a suave" if anime_diff <= MIN_DIFF else name + ": anime distinto de suave")


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
