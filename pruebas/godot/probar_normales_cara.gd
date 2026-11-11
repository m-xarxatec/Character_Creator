extends "res://probar_estilo.gd"
# Maqueta 3.13a-2: normales de elipsoide en la cara, para que el toon no la corte en manchas. Prueba visual, sin pulir.
# Necesita ventana (no --headless).
# Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s probar_normales_cara.gd 2>&1 | grep -E 'medida|ERROR|GUARDADO')
# Capturas: pruebas/capturas/normales_cara/ (antes = normales suavizadas del 3.12; mezcla = 50 %; elipsoide = 100 %).
# Aplanado (aplanado_*.png y aplanado_hoja.png): elipsoide al 100 % con menos fondo por delante (DEPTHS), para que
# las normales de la cara miren más al frente y el corte de tono se vaya al borde.
# Escribe pruebas/fase_3/salida/normales/cara.glb (pose T, con las normales al 100 %) y cara_normales.json (lo enviado).
# Después: probar_normales_leidas.gd, pruebas/fase_3/probar_normales_importador.sh y probar_normales_en_blender.py.
#
# Normal de elipsoide: la de un elipsoide con el centro y el tamaño de la caja de la cabeza. Se mezcla con la normal
# de la malla según el peso del hueso Head de cada vértice: en el cuello pasa poco a poco a la normal de siempre.

const PRESET := "anime_femenino"
const BLENDS := {"antes": 0.0, "mezcla": 0.5, "elipsoide": 1.0}
const DEPTHS := {"aplanado_100": 1.0, "aplanado_060": 0.6, "aplanado_035": 0.35}  # fondo del elipsoide por delante
const EXPORT_DEPTH := 0.6  # el que va en cara.glb

var head_weight: PackedFloat32Array


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	out = root_dir.path_join("pruebas/capturas/normales_cara")
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
	_export(load(addon.path_join("glb_exporter.gd")))
	quit(0)


## Peso del hueso Head en cada vértice (0 a 1).
func _head_weight() -> PackedFloat32Array:
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
	var result := PackedFloat32Array()
	result.resize(weights.size() / 4)
	for v in result.size():
		for k in 4:
			if bones[4 * v + k] == head:
				result[v] += weights[4 * v + k]
	return result


## Mezcla cada normal con la del elipsoide de la cabeza: amount × peso de Head.
## depth < 1 quita fondo al elipsoide solo por delante: las normales de la cara miran más al frente.
func _face_normals(vertices: PackedVector3Array, normals: PackedVector3Array, amount: float, depth := 1.0) -> PackedVector3Array:
	var box := AABB()
	var first := true
	for i in vertices.size():
		if head_weight[i] > 0.5:
			box = AABB(vertices[i], Vector3.ZERO) if first else box.expand(vertices[i])
			first = false
	var center := box.get_center()
	var radii := box.size / 2.0
	var result := normals.duplicate()
	for i in vertices.size():
		var w := head_weight[i] * amount
		if w > 0.0:
			var offset := vertices[i] - center
			var r := radii
			if offset.z > 0.0:
				r.z *= depth
			var ellipsoid := (offset / (r * r)).normalized()
			result[i] = normals[i].lerp(ellipsoid, w).normalized()
	return result


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
func _flatten_captures() -> void:
	var preset := _load_preset(PRESET)
	var body := _bake(preset["valores"], {})
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
			row.append(await _shot(model, VIEWS[view], CLOSE_TILE, "%s_%s" % [name, view]))
			model.free()
		var game := _model(body, normals, _toon_material(colors))
		_game_camera(Vector3(0.0, body["height"] / 2.0, 0.0))
		row.append(await _shot(game, -25.0, GAME_TILE, name + "_juego"))
		game.free()
		rows.append(row)
	_save(_sheet(rows), "aplanado_hoja")


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
	var normals := _face_normals(vertices, _smooth_normals(vertices, arrays[Mesh.ARRAY_NORMAL], SMOOTH_STEPS), 1.0, EXPORT_DEPTH)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, instance.mesh.surface_get_material(0))
	instance.mesh = mesh
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
