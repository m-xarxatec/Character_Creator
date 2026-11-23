extends SceneTree
# Capturas de la gorra sobre el personaje con el BodyView real del programa. Con ventana.
# Uso (desde la raíz): timeout 300 godot --path pruebas/godot -s <ruta absoluta>/capturar_gorra.gd -- <carpeta_con_packs> <salida.png> [preset|""] [valores_json|"{}"] [gorra_id]
# Filas: peinados (sin pelo, corto, melena, largo, afro); columnas: frente, tres cuartos, perfil, espalda.

const CELL := Vector2i(360, 400)
const BACKGROUND := Color8(199, 202, 204)
const HAIRS_HOLGADA := [[], ["makehuman", "short02"], ["makehuman", "toigo_blunt_bob_with_bangs"],
	["quaternius", "hair_long"], ["makehuman", "afro01"]]
const HAIRS_AJUSTADA := [[], ["quaternius", "hair_buzzed"], ["quaternius", "hair_buzzed_female"], ["makehuman", "short04"]]
const VIEWS := [0.0, 35.0, 90.0, 180.0]

var repo: String
var view


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pack_dir: String = args[0]
	var out: String = args[1]
	var preset_name: String = args[2] if args.size() > 2 else ""
	var extra: Dictionary = JSON.parse_string(args[3]) if args.size() > 3 else {}
	var cap_id: String = args[4] if args.size() > 4 else "gorra_plana"
	var caps := [["claude_gorras", cap_id], ["claude_gorras", cap_id + "_gm"]]
	var hairs: Array = HAIRS_AJUSTADA if cap_id.ends_with("ajustada") else HAIRS_HOLGADA
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	var warnings: Array = view.library.scan(PackedStringArray([repo.path_join("godot/packs"), pack_dir]))
	for w in warnings:
		print("AVISO ", w)
	if preset_name != "":
		var preset: GDScript = load(repo.path_join("godot/addons/creador/preset.gd"))
		var text := FileAccess.get_file_as_string(repo.path_join("godot/datos/humana/presets/%s.json" % preset_name))
		var loaded: Dictionary = preset.from_text(text, view.SPECIES, view.species.sliders)
		preset.apply_look(view.species.mesh, loaded)
		var values: Dictionary = loaded["valores"]
		values.merge(extra, true)
		view.set_values(values)
	var body_material: GDScript = load(repo.path_join("godot/addons/creador/body_material.gd"))
	body_material.set_color(view.species.mesh, "skin_color", Color(0.93, 0.76, 0.64))
	for cap: Array in caps:
		if not view.set_piece(cap[0], cap[1], true):
			print("ERROR: no se pudo poner ", cap)
			quit(1)
			return
	var sheet := Image.create(CELL.x * VIEWS.size(), CELL.y * hairs.size(), false, Image.FORMAT_RGBA8)
	var previous := []
	for row in hairs.size():
		if previous.size() > 0:
			view.set_piece(previous[0], previous[1], false)
		var hair: Array = hairs[row]
		if hair.size() > 0:
			if view.set_piece(hair[0], hair[1], true):
				view.set_piece_color(String(hair[0]).path_join(hair[1]), Color(0.30, 0.20, 0.15))
			else:
				print("ERROR: pelo ", hair)
		previous = hair
		view.style.refresh()
		await _wait(6)
		for column in VIEWS.size():
			var shot := await _capture(VIEWS[column])
			var cell := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
			cell.fill(BACKGROUND)
			cell.blend_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i.ZERO)
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	sheet.save_png(out)
	print("GUARDADO ", out)
	quit()


func _capture(yaw: float) -> Image:
	var camera = view.camera
	var skeleton: Skeleton3D = view.species.skeleton
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
	var size := pose.basis.get_scale().y
	var target := pose.origin + Vector3(0, 0.07 * size, 0)
	camera.yaw = yaw
	camera.pitch = 8.0
	camera.zoom = 1.0
	camera.goal_target = target
	camera.target = target
	camera.goal_distance = 0.85 * size
	camera.fit_distance = 0.85 * size
	camera.distance = 0.85 * size
	camera.snap()
	await _wait(10)
	var image: Image = view.viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
