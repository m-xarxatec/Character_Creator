extends "res://probar_normales_cara.gd"
# Maqueta 3.13a-4: cara anime como formas por rasgo sobre la malla completa (camino a). Prueba visual, sin límites.
# «cara anime» = el preset: todas las formas a 1, salvo nariz_anime (aparte).
# Necesita ventana (no --headless).
# Antes: (ulimit -v 4000000; timeout 300 blender -b -P blender/cara_anime.py -- pruebas/fase_3/salida/cara_anime/cara_anime.json)
# Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s probar_cara_anime.gd 2>&1 | grep -E 'medida|ERROR|GUARDADO')
# Capturas: pruebas/capturas/cara_anime/. hoja_ab = cara actual (arriba) contra cara anime (abajo), preset anime_femenino;
# hoja_extremos = cara anime sobre el cuerpo neutro y con cada macro al mínimo y al máximo (frente arriba, perfil abajo).
# hoja_nariz = cara anime con nariz_anime a cada valor de NOSE_VALUES (una fila por valor; frente y perfil).
# En hoja_ab y hoja_extremos, nariz_anime = 0 (su valor por defecto).
# Todas con las normales de elipsoide de la maqueta 2 (EXPORT_DEPTH) y el ojo anclado a un vértice fijo.
#
# El desplazamiento se suma a la malla en reposo, como haría una forma (aquí, después de hornear, girado y escalado
# con los huesos de cada vértice: da lo mismo). Los vértices se emparejan con los de Blender por su posición neutra.
# Medidas (mm): «cara» = cuánto se aparta cada vértice movido de la cara anime neutra, alineando por el hueso Head;
# como la forma solo se suma, es lo que la macro cambia la cara. «nariz» = lo que sobresale la punta de su borde.

const DATA := "pruebas/fase_3/salida/cara_anime/cara_anime.json"
const MATCH := 10000.0  # casillas de 0,1 mm para emparejar posiciones
const NOSE_VALUES := [0.0, 0.5]
const EXTREMES := [["neutro", {}], ["gender_0", {"gender": 0.0}], ["gender_1", {"gender": 1.0}],
	["weight_0", {"weight": 0.0}], ["weight_1", {"weight": 1.0}], ["muscle_0", {"muscle": 0.0}], ["muscle_1", {"muscle": 1.0}]]

var anime := {}  # forma → desplazamiento de cada vértice de Godot, en reposo
var face := PackedInt32Array()  # vértices movidos
var eye_anchor := {}  # lado (−1 o 1) → vértice
var nose_tip: int
var nose_ring := PackedInt32Array()
var by_position := {}


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	out = root_dir.path_join("pruebas/capturas/cara_anime")
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
	if not _load_anime():
		quit(1)
		return
	_build_view()
	await _ab_sheet()
	await _extremes_sheet()
	await _nose_sheet()
	quit(0)


# --- Datos ---------------------------------------------------------------------------------------------------------

func _load_anime() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root_dir.path_join(DATA)))
	var rest: PackedVector3Array = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in rest.size():
		var key := Vector3i((rest[i] * MATCH).round())
		if not by_position.has(key):
			by_position[key] = []
		by_position[key].append(i)
	var used := {}
	for name: String in data["shapes"]:
		var shape := PackedVector3Array()
		shape.resize(rest.size())
		var missing := 0
		for row: Array in data["shapes"][name]:
			var found := _find(rest, Vector3(row[1], row[2], row[3]))
			if found.is_empty():
				missing += 1
			for i in found:
				used[i] = true
				shape[i] = Vector3(row[4], row[5], row[6])
		anime[name] = shape
		print("medida emparejado %s: %d vértices de Blender, %d sin pareja" % [name, data["shapes"][name].size(), missing])
		if missing > 0:
			print("ERROR: hay vértices sin pareja; ¿cara_anime.json es de otra versión de datos/?")
			return false
	var preset := PackedVector3Array()  # las formas del preset, menos la nariz
	preset.resize(rest.size())
	for name: String in data["shapes"]:
		if name != "nariz_anime":
			var shape: PackedVector3Array = anime[name]
			for i in rest.size():
				preset[i] += shape[i]
	anime["preset"] = preset
	face = PackedInt32Array(used.keys())
	face.sort()
	var points: Dictionary = data["points"]
	eye_anchor[-1.0] = _find(rest, _vector(points["eye_anchor_r"]))[0]
	eye_anchor[1.0] = _find(rest, _vector(points["eye_anchor_l"]))[0]
	nose_tip = _find(rest, _vector(points["nose_tip"]))[0]
	for p: Array in data["nose_ring"]:
		nose_ring.append(_find(rest, _vector(p))[0])
	return true


func _vector(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## Vértices de Godot que están en esa posición neutra (a menos de 0,05 mm).
func _find(rest: PackedVector3Array, position: Vector3) -> Array:
	var key := Vector3i((position * MATCH).round())
	var found := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for i: int in by_position.get(key + Vector3i(dx, dy, dz), []):
					if rest[i].distance_to(position) < 0.00005:
						found.append(i)
	return found


# --- Personaje -----------------------------------------------------------------------------------------------------

## Como _bake, sumando el preset de cara anime (amount: todas las formas menos la nariz) y nariz_anime (nose), de 0 a 1. Añade head_origin: el hueso Head, para alinear cabezas.
func _anime_body(values: Dictionary, amount: float, nose := 0.0) -> Dictionary:
	var body := _bake(values, {})
	var vertices: PackedVector3Array = body["vertices"]
	var low: float = (baker.bake(species.mesh, species.skeleton)["vertices"] as PackedVector3Array)[0].y - vertices[0].y
	var normals: PackedVector3Array = body["normals"]
	if amount > 0.0 or nose > 0.0:
		var cara: PackedVector3Array = anime["preset"]
		var nariz: PackedVector3Array = anime["nariz_anime"]
		var arrays: Array = species.mesh.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var matrices: Array[Transform3D] = baker.skin_matrices(species.skeleton, species.mesh.skin)
		for i in face:
			var delta := amount * cara[i] + nose * nariz[i]
			var moved := Vector3.ZERO
			var total := 0.0
			for k in 4:
				moved += weights[4 * i + k] * (matrices[bones[4 * i + k]].basis * delta)
				total += weights[4 * i + k]
			vertices[i] += moved / total
		normals = _geometric_normals(vertices, normals)
	var result := _measure(vertices, normals)
	var poses: Array[Transform3D] = baker.global_poses(species.skeleton)
	result["head_origin"] = poses[species.skeleton.find_bone("Head")].origin - Vector3(0.0, low, 0.0)
	return result


## Normales nuevas de la malla movida (media de las caras, soldando las costuras UV). old solo da el sentido.
func _geometric_normals(vertices: PackedVector3Array, old: PackedVector3Array) -> PackedVector3Array:
	var indices: PackedInt32Array = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var sums := {}
	var keys: Array[Vector3i] = []
	keys.resize(vertices.size())
	for i in vertices.size():
		keys[i] = Vector3i((vertices[i] * 100000.0).round())
		sums[keys[i]] = Vector3.ZERO
	var agreement := 0.0
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var normal := (vertices[indices[t + 1]] - vertices[a]).cross(vertices[indices[t + 2]] - vertices[a])
		agreement += normal.dot(old[a])
		for e in 3:
			sums[keys[indices[t + e]]] += normal
	var result := PackedVector3Array()
	result.resize(vertices.size())
	for i in vertices.size():
		result[i] = (sums[keys[i]] as Vector3).normalized() * signf(agreement)
	return result


## Ojo de calcomanía como en probar_estilo.gd, pero anclado a un vértice fijo (no al más hundido).
func _eye(body: Dictionary, side: float) -> Decal:
	var box: AABB = body["head_box"]
	var anchor: Vector3 = (body["vertices"] as PackedVector3Array)[eye_anchor[side]]
	var width := EYE_WIDTH * box.size.x
	var decal := Decal.new()
	decal.texture_albedo = ImageTexture.create_from_image(_eye_image(side))
	decal.size = Vector3(width, 0.6 * box.size.z, width * 1.1)
	decal.rotation_degrees.x = 90.0
	decal.position = Vector3(anchor.x, anchor.y, box.end.z - 0.3 * box.size.z)
	decal.lower_fade = 0.0
	decal.upper_fade = 0.0
	return decal


func _toon_normals(body: Dictionary) -> PackedVector3Array:
	return _face_normals(body["vertices"], _smooth_normals(body["vertices"], body["normals"], SMOOTH_STEPS), 1.0, EXPORT_DEPTH)


## Lo que sobresale la punta de la nariz del borde de su zona, en mm.
func _nose(body: Dictionary) -> float:
	var vertices: PackedVector3Array = body["vertices"]
	var ring := 0.0
	for i in nose_ring:
		ring += vertices[i].z
	return 1000.0 * (vertices[nose_tip].z - ring / nose_ring.size())


# --- Capturas ------------------------------------------------------------------------------------------------------

func _ab_sheet() -> void:
	var preset := _load_preset(PRESET)
	var colors := _colors(preset)
	var rows: Array[Array] = []
	var center := Vector3.ZERO
	var head := 0.0
	for name: String in ["actual", "anime"]:
		var body := _anime_body(preset["valores"], 0.0 if name == "actual" else 1.0)
		if name == "actual":  # la misma cámara en las dos filas
			center = body["head_center"]
			head = body["height"] - body["chin"]
		print("medida %s (%s): nariz %.1f mm" % [name, PRESET, _nose(body)])
		var normals := _toon_normals(body)
		var row := []
		for view: String in VIEWS:
			var model := _model(body, normals, _toon_material(colors))
			_ortho(center.rotated(Vector3.UP, deg_to_rad(VIEWS[view])), head * 1.5)
			row.append(await _shot(model, VIEWS[view], CLOSE_TILE, "ab_%s_%s" % [name, view]))
			model.free()
		var game := _model(body, normals, _toon_material(colors))
		_game_camera(Vector3(0.0, body["height"] / 2.0, 0.0))
		row.append(await _shot(game, -25.0, GAME_TILE, "ab_%s_juego" % name))
		game.free()
		rows.append(row)
	_save(_sheet(rows), "hoja_ab")


func _extremes_sheet() -> void:
	var colors := _colors(_load_preset(PRESET))
	print("medida cara actual (neutro): nariz %.1f mm" % _nose(_anime_body({}, 0.0)))
	var reference := {}
	var rows: Array[Array] = [[], []]
	for extreme: Array in EXTREMES:
		var body := _anime_body(extreme[1], 1.0)
		if reference.is_empty():
			reference = body
		var worst := 0.0
		var total := 0.0
		var vertices: PackedVector3Array = body["vertices"]
		var neutral: PackedVector3Array = reference["vertices"]
		var shift: Vector3 = (reference["head_origin"] as Vector3) - (body["head_origin"] as Vector3)
		for i in face:
			var d := (vertices[i] + shift - neutral[i]).length()
			worst = maxf(worst, d)
			total += d
		print("medida %s: cara máx. %.1f mm / media %.1f mm; nariz %.1f mm"
			% [extreme[0], 1000.0 * worst, 1000.0 * total / face.size(), _nose(body)])
		var normals := _toon_normals(body)
		var head: float = body["height"] - body["chin"]
		var column := 0
		for view: String in ["frente", "perfil"]:
			var model := _model(body, normals, _toon_material(colors))
			_ortho((body["head_center"] as Vector3).rotated(Vector3.UP, deg_to_rad(VIEWS[view])), head * 1.5)
			rows[column].append(await _shot(model, VIEWS[view], CLOSE_TILE, "extremo_%s_%s" % [extreme[0], view]))
			model.free()
			column += 1
	_save(_sheet(rows), "hoja_extremos")


func _nose_sheet() -> void:
	var preset := _load_preset(PRESET)
	var colors := _colors(preset)
	var rows: Array[Array] = []
	for nose: float in NOSE_VALUES:
		var body := _anime_body(preset["valores"], 1.0, nose)
		print("medida nariz_anime %.1f (%s): nariz %.1f mm" % [nose, PRESET, _nose(body)])
		var normals := _toon_normals(body)
		var head: float = body["height"] - body["chin"]
		var row := []
		for view: String in ["frente", "perfil"]:
			var model := _model(body, normals, _toon_material(colors))
			_ortho((body["head_center"] as Vector3).rotated(Vector3.UP, deg_to_rad(VIEWS[view])), head * 1.5)
			row.append(await _shot(model, VIEWS[view], CLOSE_TILE, "nariz_%03d_%s" % [roundi(100.0 * nose), view]))
			model.free()
		rows.append(row)
	_save(_sheet(rows), "hoja_nariz")
