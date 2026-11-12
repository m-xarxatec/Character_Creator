extends SceneTree
# Paso 3.12: prueba de estilo. Prueba visual, sin límites: saca capturas y mide cuántas cabezas de alto tiene cada preset.
# Necesita ventana (no --headless).
# Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s probar_estilo.gd 2>&1 | grep -E 'medida|ERROR|GUARDADO')
# Opcional: `-- --salida=<carpeta>` guarda las capturas en otra carpeta (sin él, en la de siempre).
# Presets: pruebas/fase_3/estilo/*.json. Capturas: pruebas/capturas/estilo/ (misma luz y cámara en todas; la cámara
# encuadra a cada personaje según su altura). El personaje se hornea (mesh_baker.gd) a una malla fija para dibujarlo.

const PRESETS := ["anime_femenino", "anime_masculino", "chibi_oscuro", "chibi_fuera_de_rango"]
const VIEWS := {"frente": 0.0, "tres_cuartos": 35.0, "perfil": 90.0}
const BODY_TILE := Vector2i(800, 900)
const CLOSE_TILE := Vector2i(700, 700)
const GAME_TILE := Vector2i(1200, 800)
const SHEET_HEIGHT := 300
const SMOOTH_STEPS := 10  # normales suavizadas en el toon de los presets (ver anatomia.png)
const EYE_WIDTH := 0.27  # ancho de cada ojo, en partes del ancho de la cabeza (con orejas)
const BACKGROUND := Color(0.86, 0.87, 0.9)

var species
var shapes: GDScript
var proportions: GDScript
var refit: GDScript
var baker: GDScript
var garment_texture: GDScript
var base: Dictionary
var head_mask: PackedByteArray
var viewport: SubViewport
var camera: Camera3D
var holder: Node3D
var root_dir: String
var out: String


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
	out = _capture_folder("pruebas/capturas/estilo")
	DirAccess.make_dir_recursive_absolute(out)
	shapes = load(addon.path_join("shape_weights.gd"))
	proportions = load(addon.path_join("proportions.gd"))
	refit = load(addon.path_join("skeleton_refit.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	garment_texture = load(addon.path_join("garment_texture.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	base = refit.capture_base(species.skeleton)
	head_mask = _head_mask()
	_build_view()

	await _anatomy_sheet()
	var rows: Array[Array] = []
	for name: String in PRESETS:
		rows.append(await _preset(name))
	_save(_sheet(rows), "hoja")
	quit(0)


# --- Personaje ---------------------------------------------------------------------------------------------------

func _load_preset(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(root_dir.path_join("pruebas/fase_3/estilo/%s.json" % name)))


## Pone los valores del preset en el personaje del editor y lo hornea: {vertices, normals, height, chin, head_center}.
func _bake(values: Dictionary, extra_scales: Dictionary) -> Dictionary:
	var shape_values: Dictionary = shapes.neutral_values(species.sliders)
	var scale_values: Dictionary = proportions.neutral_values(species.sliders)
	for key: String in values:
		for target: Dictionary in [shape_values, scale_values]:
			if target.has(key) or target.has(key + "_l"):
				shapes.set_value(target, key if target.has(key) else key + "_l", values[key], true)
	var weights: Dictionary = shapes.weights(shape_values, shapes.shape_names(species.mesh.mesh))
	shapes.apply(species.mesh, weights)
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
	var scales: Dictionary = proportions.scales(scale_values, species.sliders)
	scales.merge(extra_scales, true)
	proportions.apply(species.skeleton, scales)
	var baked: Dictionary = baker.bake(species.mesh, species.skeleton)
	var vertices: PackedVector3Array = baked["vertices"]
	var low := INF
	for v in vertices:
		low = minf(low, v.y)
	for i in vertices.size():
		vertices[i].y -= low
	return _measure(vertices, baked["normals"])


func _measure(vertices: PackedVector3Array, normals: PackedVector3Array) -> Dictionary:
	var top := -INF
	var head_box := AABB()
	var first := true
	for i in vertices.size():
		top = maxf(top, vertices[i].y)
		if head_mask[i]:
			head_box = AABB(vertices[i], Vector3.ZERO) if first else head_box.expand(vertices[i])
			first = false
	var chin := INF
	for i in vertices.size():
		if head_mask[i] and absf(vertices[i].x) < 0.1 * head_box.size.x and vertices[i].z > head_box.get_center().z:
			chin = minf(chin, vertices[i].y)
	return {"vertices": vertices, "normals": normals, "height": top, "chin": chin, "head_box": head_box,
		"head_center": Vector3(0.0, (top + chin) / 2.0, head_box.get_center().z)}


## 1 en los vértices cuyo peso mayor es del hueso Head.
func _head_mask() -> PackedByteArray:
	var arrays: Array = species.mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = species.mesh.skin
	var head := -1
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		var name: String = species.skeleton.get_bone_name(bone) if bone >= 0 else String(skin.get_bind_name(i))
		if name == "Head":
			head = i
	var mask := PackedByteArray()
	mask.resize(weights.size() / 4)
	for v in mask.size():
		var best := 0
		for k in 4:
			if weights[4 * v + k] > weights[4 * v + best]:
				best = k
		mask[v] = 1 if bones[4 * v + best] == head else 0
	return mask


## Promedia cada normal con las de sus vecinos (soldando los vértices repetidos en las costuras UV), steps veces.
func _smooth_normals(vertices: PackedVector3Array, normals: PackedVector3Array, steps: int) -> PackedVector3Array:
	var indices: PackedInt32Array = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var weld := {}
	var id := PackedInt32Array()
	id.resize(vertices.size())
	for i in vertices.size():
		var key := Vector3i((vertices[i] * 100000.0).round())
		if not weld.has(key):
			weld[key] = weld.size()
		id[i] = weld[key]
	var neighbors: Array[Dictionary] = []
	neighbors.resize(weld.size())
	for n in neighbors.size():
		neighbors[n] = {}
	for t in range(0, indices.size(), 3):
		for e in 3:
			var a := id[indices[t + e]]
			var b := id[indices[t + (e + 1) % 3]]
			neighbors[a][b] = true
			neighbors[b][a] = true
	var current := PackedVector3Array()
	current.resize(weld.size())
	for i in vertices.size():
		current[id[i]] = normals[i]
	for step in steps:
		var next := current.duplicate()
		for n in current.size():
			var sum := current[n]
			for m: int in neighbors[n]:
				sum += current[m]
			next[n] = sum.normalized()
		current = next
	var result := PackedVector3Array()
	result.resize(vertices.size())
	for i in vertices.size():
		result[i] = current[id[i]]
	return result


func _static_mesh(vertices: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	var source: Array = species.mesh.mesh.surface_get_arrays(0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = source[Mesh.ARRAY_COLOR]
	arrays[Mesh.ARRAY_TEX_UV] = source[Mesh.ARRAY_TEX_UV]
	arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _colors(preset: Dictionary) -> Array[Color]:
	var c: Dictionary = preset["colores"]
	return [Color(c["skin_color"][0], c["skin_color"][1], c["skin_color"][2]),
		Color(c["garment_color"][0], c["garment_color"][1], c["garment_color"][2])]


## El material del núcleo (BodyMaterial: toon con contorno), con los dos colores del preset (la piel por defecto no interviene).
func _toon_material(colors: Array[Color]) -> ShaderMaterial:
	var body_material: GDScript = load(root_dir.path_join("godot/addons/creador/body_material.gd"))
	var holder := MeshInstance3D.new()
	var material: ShaderMaterial = body_material.apply(holder)
	body_material.set_color(holder, "skin_color", colors[0])
	body_material.set_color(holder, "garment_color", colors[1])
	holder.free()
	return material


func _normal_material(mesh: ArrayMesh, colors: Array[Color]) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(garment_texture.bake(mesh, 2048, colors[0], colors[1]))
	material.roughness = 0.8
	return material


## Modelo: la malla horneada y los ojos provisionales.
func _model(body: Dictionary, normals: PackedVector3Array, material: Material) -> Node3D:
	var model := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.mesh = _static_mesh(body["vertices"], normals)
	instance.material_override = material
	model.add_child(instance)
	for side in [-1.0, 1.0]:
		model.add_child(_eye(body, side))
	return model


## Ojo provisional: calcomanía (Decal) con un ojo anime dibujado aquí, centrada en la cuenca más honda de ese lado
## de la cara y proyectada hacia atrás (−Z). Los párpados de MakeHuman dejan una rendija pequeña: una esfera no se ve.
func _eye(body: Dictionary, side: float) -> Decal:
	var vertices: PackedVector3Array = body["vertices"]
	var normals: PackedVector3Array = body["normals"]
	var box: AABB = body["head_box"]
	var half := box.size.x / 2.0
	var head_height: float = body["height"] - body["chin"]
	var deepest := Vector3(0.0, 0.0, INF)
	for i in vertices.size():
		var v := vertices[i]
		var x := v.x * side / half
		var y: float = (v.y - body["chin"]) / head_height
		if head_mask[i] and x > 0.3 and x < 0.55 and y > 0.45 and y < 0.6 and normals[i].z > 0.3 \
				and v.z > box.get_center().z and v.z < deepest.z:
			deepest = v
	var width := EYE_WIDTH * box.size.x
	var decal := Decal.new()
	decal.texture_albedo = ImageTexture.create_from_image(_eye_image(side))
	decal.size = Vector3(width, 0.6 * box.size.z, width * 1.1)  # de la punta de la nariz hacia atrás
	decal.rotation_degrees.x = 90.0  # proyecta por su −Y: así, hacia −Z (el personaje mira a +Z)
	decal.position = Vector3(deepest.x, deepest.y, box.end.z - 0.3 * box.size.z)
	decal.lower_fade = 0.0
	decal.upper_fade = 0.0
	return decal


## Ojo anime sencillo: blanco, iris grande en degradado, pupila, dos brillos y línea de pestañas gruesa arriba.
## side: −1 = ojo derecho del personaje (a la izquierda de la imagen); la esquina de fuera queda hacia fuera.
func _eye_image(side: float) -> Image:
	var n := 256
	var image := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var lash := Color(0.1, 0.06, 0.08)
	var iris_dark := Color(0.2, 0.1, 0.08)
	var iris_light := Color(0.62, 0.38, 0.22)
	for py in n:
		for px in n:
			var p := Vector2((px + 0.5) / n * 2.0 - 1.0, (py + 0.5) / n * 2.0 - 1.0)  # y hacia abajo
			p.x *= -side  # esquina de fuera a la derecha de la imagen
			var white := (p - Vector2(0.0, 0.08)) / Vector2(0.92, 0.62)
			var c := Color(0, 0, 0, 0)
			if white.length() < 1.0:
				c = Color(0.98, 0.97, 0.97)
				var iris := (p - Vector2(-0.05, 0.08)) / Vector2(0.44, 0.62)
				if iris.length() < 1.0:
					c = iris_dark.lerp(iris_light, clampf((p.y + 0.3) / 0.9, 0.0, 1.0))
					if ((p - Vector2(-0.05, 0.12)) / Vector2(0.17, 0.3)).length() < 1.0:
						c = Color(0.05, 0.03, 0.03)
				if (p - Vector2(-0.2, -0.15)).length() < 0.13 or (p - Vector2(0.12, 0.35)).length() < 0.06:
					c = Color.WHITE
			if white.length() >= 0.9 and white.length() < 1.18 and p.y < 0.1 or \
					(p.x > 0.75 and p.x < 1.0 and p.y > -0.45 + 0.6 * (p.x - 0.75) and p.y < -0.3 + 0.2 * (p.x - 0.75)):
				c = lash
			image.set_pixel(px, py, c)
	return image


# --- Vista -------------------------------------------------------------------------------------------------------

func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.45
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.look_at_from_position(Vector3(-1.2, 1.6, 2.0), Vector3.ZERO)  # arriba, a la izquierda y delante
	camera = Camera3D.new()
	viewport.add_child(camera)
	holder = Node3D.new()
	viewport.add_child(holder)


## Ortogonal, mirando de frente al punto center, abarcando size metros de alto.
func _ortho(center: Vector3, size: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.position = center + Vector3(0.0, 0.0, 10.0)
	camera.rotation = Vector3.ZERO


## Cámara del juego: desde arriba a 45°, a 6 m del centro del personaje.
func _game_camera(target: Vector3) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 35.0
	camera.look_at_from_position(target + Vector3(0.0, 1.0, 1.0).normalized() * 6.0, target)


func _shot(model: Node3D, yaw: float, tile: Vector2i, file: String) -> Image:
	viewport.size = tile
	model.rotation_degrees.y = yaw
	holder.add_child(model)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	holder.remove_child(model)
	_save(image, file)
	return image


func _save(image: Image, file: String) -> void:
	image.save_png(out.path_join(file + ".png"))
	print("GUARDADO ", file)


# --- Capturas ----------------------------------------------------------------------------------------------------

## Una fila de la hoja de contacto: normal (3 vistas), toon (3 vistas), cara y juego.
func _preset(name: String) -> Array:
	var preset := _load_preset(name)
	var body := _bake(preset["valores"], preset.get("escalas_fuera_de_rango", {}))
	var height: float = body["height"]
	var head: float = height - body["chin"]
	print("medida %s: altura %.2f m, cabeza %.3f m, %.2f cabezas de alto" % [name, height, head, height / head])
	var colors := _colors(preset)
	var row := []
	var normal_mesh := _static_mesh(body["vertices"], body["normals"])
	var smooth: PackedVector3Array = _smooth_normals(body["vertices"], body["normals"], SMOOTH_STEPS)
	for style in ["normal", "toon"]:
		for view: String in VIEWS:
			var material: Material = _normal_material(normal_mesh, colors) if style == "normal" else _toon_material(colors)
			var model := _model(body, body["normals"] if style == "normal" else smooth, material)
			_ortho(Vector3(0.0, height / 2.0, 0.0), height * 1.08)
			row.append(await _shot(model, VIEWS[view], BODY_TILE, "%s_%s_%s" % [name, style, view]))
			model.free()
	var face := _model(body, smooth, _toon_material(colors))
	_ortho(body["head_center"], head * 1.5)
	row.append(await _shot(face, 0.0, CLOSE_TILE, name + "_cara"))
	if name == "chibi_fuera_de_rango":
		_ortho(Vector3(0.0, body["chin"], body["head_center"].z), head * 0.9)
		await _shot(face, 35.0, CLOSE_TILE, name + "_cuello")
	face.free()
	var game := _model(body, smooth, _toon_material(colors))
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(60.0, 60.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.62, 0.64, 0.6)
	ground.material_override = ground_material
	game.add_child(ground)
	_game_camera(Vector3(0.0, height / 2.0, 0.0))
	row.append(await _shot(game, -25.0, GAME_TILE, name + "_juego"))
	game.free()
	return row


## Anatomía con el toon: el preset masculino tal cual, con menos músculo y más grasa, y con normales suavizadas.
func _anatomy_sheet() -> void:
	var preset := _load_preset("anime_masculino")
	var colors := _colors(preset)
	var variants := [["musculo y grasa neutros", {"muscle": 0.5, "weight": 0.5}, 0],
		["preset (musculo 0,3, grasa 0,35)", {}, 0],
		["musculo 0, grasa 0,6", {"muscle": 0.0, "weight": 0.6}, 0],
		["preset + normales suavizadas x3", {}, 3],
		["preset + normales suavizadas x10", {}, 10]]
	var tiles: Array[Image] = []
	for variant: Array in variants:
		var values: Dictionary = preset["valores"].duplicate()
		values.merge(variant[1], true)
		var body := _bake(values, {})
		var normals: PackedVector3Array = body["normals"] if variant[2] == 0 \
			else _smooth_normals(body["vertices"], body["normals"], variant[2])
		print("anatomía %d: %s" % [tiles.size() / 2 + 1, variant[0]])
		for yaw in [0.0, 35.0]:
			var model := _model(body, normals, _toon_material(colors))
			_ortho(Vector3(0.0, body["height"] * 0.66, 0.0), body["height"] * 0.42)
			tiles.append(await _shot(model, yaw, CLOSE_TILE, "anatomia_%d_%s" % [tiles.size() / 2 + 1, "frente" if yaw == 0.0 else "tres_cuartos"]))
			model.free()
	var columns: Array[Array] = []
	for i in range(0, tiles.size(), 2):
		columns.append([tiles[i], tiles[i + 1]])
	_save(_grid_by_columns(columns), "anatomia")


# --- Hojas -------------------------------------------------------------------------------------------------------

func _scaled(image: Image, height: int) -> Image:
	var copy := image.duplicate() as Image
	copy.resize(roundi(image.get_width() * float(height) / image.get_height()), height, Image.INTERPOLATE_LANCZOS)
	return copy


## Cada fila, sus imágenes de izquierda a derecha, todas a SHEET_HEIGHT de alto.
func _sheet(rows: Array[Array]) -> Image:
	var width := 0
	for row in rows:
		var w := 0
		for image: Image in row:
			w += _scaled(image, SHEET_HEIGHT).get_width()
		width = maxi(width, w)
	var sheet := Image.create_empty(width, SHEET_HEIGHT * rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for r in rows.size():
		var x := 0
		for image: Image in rows[r]:
			var small := _scaled(image, SHEET_HEIGHT)
			small.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(x, r * SHEET_HEIGHT))
			x += small.get_width()
	return sheet


func _grid_by_columns(columns: Array[Array]) -> Image:
	var rows: Array[Array] = [[], []]
	for column in columns:
		rows[0].append(column[0])
		rows[1].append(column[1])
	return _sheet(rows)
