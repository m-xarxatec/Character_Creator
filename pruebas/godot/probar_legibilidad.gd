extends SceneTree
# Paso 5.12: el personaje exportado como se verá en el juego: cámara a 45° desde arriba, al tamaño real en pantalla
# (64, 96 y 128 px de alto en una vista de 1920 × 1080), con luz normal, baja y de color, sobre fondo gris y oscuro.
# Las capturas se recortan (160 × 160) SIN escalar: el contorno sale con su grosor real de pantalla.
# Necesita ventana. Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s probar_legibilidad.gd -- [--doble] 2>&1 | grep -E 'FALLO|MEDIDA|GUARDADO|RESULTADO|ERROR')
# Guarda en pruebas/capturas/legibilidad/: <preset>.png (filas: luz y fondo; columnas: tamaño), <preset>_poses.png
# (reposo, caminar y atacar, girado 0°, 90° y 180°, a 96 px) y una copia ×4 de cada una (vecino más cercano), solo para mirar.
# Que detecta el fallo: --doble pone la cámara al doble de distancia -> fallan las alturas.

const SCREEN := Vector2i(1920, 1080)
const CROP := 160
const HEIGHTS := [64, 96, 128]
const HEIGHT_PX := 2  # ± px; PROVISIONAL (D26)
const OUTLINE_CLASSIC := 0.06  # luminancia máxima de un píxel de contorno: el negro del estilo clásico
const OUTLINE_ANIME := 0.40  # la línea teñida de la piel gris de serie mide 0,34. Aprobado el 2026-11-24 (SH.7)
const LIGHTS := {  # energía de la luz, color, ambiente
	"normal": [1.0, Color.WHITE, 0.4],
	"baja": [0.25, Color.WHITE, 0.1],
	"color": [0.6, Color(1.0, 0.6, 0.3), 0.4],
}
const BACKGROUNDS := {"gris": Color(0.32, 0.33, 0.36), "oscuro": Color(0.08, 0.08, 0.1)}
const BACKGROUND_TOLERANCE := 10  # de 255
const PRESETS := ["anime", "anime_femenino", "anime_masculino", "chibi_oscuro", "chibi_fuera_de_rango"]
const POSES := ["reposo@0.0", "caminar@0.3", "atacar@0.4"]

var failures := 0
var root_dir: String
var species
var updater
var animations
var exporter: GDScript
var baker: GDScript
var retarget_script: GDScript
var material_script: GDScript
var preset_script: GDScript
var outline_limit := OUTLINE_CLASSIC  # SH.7: según el estilo del preset (anime: línea teñida)
var view: SubViewport
var camera: Camera3D
var light: DirectionalLight3D
var world: WorldEnvironment
var twice := "--doble" in OS.get_cmdline_user_args()


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	exporter = load(addon.path_join("glb_exporter.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	retarget_script = load(addon.path_join("pose_retarget.gd"))
	material_script = load(addon.path_join("body_material.gd"))
	preset_script = load(addon.path_join("preset.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	animations = load(addon.path_join("animation_set.gd")).new()
	var error: String = animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	if error:
		print("ERROR: ", error)
		quit(1)
		return
	_make_view()
	view.add_child(species.scene)
	view.add_child(animations.scene)
	species.scene.visible = false
	animations.scene.visible = false
	material_script.apply(species.mesh)
	updater = load(addon.path_join("character_updater.gd")).new(species)
	var out := root_dir.path_join("pruebas/capturas/legibilidad")
	DirAccess.make_dir_recursive_absolute(out)
	for preset_name: String in PRESETS:
		var text: String = species.preset_text() if preset_name == "anime" else FileAccess.get_file_as_string(
			root_dir.path_join("pruebas/fase_3/estilo/%s.json" % preset_name))
		var loaded: Dictionary = preset_script.from_text(text, "humana", species.sliders)
		if loaded["error"] != "":
			print("  MEDIDA %s: no carga (%s); se salta" % [preset_name, loaded["error"]])
			continue
		preset_script.apply_look(species.mesh, loaded)
		outline_limit = OUTLINE_ANIME if loaded["estilo"] == "anime" else OUTLINE_CLASSIC
		updater.update(loaded["valores"], false)
		var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)
		(character.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override = \
			material_script.standalone(species.mesh)
		view.add_child(character)
		await process_frame
		await _sizes_sheet(preset_name, character, out)
		await _poses_sheet(preset_name, character, out)
		character.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		print("  FALLO " + label, " ", detail)
		failures += 1


func _make_view() -> void:
	view = SubViewport.new()
	view.size = SCREEN
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	camera = Camera3D.new()
	camera.fov = 50.0
	view.add_child(camera)
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)  # la de body_view.gd
	view.add_child(light)
	world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	view.add_child(world)


func _set_look(light_name: String, background: String) -> void:
	light.light_energy = LIGHTS[light_name][0]
	light.light_color = LIGHTS[light_name][1]
	world.environment.ambient_light_energy = LIGHTS[light_name][2]
	world.environment.background_color = BACKGROUNDS[background]


func _pose(character: Node3D, pose: String) -> void:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.reset_bone_poses()
	var retarget = retarget_script.new(animations.skeleton, skeleton, animations.bones, animations.hips)
	retarget.capture()
	var parts := pose.split("@")
	animations.play(parts[0])
	animations.seek(animations.length() * float(parts[1]))
	retarget.apply()


## Pone la cámara a 45° desde arriba (desde delante) para que mida `pixels` de alto en pantalla, contorno incluido
## (el contorno queda fuera de la silueta: suma su grosor arriba y abajo).
## Devuelve el centro en pantalla de la caja proyectada.
func _frame(character: Node3D, pixels: int) -> Vector2:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
	var points: PackedVector3Array = baker.bake(mesh, skeleton)["vertices"]
	for i in points.size():
		points[i] = character.global_transform * points[i]
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= points.size()
	var direction := Vector3(0, sin(PI / 4), cos(PI / 4))
	var near := 0.5
	var far := 400.0
	for step in 30:
		var distance := (near + far) / 2.0
		camera.look_at_from_position(center + direction * distance, center)
		if _screen_box(points).size.y + 2.0 * material_script.get_outline_width(species.mesh) > pixels:
			near = distance
		else:
			far = distance
	if twice:
		camera.look_at_from_position(center + direction * far * 2.0, center)
	return _screen_box(points).get_center()


func _screen_box(points: PackedVector3Array) -> Rect2:
	var box := Rect2(camera.unproject_position(points[0]), Vector2.ZERO)
	for i in range(0, points.size(), 3):
		box = box.expand(camera.unproject_position(points[i]))
	return box


func _shot(center: Vector2) -> Image:
	for f in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var corner := Vector2i(clampi(int(center.x) - CROP / 2, 0, SCREEN.x - CROP), clampi(int(center.y) - CROP / 2, 0, SCREEN.y - CROP))
	return image.get_region(Rect2i(corner, Vector2i(CROP, CROP)))


## Altura en píxeles de lo que no es fondo, contraste (luminancia media del personaje − la del fondo) y píxeles de contorno.
func _measure(crop: Image, background: Color) -> Array:
	var top := CROP
	var bottom := -1
	var luminance := 0.0
	var count := 0
	var outline := 0
	for y in CROP:
		for x in CROP:
			var pixel := crop.get_pixel(x, y)
			if absf(pixel.r - background.r) * 255 <= BACKGROUND_TOLERANCE and absf(pixel.g - background.g) * 255 <= BACKGROUND_TOLERANCE \
					and absf(pixel.b - background.b) * 255 <= BACKGROUND_TOLERANCE:
				continue
			top = mini(top, y)
			bottom = maxi(bottom, y)
			luminance += pixel.get_luminance()
			count += 1
			if pixel.get_luminance() < outline_limit:
				outline += 1
	var contrast := (luminance / maxi(count, 1)) - background.get_luminance()
	return [bottom - top + 1 if bottom >= 0 else 0, contrast, outline]


func _sizes_sheet(preset_name: String, character: Node3D, out: String) -> void:
	_pose(character, POSES[0])
	character.rotation = Vector3.ZERO
	var rows := LIGHTS.size() * BACKGROUNDS.size()
	var sheet := Image.create(CROP * HEIGHTS.size(), CROP * rows, false, Image.FORMAT_RGBA8)
	var row := 0
	for light_name: String in LIGHTS:
		for background: String in BACKGROUNDS:
			_set_look(light_name, background)
			for column in HEIGHTS.size():
				var center := _frame(character, HEIGHTS[column])
				var crop: Image = await _shot(center)
				sheet.blit_rect(crop, Rect2i(0, 0, CROP, CROP), Vector2i(column * CROP, row * CROP))
				var measured := _measure(crop, BACKGROUNDS[background])
				print("  MEDIDA %s %s %s %d px: alto %d px, contraste %.3f, contorno %d px" % [preset_name, light_name, background,
					HEIGHTS[column], measured[0], measured[1], measured[2]])
				check("%s %s %s: alto %d ± %d px" % [preset_name, light_name, background, HEIGHTS[column], HEIGHT_PX],
					absi(measured[0] - HEIGHTS[column]) <= HEIGHT_PX, "%d px" % measured[0])
				check("%s %s %s %d px: recorte de %d × %d" % [preset_name, light_name, background, HEIGHTS[column], CROP, CROP],
					crop.get_size() == Vector2i(CROP, CROP))
				check("%s %s %s %d px: hay contorno" % [preset_name, light_name, background, HEIGHTS[column]], measured[2] > 0)
			row += 1
	_save(sheet, out.path_join(preset_name + ".png"))


func _poses_sheet(preset_name: String, character: Node3D, out: String) -> void:
	_set_look("normal", "gris")
	var sheet := Image.create(CROP * 3, CROP * POSES.size(), false, Image.FORMAT_RGBA8)
	for row in POSES.size():
		_pose(character, POSES[row])
		for column in 3:
			character.rotation_degrees = Vector3(0, 90 * column, 0)
			var crop: Image = await _shot(_frame(character, 96))
			sheet.blit_rect(crop, Rect2i(0, 0, CROP, CROP), Vector2i(column * CROP, row * CROP))
	character.rotation = Vector3.ZERO
	_save(sheet, out.path_join(preset_name + "_poses.png"))


func _save(sheet: Image, path: String) -> void:
	sheet.save_png(path)
	var big := sheet.duplicate() as Image
	big.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	big.save_png(path.get_basename() + "_x4.png")
	print("GUARDADO ", path)
