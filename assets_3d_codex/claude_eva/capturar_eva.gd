extends SceneTree
# Capturas del traje EVA sobre el personaje con el BodyView real del programa. Con ventana.
# Uso (desde la raíz): timeout 300 godot --path pruebas/godot -s <ruta absoluta>/capturar_eva.gd -- <carpeta_con_packs> <salida.png> [cerca]
# La carpeta debe tener claude_evas y claude_cascos (la última fila lleva también el casco de astronauta).
# Filas: por defecto; femenino con pecho grande; fuerte (músculo y grasa al máximo); con el casco.
# Columnas: frente, tres cuartos, perfil, espalda, desde abajo. Con «cerca», la cámara va al cuello.

const CELL := Vector2i(400, 400)
const BACKGROUND := Color8(199, 202, 204)
const ROWS := [{}, {"gender": 0.0, "breast_volume": 1.0}, {"muscle": 1.0, "weight": 1.0}, {}]
const VIEWS := [[0.0, 5.0], [35.0, 5.0], [90.0, 5.0], [180.0, 5.0], [20.0, -30.0]]

var repo: String
var view
var close := false


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	close = args.size() > 2 and args[2] == "cerca"
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	for w in view.library.scan(PackedStringArray([repo.path_join("godot/packs"), args[0]])):
		print("AVISO ", w)
	var body_material: GDScript = load(repo.path_join("godot/addons/creador/body_material.gd"))
	body_material.set_color(view.species.mesh, "skin_color", Color(0.93, 0.76, 0.64))
	if not view.set_piece("claude_evas", "traje_eva", true):
		print("ERROR: no se pudo poner traje_eva")
		quit(1)
		return
	var sheet := Image.create(CELL.x * VIEWS.size(), CELL.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for row in ROWS.size():
		if row == ROWS.size() - 1 and not view.set_piece("claude_cascos", "casco_astronauta", true):
			print("AVISO: sin casco de astronauta")
		view.set_values(ROWS[row])
		view.style.refresh()
		await _wait(6)
		for column in VIEWS.size():
			var shot := await _capture(VIEWS[column][0], VIEWS[column][1])
			var cell := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
			cell.fill(BACKGROUND)
			cell.blend_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i.ZERO)
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	sheet.save_png(args[1])
	print("GUARDADO ", args[1])
	quit()


func _capture(yaw: float, pitch: float) -> Image:
	var camera = view.camera
	var skeleton: Skeleton3D = view.species.skeleton
	var bone := "Neck" if close else "Hips"
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))
	var distance := 1.0 if close else 3.0
	camera.yaw = yaw
	camera.pitch = pitch
	camera.zoom = 1.0
	camera.goal_target = pose.origin
	camera.target = pose.origin
	camera.goal_distance = distance
	camera.fit_distance = distance
	camera.distance = distance
	camera.snap()
	await _wait(10)
	var image: Image = view.viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
