extends SceneTree
# Paso 3.11b: el .tres exportado junto al .glb funciona en un proyecto sin el addon (shaders incrustados) y el toon lee
# la prenda del alfa del .glb (min(rojo, alfa)). Necesita ventana: dibuja con luz y lee los píxeles.
# Uso: (ulimit -v 4000000; timeout 120 godot --path pruebas/godot_vacio -s probar_tres.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Antes: pruebas/godot/probar_prenda_exportada.gd (escribe pruebas/fase_3/salida/prenda/visible y oculta, .glb y .tres).
# Capturas: pruebas/capturas/tres_vacio/.

const SIZE := 1024  # píxeles de lado
const VIEW := 2.0  # metros que abarca la imagen
const CENTER := Vector2(0.0, 0.9)
const HALF_WIDTH := 0.14  # solo tronco, cabeza y piernas: nada los tapa de frente

var failures := 0
var viewport: SubViewport


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	check("proyecto sin el addon", not DirAccess.dir_exists_absolute("res://addons"))
	var captures := root_dir.path_join("pruebas/capturas/tres_vacio")
	DirAccess.make_dir_recursive_absolute(captures)
	_build_view()
	for name in ["visible", "oculta"]:
		await _check(root_dir.path_join("pruebas/fase_3/salida/prenda").path_join(name), name == "visible", captures)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check(base: String, shown: bool, captures: String) -> void:
	var label := base.get_file() + ": "
	var text := FileAccess.get_file_as_string(base + ".tres")
	var material := load(base + ".tres") as ShaderMaterial
	var outline := material.next_pass as ShaderMaterial if material else null
	check(label + ".tres sin rutas res:// y se carga con sus dos shaders",
		not text.is_empty() and not text.contains("res://") and material != null and material.shader != null
		and outline != null and outline.shader != null)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if material == null or document.append_from_file(base + ".glb", state) != OK:
		check(label + ".glb se lee", false)
		return
	var scene := document.generate_scene(state)
	var mesh := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	mesh.material_override = material
	viewport.add_child(scene)
	var image := await _render()
	image.save_png(captures.path_join(base.get_file() + ".png"))
	_check_vertices(label + "cada vértice de frente: prenda (azulada) o piel (rojiza) según el alfa", image, mesh, shown)
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
	var light := DirectionalLight3D.new()  # de frente y desde arriba
	light.rotation_degrees = Vector3(-30.0, 20.0, 0.0)
	viewport.add_child(light)


func _render() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _pixel(point: Vector3) -> Vector2i:
	var scale := SIZE / VIEW
	return Vector2i(roundi(SIZE / 2.0 + (point.x - CENTER.x) * scale - 0.5), roundi(SIZE / 2.0 - (point.y - CENTER.y) * scale - 0.5))


## Con luz el color no es exacto (tonos y rim), pero el matiz sí: piel 0,9/0,6/0,5 y prenda 0,1/0,2/0,6.
func _check_vertices(label: String, image: Image, mesh: MeshInstance3D, shown: bool) -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var to_scene := mesh.global_transform
	var counted := [0, 0]  # piel, prenda
	var wrong := 0
	for i in vertices.size():
		var point := to_scene * vertices[i]
		var value := colors[i].a
		if (to_scene.basis * normals[i]).normalized().z < 0.8 or absf(point.x) > HALF_WIDTH or (value > 0.01 and value < 0.99):
			continue
		var is_garment := value > 0.5
		counted[int(is_garment)] += 1
		var pixel := image.get_pixelv(_pixel(point))
		if pixel.a < 0.98 or (pixel.b > pixel.r) != (is_garment and shown):
			wrong += 1
	check(label, wrong == 0 and counted[0] > 100 and counted[1] > 100,
		"%d vértices de piel y %d de prenda; %d píxeles con otro color" % [counted[0], counted[1], wrong])
