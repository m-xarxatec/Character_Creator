extends "res://probar_estilo.gd"
# Maqueta 3.13a-2: normales de elipsoide en la cara, para que el toon no la corte en manchas. Prueba visual, sin pulir.
# Necesita ventana (no --headless).
# Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s probar_normales_cara.gd 2>&1 | grep -E 'medida|ERROR|GUARDADO')
# Opcional: `-- --salida=<carpeta>` guarda las capturas en otra carpeta (sin él, en la de siempre).
# Capturas: pruebas/capturas/normales_cara/ (antes = normales suavizadas del 3.12; mezcla = 50 %; elipsoide = 100 %).
# Aplanado (aplanado_*.png y aplanado_hoja.png): elipsoide al 100 % con menos fondo por delante (DEPTHS), para que
# las normales de la cara miren más al frente y el corte de tono se vaya al borde. aplanado_anime_*: lo mismo con la
# cara anime (formas de cara de presets/anime.json; paso 3.16, para revisar el 0,6).
# Escribe pruebas/fase_3/salida/normales/cara.glb (pose T, con las normales del núcleo, GlbExporter) y cara_normales.json (lo enviado).
# Después: probar_normales_leidas.gd, pruebas/fase_3/probar_normales_importador.sh y probar_normales_en_blender.py.
#
# Normal de elipsoide: la de un elipsoide con el centro y el tamaño de la caja de la cabeza. Se mezcla con la normal
# de la malla según el peso del hueso Head de cada vértice: en el cuello pasa poco a poco a la normal de siempre.

const PRESET := "anime_femenino"
const BLENDS := {"antes": 0.0, "mezcla": 0.5, "elipsoide": 1.0}
const DEPTHS := {"aplanado_100": 1.0, "aplanado_060": 0.6, "aplanado_035": 0.35}  # fondo del elipsoide por delante

var head_weight: PackedFloat32Array


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	out = _capture_folder("pruebas/capturas/normales_cara")
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
	head_weight = _head_weight()
	_build_view()
	await _captures()
	await _flatten_captures()
	_export(load(addon.path_join("glb_exporter.gd")))  # antes de la cara anime: cara.glb sigue siendo el del 3.13a-2
	await _flatten_captures("aplanado_anime", _anime_face())
	quit(0)


## Peso del hueso Head y normales de elipsoide: las del núcleo (StyleNormals, paso 3.16).
func _head_weight() -> PackedFloat32Array:
	var arrays: Array = species.mesh.mesh.surface_get_arrays(0)
	return _style().head_weights(arrays, species.mesh.skin, species.skeleton)


## Mezcla cada normal con la del elipsoide de la cabeza: amount × peso de Head; depth < 1 quita fondo por delante.
func _face_normals(vertices: PackedVector3Array, normals: PackedVector3Array, amount: float, depth := 1.0) -> PackedVector3Array:
	return _style().face(vertices, normals, head_weight, amount, depth)


func _style() -> GDScript:
	return load(root_dir.path_join("godot/addons/creador/style_normals.gd"))


func _captures() -> void:
	var preset := _load_preset(PRESET)
	var body := _bake(preset["valores"], {})
	var colors := _colors(preset)
	var smooth := _smooth_normals(body["vertices"], body["normals"], SMOOTH_STEPS)
	var head: float = body["height"] - body["chin"]
	var rows: Array[Array] = []
	for name: String in BLENDS:
		var normals := _face_normals(body["vertices"], smooth, BLENDS[name])
		var row := []
		for view: String in VIEWS:
			var model := _model(body, normals, _toon_material(colors))
			_ortho((body["head_center"] as Vector3).rotated(Vector3.UP, deg_to_rad(VIEWS[view])), head * 1.5)
			row.append(await _shot(model, VIEWS[view], CLOSE_TILE, "%s_%s" % [name, view]))
			model.free()
		var game := _model(body, normals, _toon_material(colors))
		_game_camera(Vector3(0.0, body["height"] / 2.0, 0.0))
		row.append(await _shot(game, -25.0, GAME_TILE, name + "_juego"))
		game.free()
		rows.append(row)
	_save(_sheet(rows), "hoja")


## A/B del aplanado: una fila por valor de DEPTHS, de frente, en tres cuartos y con la cámara del juego.
## prefix "aplanado_anime" + face: lo mismo con la cara anime (paso 3.16).
func _flatten_captures(prefix := "aplanado", face := {}) -> void:
	var preset := _load_preset(PRESET)
	var values: Dictionary = preset["valores"].duplicate()
	values.merge(face, true)
	var body := _bake(values, {})
	var colors := _colors(preset)
	var smooth := _smooth_normals(body["vertices"], body["normals"], SMOOTH_STEPS)
	var head: float = body["height"] - body["chin"]
	var rows: Array[Array] = []
	for name: String in DEPTHS:
		var normals := _face_normals(body["vertices"], smooth, 1.0, DEPTHS[name])
		var row := []
		for view: String in ["frente", "tres_cuartos"]:
			var model := _model(body, normals, _toon_material(colors))
			_ortho((body["head_center"] as Vector3).rotated(Vector3.UP, deg_to_rad(VIEWS[view])), head * 1.5)
			row.append(await _shot(model, VIEWS[view], CLOSE_TILE, "%s_%s" % [name.replace("aplanado", prefix), view]))
			model.free()
		var game := _model(body, normals, _toon_material(colors))
		_game_camera(Vector3(0.0, body["height"] / 2.0, 0.0))
		row.append(await _shot(game, -25.0, GAME_TILE, name.replace("aplanado", prefix) + "_juego"))
		game.free()
		rows.append(row)
	_save(_sheet(rows), prefix + "_hoja")


## Valores de las formas de cara (zona Cara) del preset de personaje nuevo (presets/anime.json).
func _anime_face() -> Dictionary:
	var values: Dictionary = JSON.parse_string(species.preset_text())["valores"]
	var face := {}
	for row: Dictionary in species.sliders:
		if row["zona"] == "Cara":
			face[row["id"]] = values[row["id"]]
	return face


## Exporta el personaje del preset (pose T) con las normales de elipsoide en la malla, y guarda lo enviado en un JSON.
func _export(exporter: GDScript) -> void:
	var folder := root_dir.path_join("pruebas/fase_3/salida/normales")
	DirAccess.make_dir_recursive_absolute(folder)
	var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)
	var instance := character.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays := instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() != head_weight.size():
		print("ERROR: la malla exportada tiene otro número de vértices")
		return
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]  # las del núcleo: GlbExporter las pone (paso 3.16)
	exporter._add_armature_node(character)
	exporter._set_owner(character, character)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(character, state)
	if error == OK:
		error = document.write_to_filesystem(state, folder.path_join("cara.glb"))
	character.free()
	if error != OK:
		print("ERROR: no se pudo escribir cara.glb (", error, ")")
		return
	var positions := []
	var sent := []
	for i in vertices.size():
		positions.append_array([vertices[i].x, vertices[i].y, vertices[i].z])
		sent.append_array([normals[i].x, normals[i].y, normals[i].z])
	var file := FileAccess.open(folder.path_join("cara_normales.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"positions": positions, "normals": sent, "head_weight": Array(head_weight)}))
	print("GUARDADO cara.glb y cara_normales.json")
