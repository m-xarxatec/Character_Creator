extends SceneTree
# Paso PL.9: Cabeza › Tamaño llega a ×2,5 (antes ×1,3). Capturas para el juicio visual, solo con deslizadores, desde el
# personaje nuevo (presets/anime.json). Mide con Measures.proportions. Necesita ventana (no --headless). Sin límites.
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s capturar_cabeza.gd 2>&1 | grep -E 'MEDIDA|GUARDADO|ERROR')
# Hojas: pruebas/capturas/cabeza/<caso>.png: frente, tres cuartos, perfil y primer plano de cabeza y cuello.

const TILE := Vector2i(450, 600)
const FOV := 35.0  # el de la vista del editor (orbit_camera.gd)
const PITCH := 5.0
const MARGIN := 1.08
const LIGHT_ANGLES := Vector3(-40, 30, 0)  # los de body_view.gd
const BACKGROUND := Color(0.86, 0.87, 0.9)
const VIEWS := [0.0, 35.0, 90.0]  # frente, tres cuartos, perfil
const CLOSE_DOWN := 1.25  # primer plano: de la coronilla hacia abajo, en cabezas
const CLOSE_SIDE := 0.6  # primer plano: a cada lado del centro, en cabezas (deja fuera los brazos)
## Deslizadores que cambia cada caso sobre el personaje nuevo.
const CASES := {
	"1_cabeza_x1": {},
	"2_cabeza_x1_75": {"head_size": 0.75},
	"3_cabeza_x2_5": {"head_size": 1.0},
	"4_cabeza_x2_5_cuerpo_corto": {"head_size": 1.0, "leg_length": 0.0, "torso_length": 0.0, "neck_length": 0.0,
		"arm_length": 0.0, "weight": 0.65, "thigh": 0.8, "calf": 0.8, "hand_size_l": 1.0, "hand_size_r": 1.0,
		"foot_size_l": 1.0, "foot_size_r": 1.0},
}

var root_dir: String
var species
var viewport: SubViewport
var camera: Camera3D


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	var out := root_dir.path_join("pruebas/capturas/cabeza")
	DirAccess.make_dir_recursive_absolute(out)
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	_build_view()
	var preset: GDScript = load(addon.path_join("preset.gd"))
	var baker: GDScript = load(addon.path_join("mesh_baker.gd"))
	var measures: GDScript = load(root_dir.path_join("godot/app/measures.gd"))
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	load(addon.path_join("body_material.gd")).apply(species.mesh)
	var loaded: Dictionary = preset.from_text(species.preset_text(), "humana", species.sliders)
	preset.apply_look(species.mesh, loaded)
	var style: MeshInstance3D = load(root_dir.path_join("godot/app/style_view.gd")).new()
	style.setup(species.mesh, species.skeleton)
	for case: String in CASES:
		var values: Dictionary = loaded["valores"].duplicate()
		values.merge(CASES[case], true)
		updater.update(values, false)
		style.refresh()
		var p: Dictionary = measures.proportions(species.mesh, species.skeleton)
		print("MEDIDA %s: %.2f m, %.2f cabezas" % [case, p["height"], p["heads"]])
		var vertices: PackedVector3Array = baker.bake(species.mesh, species.skeleton)["vertices"]
		var sheet := Image.create(TILE.x * (VIEWS.size() + 1), TILE.y, false, Image.FORMAT_RGBA8)
		for i in VIEWS.size():
			_frame(_box(vertices, -INF, INF), VIEWS[i])
			sheet.blit_rect(await _render(), Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * i, 0))
		var top := _box(vertices, -INF, INF).end.y
		_frame(_box(vertices, top - CLOSE_DOWN * p["head"], CLOSE_SIDE * p["head"]), VIEWS[1])
		sheet.blit_rect(await _render(), Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * VIEWS.size(), 0))
		var path := out.path_join(case + ".png")
		sheet.save_png(path)
		print("GUARDADO ", path)
	quit()


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.size = TILE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(species.scene)
	var environment := Environment.new()  # como body_view.gd, con fondo liso
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


## Caja de los vértices por encima de esa altura y a menos de side del centro (en X).
static func _box(vertices: PackedVector3Array, from_y: float, side: float) -> AABB:
	var box := AABB()
	var first := true
	for v in vertices:
		if v.y >= from_y and absf(v.x) <= side:
			box = AABB(v, Vector3.ZERO) if first else box.expand(v)
			first = false
	return box


## Cámara que encuadra la caja desde ese giro (grados), con MARGIN, en la proporción de TILE.
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
