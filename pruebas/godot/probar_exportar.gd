extends SceneTree
# Paso 3.6.5: exportar el personaje a .glb (glb_exporter.gd) y volver a leerlo con GLTFDocument.
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_exportar.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Escribe pruebas/fase_3/salida/t/ y a/ (pose T y pose A): neutro.glb y al_azar.glb (este, con escalas de Proporción).
# Después, sobre esos archivos:
#   godot --headless --path pruebas/godot -s probar_glb.gd -- ../fase_3/salida/t
#   godot --headless --path pruebas/godot -s probar_glb.gd -- ../fase_3/salida/a --pose-a
#   blender -b -P pruebas/fase_3/probar_glb_en_blender.py
#   pruebas/fase_3/probar_importador.sh   (importador del editor en un proyecto vacío)

const SAME_MM := 0.1
const SOCKET_DEG := 1.0
const SCALES := {
	"neutro": {},
	"al_azar": {"height": 0.3, "head_size": 0.8, "hand_size_l": 1.0, "hand_size_r": 0.0, "foot_size_l": 0.2, "foot_size_r": 0.9},
}

var failures := 0
var species
var base: Dictionary
var exporter: GDScript
var refit: GDScript
var shapes: GDScript
var proportions: GDScript
var reference: Dictionary
var socket_names: Array
var out: String


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	out = root_dir.path_join("pruebas/fase_3/salida")
	exporter = load(addon.path_join("glb_exporter.gd"))
	refit = load(addon.path_join("skeleton_refit.gd"))
	shapes = load(addon.path_join("shape_weights.gd"))
	proportions = load(addon.path_join("proportions.gd"))
	reference = JSON.parse_string(
		FileAccess.get_file_as_string(root_dir.path_join("pruebas/fase_2/salida/referencia_reajuste.json")))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	base = refit.capture_base(species.skeleton)
	socket_names = species.manifest["bones"]["sockets"]
	for folder: String in ["t", "a"]:
		DirAccess.make_dir_recursive_absolute(out.path_join(folder))
		for body: String in SCALES:
			_check(body, folder == "t", out.path_join(folder).path_join(body + ".glb"))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _set_up(body: String) -> void:
	var weights := {}
	for candidate: Dictionary in reference["bodies"]:
		if candidate["name"] == body:
			weights = candidate["weights"]
	shapes.apply(species.mesh, weights)
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
	var values: Dictionary = proportions.neutral_values(species.sliders)
	values.merge(SCALES[body], true)
	proportions.apply(species.skeleton, proportions.scales(values, species.sliders))


func _global_rests(skeleton: Skeleton3D) -> Dictionary:
	var rests := {}
	for bone in skeleton.get_bone_count():
		rests[skeleton.get_bone_name(bone)] = skeleton.get_bone_global_rest(bone)
	return rests


## {anclaje: transformación global en reposo}; vacío si alguno no cuelga de un BoneAttachment3D.
func _sockets(skeleton: Skeleton3D) -> Dictionary:
	var found := {}
	for socket: String in socket_names:
		var node := skeleton.find_child(socket, true, false) as Node3D
		var holder := node.get_parent() as BoneAttachment3D if node else null
		if holder == null or skeleton.find_bone(holder.bone_name) < 0:
			return {}
		found[socket] = skeleton.get_bone_global_rest(skeleton.find_bone(holder.bone_name)) * node.transform
	return found


func _angle(a: Basis, b: Basis) -> float:
	var q := (a.orthonormalized().inverse() * b.orthonormalized()).get_rotation_quaternion()
	return rad_to_deg(2.0 * acos(minf(1.0, absf(q.w))))


func _check(body: String, t_variant: bool, path: String) -> void:
	var label := "%s, pose %s: " % [body, "T" if t_variant else "A"]
	_set_up(body)
	var memory: Node3D = exporter.build(species.mesh, species.skeleton, socket_names, t_variant)
	var memory_skeleton: Skeleton3D = memory.get_child(0)
	var memory_vertices: PackedVector3Array = \
		(memory_skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var error: Error = exporter.save(species.mesh, species.skeleton, socket_names, path, t_variant)
	check(label + "se exporta sin errores", error == OK and FileAccess.file_exists(path), error_string(error))
	var first := FileAccess.get_sha256(path)
	exporter.save(species.mesh, species.skeleton, socket_names, path, t_variant)
	check(label + "exportar dos veces da el mismo archivo", FileAccess.get_sha256(path) == first,
		"%.1f MB" % (FileAccess.get_file_as_bytes(path).size() / 1e6))

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	error = document.append_from_file(path, state)
	check(label + "se vuelve a leer sin errores", error == OK, error_string(error))
	if error != OK:
		memory.free()
		return
	var scene := document.generate_scene(state)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	check(label + "un esqueleto y una malla", skeletons.size() == 1 and meshes.size() == 1)
	if skeletons.size() == 1 and meshes.size() == 1:
		_compare(label, skeletons[0], meshes[0], memory_skeleton, memory_vertices)
	scene.free()
	memory.free()


func _compare(label: String, skeleton: Skeleton3D, mesh: MeshInstance3D, memory_skeleton: Skeleton3D,
		memory_vertices: PackedVector3Array) -> void:
	# Huesos, por nombre.
	var rests := _global_rests(skeleton)
	var memory_rests := _global_rests(memory_skeleton)
	var mm := 0.0
	var deg := 0.0
	var unit := true
	for bone: String in memory_rests:
		if not rests.has(bone):
			mm = INF
			continue
		mm = maxf(mm, 1000.0 * rests[bone].origin.distance_to(memory_rests[bone].origin))
		deg = maxf(deg, _angle(rests[bone].basis, memory_rests[bone].basis))
	for bone in skeleton.get_bone_count():
		unit = unit and skeleton.get_bone_rest(bone).basis.get_scale().is_equal_approx(Vector3.ONE) \
			and skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE)
	check(label + "53 huesos iguales que en memoria (< %s mm) y con escala 1" % SAME_MM,
		rests.size() == 53 and mm < SAME_MM and unit, "máximo %.5f mm, %.4f°" % [mm, deg])

	# Anclajes.
	var sockets := _sockets(skeleton)
	var memory_sockets := _sockets(memory_skeleton)
	mm = 0.0
	deg = 0.0
	for socket: String in memory_sockets:
		if sockets.has(socket):
			mm = maxf(mm, 1000.0 * sockets[socket].origin.distance_to(memory_sockets[socket].origin))
			deg = maxf(deg, _angle(sockets[socket].basis, memory_sockets[socket].basis))
	check(label + "4 anclajes en su sitio (< %s mm, < %s°)" % [SAME_MM, SOCKET_DEG],
		sockets.size() == 4 and memory_sockets.size() == 4 and mm < SAME_MM and deg < SOCKET_DEG,
		"máximo %.5f mm, %.4f°" % [mm, deg])

	# Malla: cada vértice leído tiene uno igual en memoria (el exportador puede reordenarlos).
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var to_scene := Transform3D.IDENTITY
	var node: Node3D = mesh
	while node.get_parent() != null:
		to_scene = node.transform * to_scene
		node = node.get_parent()
	var grid := {}
	for vertex in memory_vertices:
		var cell := Vector3i((vertex * 1000.0).floor())
		if not grid.has(cell):
			grid[cell] = PackedVector3Array()
		grid[cell].append(vertex)
	mm = 0.0
	for vertex in vertices:
		var point := to_scene * vertex
		var nearest := INF
		var cell := Vector3i((point * 1000.0).floor())
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					for candidate: Vector3 in grid.get(cell + Vector3i(x, y, z), PackedVector3Array()):
						nearest = minf(nearest, point.distance_to(candidate))
		mm = maxf(mm, 1000.0 * nearest)
	check(label + "malla igual que en memoria (< %s mm)" % SAME_MM, mm < SAME_MM,
		"máximo %.5f mm; %d vértices leídos, %d en memoria" % [mm, vertices.size(), memory_vertices.size()])

	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var eight: bool = ((mesh.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
	var wrong := 0
	for i in vertices.size():
		if absf(weights[4 * i] + weights[4 * i + 1] + weights[4 * i + 2] + weights[4 * i + 3] - 1.0) > 1e-4:
			wrong += 1
	check(label + "0 formas, 4 influencias por vértice que suman 1 y color por vértice",
		mesh.mesh.get_blend_shape_count() == 0 and not eight and weights.size() == 4 * vertices.size() and wrong == 0
		and arrays[Mesh.ARRAY_COLOR] != null and mesh.mesh.get_surface_count() == 1, "%d vértices no suman 1" % wrong)
