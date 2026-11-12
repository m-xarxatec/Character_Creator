extends SceneTree
# Paso 3.5: prenda base (toon.gdshader con `unlit` y body_material.gd).
# Necesita ventana (no --headless): dibuja el cuerpo de frente y lee los píxeles.
# Uso: godot --path pruebas/godot -s probar_prenda.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Compara cada vértice que mira al frente (piel o prenda claras, lejos del borde) con el píxel donde cae.

const SIZE := 1024  # píxeles de lado
const VIEW := 2.0  # metros que abarca la imagen
const CENTER := Vector2(0.0, 0.9)
const SKIN := Color(0.9, 0.6, 0.5)
const GARMENT := Color(0.1, 0.2, 0.6)
const HALF_WIDTH := 0.14  # solo tronco, cabeza y piernas: nada los tapa de frente
const EDGE_HALF_WIDTH := 0.08
const EDGE_MAX_PX := 2  # a 1024 px = 4 mm (medido: 1 px); aprobado el 2026-11-11

var failures := 0
var viewport: SubViewport
var species
var material: GDScript
var shapes: GDScript


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	material = load(addon.path_join("body_material.gd"))
	shapes = load(addon.path_join("shape_weights.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	_build_view()
	var mesh: MeshInstance3D = species.mesh
	var body: ShaderMaterial = material.apply(mesh)
	material.set_unlit(mesh, true)  # color exacto: sin luces ni contorno
	body.set_shader_parameter("skin_color", SKIN)
	body.set_shader_parameter("garment_color", GARMENT)
	check("interruptor: visible al empezar", material.is_garment_visible(mesh))

	var image := await _render()
	_check_vertices("prenda visible", image, true)
	_check_two_colors(image)
	_check_edge(image)

	var values: Dictionary = shapes.neutral_values(species.sliders)
	shapes.set_value(values, "hip_width", 1.0, false)
	shapes.set_value(values, "weight", 1.0, false)
	shapes.apply(mesh, shapes.weights(values, shapes.shape_names(mesh.mesh), shapes.neutral_values(species.sliders)))
	_check_vertices("caderas anchas y grasa al máximo: la prenda sigue al cuerpo", await _render(), true)
	shapes.apply(mesh, {})

	material.set_garment_visible(mesh, false)
	check("interruptor: oculta", not material.is_garment_visible(mesh))
	_check_vertices("prenda oculta: todo piel", await _render(), false)
	material.set_garment_visible(mesh, true)
	check("interruptor: visible otra vez", material.is_garment_visible(mesh))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(species.scene)
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


func _check_vertices(label: String, image: Image, garment_shown: bool) -> void:
	var mesh: MeshInstance3D = species.mesh
	var arrays := mesh.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = mesh.bake_mesh_from_current_blend_shape_mix().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var counted := [0, 0]  # piel, prenda
	var wrong := 0
	for i in positions.size():
		var value := colors[i].r
		if normals[i].z < 0.8 or absf(arrays[Mesh.ARRAY_VERTEX][i].x) > HALF_WIDTH or (value > 0.01 and value < 0.99):
			continue
		var is_garment := value > 0.5
		counted[int(is_garment)] += 1
		var expected := GARMENT if is_garment and garment_shown else SKIN
		if not _same(image.get_pixelv(_pixel(positions[i])), expected):
			wrong += 1
	check(label, wrong == 0 and counted[0] > 100 and counted[1] > 100,
		"%d vértices de piel y %d de prenda; %d píxeles con otro color" % [counted[0], counted[1], wrong])


func _check_two_colors(image: Image) -> void:
	var other := 0
	var seen := [0, 0]
	for y in SIZE:
		for x in SIZE:
			var c := image.get_pixel(x, y)
			if c.a < 0.01:
				continue
			if _same(c, SKIN):
				seen[0] += 1
			elif _same(c, GARMENT):
				seen[1] += 1
			else:
				other += 1
	check("solo dos colores, sin mezcla en el borde", other == 0 and seen[0] > 0 and seen[1] > 0,
		"%d píxeles de piel, %d de prenda, %d de otro color" % [seen[0], seen[1], other])


## Borde de arriba de la prenda de abajo: de arriba abajo, la segunda vez que la piel pasa a prenda (la primera es el top).
func _check_edge(image: Image) -> void:
	var rows: Array[int] = []
	var half := roundi(EDGE_HALF_WIDTH * SIZE / VIEW)
	for x in range(SIZE / 2 - half, SIZE / 2 + half):
		var changes := 0
		for y in range(1, SIZE):
			if _same(image.get_pixel(x, y - 1), SKIN) and _same(image.get_pixel(x, y), GARMENT):
				changes += 1
				if changes == 2:
					rows.append(y)
					break
	var mm := 1000.0 * VIEW / SIZE
	if rows.is_empty():
		check("se encuentra el borde de la prenda de abajo", false)
		return
	var change: int = rows.max() - rows.min()
	check("borde de la cintura recto en 16 cm (≤ %d px a %d px)" % [EDGE_MAX_PX, SIZE], change <= EDGE_MAX_PX and SIZE == 1024,
		"%d columnas: varía %d px = %.1f mm" % [rows.size(), change, change * mm])
