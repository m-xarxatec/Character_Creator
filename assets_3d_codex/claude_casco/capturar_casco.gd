extends SceneTree
# Capturas del casco sobre el personaje con el BodyView real del programa. Con ventana.
# Uso (desde la raíz): timeout 300 godot --path pruebas/godot -s <ruta absoluta>/capturar_casco.gd -- <carpeta_con_packs> <salida.png>
# Filas: con visor; sin visor; cuello corto + cabeza grande; cuello largo + complexión fuerte. Antes de cada fila se pone
# un peinado: el casco (ranura pelo) debe quitarlo. Columnas: frente, tres cuartos, perfil, espalda, desde abajo.

const CELL := Vector2i(360, 400)
const BACKGROUND := Color8(199, 202, 204)
const PACK := "claude_cascos"
const BASE := ["casco_astronauta", "casco_astronauta_metal", "casco_astronauta_acolchado"]
const ROWS := [
	{"visor": true, "valores": {}},
	{"visor": false, "valores": {}},
	{"visor": false, "valores": {"neck_length": 0.0, "head_width": 1.0, "head_height": 1.0}},
	{"visor": true, "valores": {"neck_length": 1.0, "gender": 1.0, "muscle": 1.0, "weight": 1.0}},
]
const VIEWS := [[0.0, 8.0], [35.0, 8.0], [90.0, 8.0], [180.0, 8.0], [20.0, -35.0]]

var repo: String
var view


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
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
	var sheet := Image.create(CELL.x * VIEWS.size(), CELL.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for row in ROWS.size():
		var spec: Dictionary = ROWS[row]
		view.set_values(spec["valores"])
		if not view.set_piece("makehuman", "short02", true):
			print("ERROR: pelo")
		var ids: Array = BASE + (["casco_astronauta_visor"] if spec["visor"] else [])
		view.set_piece(PACK, "casco_astronauta_visor", false)
		for id: String in ids:
			if not view.set_piece(PACK, id, true):
				print("ERROR: no se pudo poner ", id)
				quit(1)
				return
		print("FILA %d: pelo puesto = %s" % [row, view.pieces.has("makehuman/short02")])
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
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
	var size := pose.basis.get_scale().y
	var target := pose.origin + Vector3(0, 0.03 * size, 0)
	camera.yaw = yaw
	camera.pitch = pitch
	camera.zoom = 1.0
	camera.goal_target = target
	camera.target = target
	camera.goal_distance = 1.0 * size
	camera.fit_distance = 1.0 * size
	camera.distance = 1.0 * size
	camera.snap()
	await _wait(10)
	var image: Image = view.viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
