extends SceneTree
# Paso 3.6.6: la prenda base se ve en el .glb exportado, leído sin el addon (solo GLTFDocument).
# Necesita ventana (no --headless): dibuja el cuerpo de frente y lee los píxeles, como probar_prenda.gd.
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s probar_prenda_exportada.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|medida')
# Escribe pruebas/fase_3/salida/prenda/visible.glb y oculta.glb (pose A, cuerpo neutro), que usa probar_glb_en_blender.py.
# Capturas: pruebas/capturas/prenda_exportada/, o la carpeta de `-- --salida=<carpeta>`.

const SIZE := 1024  # píxeles de lado
const VIEW := 2.0  # metros que abarca la imagen
const CENTER := Vector2(0.0, 0.9)
const SKIN := Color(0.9, 0.6, 0.5)
const GARMENT := Color(0.1, 0.2, 0.6)
const HALF_WIDTH := 0.14  # solo tronco, cabeza y piernas: nada los tapa de frente
const EDGE_HALF_WIDTH := 0.08

var failures := 0
var viewport: SubViewport
var root_dir: String
var captures: String


## Carpeta de capturas: la de siempre, o la de `-- --salida=<carpeta>` (ruta absoluta, o relativa a la raíz del proyecto).
func _capture_folder(default_folder: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--salida="):
			var folder := arg.trim_prefix("--salida=")
			return folder if folder.is_absolute_path() else root_dir.path_join(folder)
	return root_dir.path_join(default_folder)


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	var species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	var material: GDScript = load(addon.path_join("body_material.gd"))
	var body: ShaderMaterial = material.apply(species.mesh)
	body.set_shader_parameter("skin_color", SKIN)
	body.set_shader_parameter("garment_color", GARMENT)
	var exporter: GDScript = load(addon.path_join("glb_exporter.gd"))
	var out := root_dir.path_join("pruebas/fase_3/salida/prenda")
	DirAccess.make_dir_recursive_absolute(out)
	captures = _capture_folder("pruebas/capturas/prenda_exportada")
	DirAccess.make_dir_recursive_absolute(captures)
	_build_view()

	for shown in [true, false]:
		material.set_garment_visible(species.mesh, shown)
		var path := out.path_join("visible.glb" if shown else "oculta.glb")
		var start := Time.get_ticks_msec()
		var error: Error = exporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], path, false)
		check(path.get_file() + ": se exporta", error == OK, "%.1f s, %.2f MB" % [
			(Time.get_ticks_msec() - start) / 1000.0, FileAccess.get_file_as_bytes(path).size() / 1e6])
		await _check_file(path, shown)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_file(path: String, shown: bool) -> void:
	var label := path.get_file() + ": "
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		check(label + "se vuelve a leer", false)
		return
	var scene := document.generate_scene(state)
	var mesh := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var standard := mesh.get_active_material(0) as StandardMaterial3D
	var texture := standard.albedo_texture if standard else null
	var size := texture.get_size() if texture else Vector2.ZERO
	check(label + "material sin luces, sin color por vértice, %s" % ("textura de 2048 px" if shown else "sin textura"),
		standard != null and standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		and not standard.vertex_color_use_as_albedo and (size == Vector2(2048, 2048) if shown else texture == null),
		"textura %s, color %s" % [size, standard.albedo_color if standard else null])
	# El alfa del color por vértice guarda `garment`: el material debe ser opaco (sin alphaMode = OPAQUE en glTF).
	var modes: Array = state.json["materials"].map(func(m: Dictionary) -> String: return m.get("alphaMode", "OPAQUE"))
	check(label + "material opaco (alphaMode OPAQUE)", modes == ["OPAQUE"], str(modes))
	viewport.add_child(scene)
	var image := await _render()
	image.save_png(captures.path_join(path.get_file().get_basename() + ".png"))
	_check_vertices(label + "cada vértice de frente cae en un píxel de su color", image, mesh, shown)
	if shown:
		_measure_edge(label, image)
	scene.queue_free()
	await process_frame


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW
	camera.position = Vector3(CENTER.x, CENTER.y, 3.0)  # el personaje mira a +Z
	viewport.add_child(camera)


func _render() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _pixel(point: Vector3) -> Vector2i:
	var scale := SIZE / VIEW
	return Vector2i(roundi(SIZE / 2.0 + (point.x - CENTER.x) * scale - 0.5), roundi(SIZE / 2.0 - (point.y - CENTER.y) * scale - 0.5))


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02 and a.a > 0.98


func _check_vertices(label: String, image: Image, mesh: MeshInstance3D, shown: bool) -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var to_scene := mesh.global_transform
	var counted := [0, 0]  # piel, prenda
	var wrong := 0
	var white := true
	for color in colors:
		white = white and color.r == 1.0 and color.g == 1.0 and color.b == 1.0
	check(label.get_slice(":", 0) + ": color por vértice: RGB blanco (no tiñe) y `garment` en el alfa", white)
	for i in vertices.size():
		var point := to_scene * vertices[i]
		var value := colors[i].a
		if (to_scene.basis * normals[i]).normalized().z < 0.8 or absf(point.x) > HALF_WIDTH or (value > 0.01 and value < 0.99):
			continue
		var is_garment := value > 0.5
		counted[int(is_garment)] += 1
		if not _same(image.get_pixelv(_pixel(point)), GARMENT if is_garment and shown else SKIN):
			wrong += 1
	check(label, wrong == 0 and counted[0] > 100 and counted[1] > 100,
		"%d vértices de piel y %d de prenda; %d píxeles con otro color" % [counted[0], counted[1], wrong])


## Medida (sin límite todavía): píxeles mezclados y cuánto varía el borde de la cintura, como en probar_prenda.gd.
func _measure_edge(label: String, image: Image) -> void:
	var mixed := 0
	for y in SIZE:
		for x in SIZE:
			var c := image.get_pixel(x, y)
			if c.a > 0.01 and not _same(c, SKIN) and not _same(c, GARMENT):
				mixed += 1
	var rows: Array[int] = []
	var half := roundi(EDGE_HALF_WIDTH * SIZE / VIEW)
	for x in range(SIZE / 2 - half, SIZE / 2 + half):
		var changes := 0
		for y in range(1, SIZE):
			if _is_garment(image.get_pixel(x, y)) and not _is_garment(image.get_pixel(x, y - 1)) and image.get_pixel(x, y - 1).a > 0.5:
				changes += 1
				if changes == 2:
					rows.append(y)
					break
	if rows.is_empty():
		check(label + "se encuentra el borde de la prenda de abajo", false)
		return
	print("  medida %sborde de la cintura en 16 cm: varía %d px = %.1f mm; %d píxeles mezclados en el borde" % [
		label, rows.max() - rows.min(), (rows.max() - rows.min()) * 1000.0 * VIEW / SIZE, mixed])


func _is_garment(c: Color) -> bool:
	return c.a > 0.5 and c.b > (SKIN.b + GARMENT.b) / 2.0
