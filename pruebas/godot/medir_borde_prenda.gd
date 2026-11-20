extends SceneTree
# Paso B0.4: cuánto se ondula el borde de la prenda en primeros planos (a 0,5 m), en el editor y en el .glb exportado.
# Necesita ventana (no --headless). Solo mide: no tiene límites (ruta/pasos/B0.4_borde_prenda.md).
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s medir_borde_prenda.gd 2>&1 | grep -E 'MEDIDA|GUARDADO|ERROR')
# Hoja pruebas/capturas/borde_prenda/hoja.png: filas = BORDERS (de arriba abajo), columnas = VARIANTS (de izquierda
# a derecha). Sin luces ni contorno: piel y prenda de color exacto.

const TILE := 512
const DISTANCE := 0.5  # metros de la cámara al borde
const FOV := 35.0
const SKIN := Color(0.9, 0.6, 0.5)
const GARMENT := Color(0.1, 0.2, 0.6)
const WINDOW := 20  # columnas a cada lado para la media de la ondulación
const BORDERS := ["pecho arriba", "pecho abajo", "cintura"]
const VARIANTS := ["editor", "sin degradado", "editor + fwidth", "exportado 2048", "exportado 4096"]
const STEP_CUT := "float garment = show_garment ? step(0.5, min(COLOR.r, COLOR.a)) : 0.0;"
const FWIDTH_CUT := "float g = min(COLOR.r, COLOR.a); float w = max(fwidth(g), 1e-4);\n\tfloat garment = show_garment ? smoothstep(0.5 - w, 0.5 + w, g) : 0.0;"

var root_dir: String
var addon: String
var species
var body_material: GDScript
var viewport: SubViewport
var camera: Camera3D


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	addon = root_dir.path_join("godot/addons/creador")
	body_material = load(addon.path_join("body_material.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	_build_view()
	var subjects := _subjects()
	if subjects.is_empty():
		quit(1)
		return
	var rows: Array[Image] = []
	for border: Dictionary in _borders():
		var tiles: Array[Image] = []
		for variant: String in VARIANTS:
			for name: String in subjects:
				subjects[name].visible = name == variant
			camera.look_at_from_position(border["point"] + Vector3(0, 0, DISTANCE), border["point"])
			var image := await _render()
			_report(border["name"], variant, image)
			tiles.append(image)
		rows.append(_join(tiles, true))
	var folder := root_dir.path_join("pruebas/capturas/borde_prenda")
	DirAccess.make_dir_recursive_absolute(folder)
	_join(rows, false).save_png(folder.path_join("hoja.png"))
	print("GUARDADO: ", folder.path_join("hoja.png"))
	quit()


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(TILE, TILE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.05
	viewport.add_child(camera)


## {variante: nodo}: el cuerpo del personaje nuevo (neutro con alisado) quieto en pose A, y el mismo exportado.
func _subjects() -> Dictionary:
	var shapes: GDScript = load(addon.path_join("shape_weights.gd"))
	var mesh: MeshInstance3D = species.mesh
	var values: Dictionary = shapes.neutral_values(species.sliders)
	shapes.set_value(values, "alisado", 1.0, false)
	shapes.apply(mesh, shapes.weights(values, shapes.shape_names(mesh.mesh), shapes.neutral_values(species.sliders)))
	body_material.apply(mesh)
	body_material.set_color(mesh, "skin_color", SKIN)
	body_material.set_color(mesh, "garment_color", GARMENT)
	var baked: ArrayMesh = mesh.bake_mesh_from_current_blend_shape_mix()
	var arrays := baked.surface_get_arrays(0)
	var rounded: PackedColorArray = arrays[Mesh.ARRAY_COLOR].duplicate()
	for i in rounded.size():
		var value := 1.0 if rounded[i].r > 0.5 else 0.0
		rounded[i] = Color(value, value, value, 1.0)
	var editor := _static(baked, null)
	var smooth: ShaderMaterial = editor.material_override.duplicate()
	smooth.shader = Shader.new()
	smooth.shader.code = body_material.SHADER.code.replace(STEP_CUT, FWIDTH_CUT)
	if smooth.shader.code == body_material.SHADER.code:
		print("ERROR: toon.gdshader ya no tiene la línea del corte (STEP_CUT)")
		return {}
	var subjects := {"editor": editor, "sin degradado": _static(baked, rounded), "editor + fwidth": _static(baked, null)}
	subjects["editor + fwidth"].material_override = smooth
	var exporter: GDScript = load(addon.path_join("glb_exporter.gd"))
	var garment_texture: GDScript = load(addon.path_join("garment_texture.gd"))
	for size in [2048, 4096]:
		var character: Node3D = exporter.build(mesh, species.skeleton, species.manifest["bones"]["sockets"], false)
		var body: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
		var plain: StandardMaterial3D = body.get_active_material(0).duplicate()
		plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if size != exporter.TEXTURE_SIZE:
			plain.albedo_texture = ImageTexture.create_from_image(garment_texture.bake(baked, size, SKIN, GARMENT))
		body.material_override = plain
		viewport.add_child(character)
		subjects["exportado %d" % size] = character
	mesh.get_parent().remove_child(mesh)  # el del editor no se dibuja: lo sustituyen las copias quietas
	return subjects


## Copia quieta de la malla (sin esqueleto ni formas), con el material del editor sin luces; colors: otro `garment`.
func _static(baked: ArrayMesh, colors: Variant) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if colors == null:
		instance.mesh = baked
	else:
		var arrays := baked.surface_get_arrays(0)
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		instance.mesh = mesh
	body_material.apply(instance)
	body_material.set_color(instance, "skin_color", SKIN)
	body_material.set_color(instance, "garment_color", GARMENT)
	body_material.set_unlit(instance, true)
	viewport.add_child(instance)
	return instance


## [{name, point}]: dónde corta 0,5 el `garment` de los vértices de delante por la línea del centro, de arriba abajo.
func _borders() -> Array[Dictionary]:
	var mesh: MeshInstance3D = species.mesh
	var arrays := mesh.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = mesh.bake_mesh_from_current_blend_shape_mix().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var front: Array = []
	for i in positions.size():
		if absf(positions[i].x) < 0.02 and arrays[Mesh.ARRAY_NORMAL][i].z > 0.7:
			front.append([positions[i], arrays[Mesh.ARRAY_COLOR][i].r])
	front.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y > b[0].y)
	var found: Array[Dictionary] = []
	for i in range(1, front.size()):
		var a: Array = front[i - 1]
		var b: Array = front[i]
		if (a[1] > 0.5) != (b[1] > 0.5) and found.size() < BORDERS.size():
			var t: float = (0.5 - a[1]) / (b[1] - a[1])
			var point: Vector3 = a[0].lerp(b[0], t)
			found.append({"name": BORDERS[found.size()], "point": Vector3(0.0, point.y, point.z)})
	return found


func _render() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


## MEDIDA de una imagen: en cada columna, la fila donde la piel pasa a prenda más cerca del centro; ondulación = la
## mayor distancia a la media de sus vecinas; escalón = el mayor salto entre dos columnas seguidas.
func _report(border: String, variant: String, image: Image) -> void:
	var rows: Array[int] = []
	for x in range(roundi(TILE * 0.15), roundi(TILE * 0.85)):
		rows.append(_transition(image, x))
	var wave := 0.0
	var step := 0
	var valid := 0
	var zigzag := 0.0  # media de |y[i-1] - 2 y[i] + y[i+1]|: solo ve los dientes, no la forma de la banda
	var bends := 0
	for i in rows.size():
		if rows[i] < 0:
			continue
		valid += 1
		if i > 0 and rows[i - 1] >= 0:
			step = maxi(step, absi(rows[i] - rows[i - 1]))
		if i > 0 and i < rows.size() - 1 and rows[i - 1] >= 0 and rows[i + 1] >= 0:
			zigzag += absi(rows[i - 1] - 2 * rows[i] + rows[i + 1])
			bends += 1
		var total := 0.0
		var count := 0
		for j in range(maxi(0, i - WINDOW), mini(rows.size(), i + WINDOW + 1)):
			if rows[j] >= 0:
				total += rows[j]
				count += 1
		wave = maxf(wave, absf(rows[i] - total / count))
	var mm := 1000.0 * 2.0 * DISTANCE * tan(deg_to_rad(FOV / 2.0)) / TILE
	print("MEDIDA %s, %s: ondulación %.1f px (%.1f mm), zigzag %.2f px, escalón %d px, %d de %d columnas" % [
		border, variant, wave, wave * mm, zigzag / maxi(bends, 1), step, valid, rows.size()])


## Fila (más cerca del centro) donde cambia piel ↔ prenda en la columna x; -1 si no hay.
func _transition(image: Image, x: int) -> int:
	var best := -1
	for y in range(1, TILE):
		var a := image.get_pixel(x, y - 1)
		var b := image.get_pixel(x, y)
		if a.a > 0.5 and b.a > 0.5 and _is_garment(a) != _is_garment(b):
			if best < 0 or absi(y - TILE / 2) < absi(best - TILE / 2):
				best = y
	return best


func _is_garment(color: Color) -> bool:
	return _distance(color, GARMENT) < _distance(color, SKIN)


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _join(images: Array[Image], across: bool) -> Image:
	var first := images[0]
	var size := Vector2i(first.get_width() * (images.size() if across else 1), first.get_height() * (1 if across else images.size()))
	var sheet := Image.create(size.x, size.y, false, first.get_format())
	for i in images.size():
		var at := Vector2i(i * first.get_width(), 0) if across else Vector2i(0, i * first.get_height())
		sheet.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), at)
	return sheet
