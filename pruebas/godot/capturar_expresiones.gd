extends SceneTree
# Paso 9.7.0 (hoja para el juicio del responsable): las expresiones (formas expr_*) sobre Neutro, Femenino y Masculino,
# con los ojos, las líneas y las cejas, en primer plano de frente y en tres cuartos. Necesita ventana (no --headless).
# Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s capturar_expresiones.gd 2>&1 | grep -E 'MEDIDA|GUARDADO|ERROR')
# Hojas: pruebas/capturas/expresiones/<plantilla>.png: una fila por expresión (la primera, sin expresión), columnas
# frente y tres cuartos. Para el A/B del parpadeo (ficha §6): regenerar los datos con la otra receta de
# blender/expresiones.json en una copia y repetir con -- --salida=<carpeta>.

const TILE := Vector2i(420, 420)
const FOV := 35.0
const PITCH := 5.0
const MARGIN := 1.15
const LIGHT_ANGLES := Vector3(-40, 30, 0)  # los de body_view.gd
const BACKGROUND := Color(0.86, 0.87, 0.9)
const VIEWS := [0.0, 35.0]
const CLOSE_DOWN := 1.1  # de la coronilla hacia abajo, en cabezas
const CLOSE_SIDE := 0.7  # a cada lado del centro, en cabezas
const FACES := ["", "happy", "angry", "sad", "surprised", "blink", "blinkLeft", "aa", "ih", "ou", "ee", "oh"]  # 9.8: visemas
const TEMPLATES := {"neutro": "", "femenino": "presets/femenino.json", "masculino": "presets/masculino.json"}

var root_dir: String
var species
var viewport: SubViewport
var camera: Camera3D


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	var out := root_dir.path_join("pruebas/capturas/expresiones")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--salida="):
			out = arg.trim_prefix("--salida=")
	DirAccess.make_dir_recursive_absolute(out)
	species = load(addon.path_join("species_data.gd")).new()
	var folder := root_dir.path_join("godot/datos/humana")
	if species.load_folder(folder):
		print("ERROR: ", species.error)
		quit(1)
		return
	_build_view()
	var preset: GDScript = load(addon.path_join("preset.gd"))
	var baker: GDScript = load(addon.path_join("mesh_baker.gd"))
	var measures: GDScript = load(root_dir.path_join("godot/app/measures.gd"))
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	load(addon.path_join("body_material.gd")).apply(species.mesh)
	for eye in load(addon.path_join("eye_mesh.gd")).build(species.mesh, species.skeleton, species.eyes):
		updater.pieces.append(eye)
	var style: MeshInstance3D = load(root_dir.path_join("godot/app/style_view.gd")).new()
	style.setup(species.mesh, species.skeleton)
	for template: String in TEMPLATES:
		var text: String = species.preset_text() if TEMPLATES[template] == "" \
			else FileAccess.get_file_as_string(folder.path_join(TEMPLATES[template]))
		var loaded: Dictionary = preset.from_text(text, "humana", species.sliders)
		preset.apply_look(species.mesh, loaded)
		var sheet := Image.create(TILE.x * VIEWS.size(), TILE.y * FACES.size(), false, Image.FORMAT_RGBA8)
		for row in FACES.size():
			var face: String = FACES[row]
			var rejected: Array = updater.update(loaded["valores"], false, {face: 1.0} if face != "" else {})
			if not rejected.is_empty():
				print("ERROR: %s no se aplicó: %s" % [face, rejected])
			style.refresh()
			var vertices: PackedVector3Array = baker.bake(species.mesh, species.skeleton)["vertices"]
			var head: float = measures.proportions(species.mesh, species.skeleton)["head"]
			var top := _box(vertices, -INF, INF).end.y
			for column in VIEWS.size():
				_frame(_box(vertices, top - CLOSE_DOWN * head, CLOSE_SIDE * head), VIEWS[column])
				sheet.blit_rect(await _render(), Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * column, TILE.y * row))
		var path := out.path_join(template + ".png")
		sheet.save_png(path)
		print("GUARDADO ", path, " (filas: sin expresión, ", ", ".join(FACES.slice(1)), ")")
	quit()


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.size = TILE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(species.scene)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = LIGHT_ANGLES
	viewport.add_child(light)
	camera = Camera3D.new()
	camera.fov = FOV
	viewport.add_child(camera)


## Como capturar_cabeza.gd: caja de los vértices por encima de from_y y a menos de side del centro (en X).
static func _box(vertices: PackedVector3Array, from_y: float, side: float) -> AABB:
	var box := AABB()
	var first := true
	for v in vertices:
		if v.y >= from_y and absf(v.x) <= side:
			box = AABB(v, Vector3.ZERO) if first else box.expand(v)
			first = false
	return box


func _frame(box: AABB, yaw: float) -> void:
	var aspect := float(TILE.x) / TILE.y
	var half := maxf(box.size.y, maxf(box.size.x, box.size.z) / aspect) / 2.0 * MARGIN
	var distance := half / tan(deg_to_rad(FOV / 2.0)) + maxf(box.size.x, box.size.z) / 2.0
	var direction := Vector3(sin(deg_to_rad(yaw)), sin(deg_to_rad(PITCH)), cos(deg_to_rad(yaw))).normalized()
	camera.look_at_from_position(box.get_center() + direction * distance, box.get_center())


func _render() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image
