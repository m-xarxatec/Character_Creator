extends SceneTree
# Paso PL.2: miniaturas de los presets de serie (godot/datos/humana/presets/<id>.png, 256 × 256, fondo transparente),
# hechas con el núcleo del editor: toon con contorno, valores en reposo, luz de la vista y cámara de tres cuartos.
# Necesita ventana (no --headless). Escribe también <id>.png.import con importer="keep" (viajan tal cual en el .pck).
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s generar_miniaturas.gd 2>&1 | grep -E 'GUARDADO|ERROR')

const SIZE := 256
const FOV := 35.0  # el de la cámara de la vista (orbit_camera.gd)
const YAW := 35.0  # grados: tres cuartos
const PITCH := 5.0  # grados: un poco desde arriba
const MARGIN := 1.08  # aire alrededor del cuerpo
const LIGHT_ANGLES := Vector3(-40, 30, 0)  # los de body_view.gd
const KEEP := "[remap]\n\nimporter=\"keep\"\n"

var root_dir: String
var species
var viewport: SubViewport
var camera: Camera3D


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	var folder := root_dir.path_join("godot/datos/humana")
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(folder):
		print("ERROR: ", species.error)
		quit(1)
		return
	_build_view()
	var preset: GDScript = load(addon.path_join("preset.gd"))
	var baker: GDScript = load(addon.path_join("mesh_baker.gd"))
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	load(addon.path_join("body_material.gd")).apply(species.mesh)
	var presets := folder.path_join("presets")
	for file: String in DirAccess.get_files_at(presets):
		if file.get_extension() != "json":
			continue
		var loaded: Dictionary = preset.from_text(FileAccess.get_file_as_string(presets.path_join(file)), "humana", species.sliders)
		if loaded["error"] != "":
			print("ERROR: ", file, ": ", loaded["error"])
			continue
		updater.update(loaded["valores"], false)
		preset.apply_look(species.mesh, loaded)
		_frame(baker.bake(species.mesh, species.skeleton)["vertices"])
		var image := await _render()
		var path := presets.path_join(file.get_basename() + ".png")
		image.save_png(path)
		if not FileAccess.file_exists(path + ".import"):
			FileAccess.open(path + ".import", FileAccess.WRITE).store_string(KEEP)
		print("GUARDADO ", path)
	quit()


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(species.scene)
	var environment := Environment.new()  # como body_view.gd
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


## Cámara de tres cuartos que encuadra la caja de esos vértices (la más alta de alto o ancho, con MARGIN).
func _frame(vertices: PackedVector3Array) -> void:
	var box := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		box = box.expand(v)
	var half := maxf(box.size.y, maxf(box.size.x, box.size.z)) / 2.0 * MARGIN
	var distance := half / tan(deg_to_rad(FOV / 2.0)) + box.size.z / 2.0
	var direction := Vector3(sin(deg_to_rad(YAW)), sin(deg_to_rad(PITCH)), cos(deg_to_rad(YAW))).normalized()
	camera.look_at_from_position(box.get_center() + direction * distance, box.get_center())


func _render() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
