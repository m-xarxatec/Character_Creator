extends SceneTree
# Paso 9.2a: las 40 formas de cara existen, son simétricas y solo mueven cabeza y cuello.
# Uso: godot --headless --path pruebas/godot -s probar_formas_rasgos.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
# Sobre una copia de los datos: ... -s probar_formas_rasgos.gd -- <carpeta de la especie>

const FACE_ZONES := ["Ojos", "Nariz", "Boca", "Mandíbula", "Orejas"]
const FACE_ROWS := 20
const MAX_ASYMMETRY_MM := 0.5  # PROVISIONAL (medido 0,30 mm)
const MAX_OUTSIDE_MM := 0.5  # PROVISIONAL (medido 0,30 mm)

var failures := 0


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var species = load(root.path_join("godot/addons/creador/species_data.gd")).new()
	if species.load_folder(_species_folder(root)):
		print("ERROR: ", species.error)
		quit(1)
		return
	_check_face(species)
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _species_folder(root: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if FileAccess.file_exists(arg.path_join("manifiesto.json")):
			return arg
	return root.path_join("godot/datos/humana")


func check(label: String, ok: bool, detail := "") -> void:
	if not ok or detail == "":
		print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_face(species) -> void:
	var rows: Array = species.sliders.filter(func(row: Dictionary) -> bool: return row["zona"] in FACE_ZONES)
	check("%d filas de cara" % FACE_ROWS, rows.size() == FACE_ROWS, "" if rows.size() == FACE_ROWS else str(rows.size()))
	var mesh: ArrayMesh = species.mesh.mesh
	var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mirror := _mirror_map(base)
	check("cada vértice tiene su reflejo", not mirror.has(-1))
	if mirror.has(-1):
		return
	var region := _head_and_neck(species, mesh, base.size())
	var indices := {}
	for shape in mesh.get_blend_shape_count():
		indices[String(mesh.get_blend_shape_name(shape))] = shape
	var arrays := mesh.surface_get_blend_shape_arrays(0)
	var worst := [0.0, 0.0]
	var found := 0
	for row: Dictionary in rows:
		for direction in ["decr", "incr"]:
			var shape_name := "%s_%s" % [row["id"], direction]
			check("existe %s" % shape_name, indices.has(shape_name), "" if indices.has(shape_name) else "no está en el .glb")
			if indices.has(shape_name):
				found += 1
				_check_shape(shape_name, arrays[indices[shape_name]][Mesh.ARRAY_VERTEX], base, mirror, region, worst)
	check("las 40 formas", found == 40, "" if found == 40 else str(found))
	print("MEDIDA asimetría máxima: %.3f mm" % worst[0])
	print("MEDIDA fuera de cabeza y cuello: %.3f mm" % worst[1])


func _check_shape(shape_name: String, vertices: PackedVector3Array, base: PackedVector3Array, mirror: PackedInt32Array,
		region: PackedByteArray, worst: Array) -> void:
	var asymmetry := 0.0
	var outside := 0.0
	for i in base.size():
		var move := vertices[i] - base[i]
		var other := vertices[mirror[i]] - base[mirror[i]]
		asymmetry = maxf(asymmetry, (Vector3(-other.x, other.y, other.z) - move).length())
		if region[i] == 0:
			outside = maxf(outside, move.length())
	asymmetry *= 1000.0
	outside *= 1000.0
	worst[0] = maxf(worst[0], asymmetry)
	worst[1] = maxf(worst[1], outside)
	check("%s: simétrica" % shape_name, asymmetry <= MAX_ASYMMETRY_MM, "" if asymmetry <= MAX_ASYMMETRY_MM else "%.3f mm" % asymmetry)
	check("%s: solo cabeza y cuello" % shape_name, outside <= MAX_OUTSIDE_MM, "" if outside <= MAX_OUTSIDE_MM else "%.3f mm" % outside)


## Para cada vértice, el índice de su reflejo en X (-1 si no lo tiene). Compara a 0,1 mm.
func _mirror_map(base: PackedVector3Array) -> PackedInt32Array:
	var by_position := {}
	for i in base.size():
		by_position[Vector3i((base[i] * 1e4).round())] = i
	var mirror := PackedInt32Array()
	mirror.resize(base.size())
	for i in base.size():
		var key := Vector3i((base[i] * 1e4).round())
		mirror[i] = by_position.get(Vector3i(-key.x, key.y, key.z), -1)
	return mirror


## 1 en los vértices con algún peso de los huesos Head o Neck.
func _head_and_neck(species, mesh: ArrayMesh, count: int) -> PackedByteArray:
	var arrays := mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skeleton: Skeleton3D = species.skeleton
	var wanted := [skeleton.find_bone("Head"), skeleton.find_bone("Neck")]
	var skin: Skin = species.mesh.skin
	var in_region := {}
	for bind in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		in_region[bind] = bone in wanted
	var per := bones.size() / count
	var region := PackedByteArray()
	region.resize(count)
	for i in count:
		for k in per:
			if weights[i * per + k] > 0.0 and in_region[bones[i * per + k]]:
				region[i] = 1
	return region
