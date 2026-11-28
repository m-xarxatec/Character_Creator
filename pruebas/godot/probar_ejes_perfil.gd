extends SceneTree
# Paso 5.7b: prototipo «pose T + ejes del perfil humanoide» (CharacterBaker.bake con profile_axes = true). Sin ventana.
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_ejes_perfil.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Escribe pruebas/fase_5/salida/t_perfil.glb (el mismo cuerpo que pruebas/fase_3/salida/t/al_azar.glb) y su .tres:
# después, sh pruebas/fase_5/probar_overwrite_axis.sh lo importa sin Overwrite Axis y lo compara con la T de hoy.
# Que detecta el fallo: en CharacterBaker.profile_global_bases, usar solo el giro local (sin encadenar los padres)
# -> falla «giro de reposo global = el del perfil».

const SCALES := {"height": 0.3, "head_size": 0.8, "hand_size_l": 1.0, "hand_size_r": 0.0, "foot_size_l": 0.2, "foot_size_r": 0.9}
const POSES := {
	"codo a 90°": {"LeftLowerArm": [0, -90, 0], "RightLowerArm": [0, 90, 0]},
	"pierna, tronco y hombro": {"LeftUpperLeg": [-95, 0, 0], "LeftLowerLeg": [110, 0, 0], "Spine": [0, 45, 0], "RightUpperArm": [0, 0, -60]},
}
const SAME_BONE_MM := 0.001
const SAME_AXES_DEG := 0.001
const BIND_MM := 0.01  # el límite del 3.4
const SAME_POSED_MM := 0.001
const SOCKET_MM := 0.1  # el límite del 3.6.4
const FILE_AXES_DEG := 0.01  # PROVISIONAL: el .glb guarda los giros con 32 bits

var failures := 0
var saved := false
var species
var baker: GDScript
var mesh_baker: GDScript
var static_pose: GDScript
var sockets: GDScript
var exporter: GDScript
var bases: Dictionary


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	baker = load(addon.path_join("character_baker.gd"))
	mesh_baker = load(addon.path_join("mesh_baker.gd"))
	static_pose = load(addon.path_join("static_pose.gd"))
	sockets = load(addon.path_join("sockets.gd"))
	exporter = load(addon.path_join("glb_exporter.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	if not _set_up(root_dir, addon):
		print("RESULTADO: 1 FALLO")
		quit(1)
		return
	bases = _profile_bases()
	check("CharacterBaker.profile_global_bases da los 56 huesos del perfil", baker.profile_global_bases().size() == 56)
	var plain: Node3D = baker.bake(species.mesh, species.skeleton, true)
	var proto: Node3D = baker.bake(species.mesh, species.skeleton, true, true)
	root.add_child(plain)
	root.add_child(proto)
	await process_frame
	_check_rest(plain, proto)
	_check_posed(plain, proto)
	var socket_names: Array = species.manifest["bones"]["sockets"]
	var character: Node3D = _check_sockets(plain, proto, socket_names)
	var results: Array = load(addon.path_join("character_checks.gd")).run(character, species.manifest)
	var bad: PackedStringArray = []
	for result: Dictionary in results:
		if result["nivel"] != "bien":
			bad.append("%s: %s" % [result["id"], result["texto"]])
	check("las comprobaciones del 5.3 dan todo bien", bad.is_empty(), ", ".join(bad))
	var folder := root_dir.path_join("pruebas/fase_5/salida")
	DirAccess.remove_absolute(folder.path_join("t_perfil.glb"))  # que un archivo viejo no valga
	_save(character, folder)
	check("el guardado llegó al final y el .glb existe", saved and FileAccess.file_exists(folder.path_join("t_perfil.glb")))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## El cuerpo «al_azar» de probar_exportar.gd.
func _set_up(root_dir: String, addon: String) -> bool:
	var refit: GDScript = load(addon.path_join("skeleton_refit.gd"))
	var proportions: GDScript = load(addon.path_join("proportions.gd"))
	var path := root_dir.path_join("pruebas/fase_2/salida/referencia_reajuste.json")
	if not FileAccess.file_exists(path):
		check("existe la referencia de Blender", false, path)
		return false
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not reference is Dictionary or not reference.get("bodies") is Array:
		check("se pueden leer los cuerpos de la referencia", false, path)
		return false
	var weights := {}
	for candidate: Dictionary in reference["bodies"]:
		if candidate["name"] == "al_azar":
			weights = candidate["weights"]
	check("existe el cuerpo al_azar de la referencia", not weights.is_empty())
	if weights.is_empty():
		return false
	var base: Dictionary = refit.capture_base(species.skeleton)
	load(addon.path_join("shape_weights.gd")).apply(species.mesh, weights)
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
	var values: Dictionary = proportions.neutral_values(species.sliders)
	values.merge(SCALES, true)
	proportions.apply(species.skeleton, proportions.scales(values, species.sliders))
	return true


## Giro global de cada hueso del perfil, calculado aquí (no con la función que se prueba): padre antes que hijo.
func _profile_bases() -> Dictionary:
	var profile := SkeletonProfileHumanoid.new()
	var found := {}
	while found.size() < profile.bone_size:
		for i in profile.bone_size:
			var parent := String(profile.get_bone_parent(i))
			if not found.has(String(profile.get_bone_name(i))) and (parent == "" or found.has(parent)):
				found[String(profile.get_bone_name(i))] = found.get(parent, Basis.IDENTITY) * profile.get_reference_pose(i).basis
	return found


func _parts(character: Node3D) -> Array:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	return [skeleton, skeleton.find_children("*", "MeshInstance3D", true, false)[0]]


func _far(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var far := 0.0 if a.size() == b.size() else INF
	for i in mini(a.size(), b.size()):
		far = maxf(far, 1000.0 * a[i].distance_to(b[i]))
	return far


func _check_rest(plain: Node3D, proto: Node3D) -> void:
	var a := _parts(plain)
	var b := _parts(proto)
	var arrays_a: Array = a[1].mesh.surface_get_arrays(0)
	var arrays_b: Array = b[1].mesh.surface_get_arrays(0)
	check("la malla es idéntica (vértices, normales, huesos y pesos; exacto)",
		arrays_a[Mesh.ARRAY_VERTEX] == arrays_b[Mesh.ARRAY_VERTEX] and arrays_a[Mesh.ARRAY_NORMAL] == arrays_b[Mesh.ARRAY_NORMAL]
		and arrays_a[Mesh.ARRAY_BONES] == arrays_b[Mesh.ARRAY_BONES] and arrays_a[Mesh.ARRAY_WEIGHTS] == arrays_b[Mesh.ARRAY_WEIGHTS]
		and arrays_a[Mesh.ARRAY_INDEX] == arrays_b[Mesh.ARRAY_INDEX], "%d vértices" % arrays_a[Mesh.ARRAY_VERTEX].size())
	var moved := 0.0
	var turned := 0.0
	var same := 0
	var in_profile := 0
	for bone in a[0].get_bone_count():
		var name: String = a[0].get_bone_name(bone)
		var rest: Transform3D = b[0].get_bone_global_rest(bone)
		moved = maxf(moved, 1000.0 * rest.origin.distance_to(a[0].get_bone_global_rest(bone).origin))
		if bases.has(name):
			in_profile += 1
			turned = maxf(turned, _angle(rest.basis, bases[name]))
			if _angle(rest.basis, a[0].get_bone_global_rest(bone).basis) < SAME_AXES_DEG:
				same += 1
	check("los huesos no se mueven (< %s mm)" % SAME_BONE_MM, moved < SAME_BONE_MM, "%.6f mm, %d huesos" % [moved, a[0].get_bone_count()])
	check("giro de reposo global = el del perfil (< %s°)" % SAME_AXES_DEG, turned < SAME_AXES_DEG and in_profile == 56,  # paso 9.3
		"%.6f°, %d huesos del perfil" % [turned, in_profile])
	check("la prueba distingue: sin el prototipo casi ningún hueso tiene los ejes del perfil", same < 10, "%d de %d" % [same, in_profile])
	var bind := 0.0
	var skin: Skin = b[1].skin
	for i in skin.get_bind_count():
		var both: Transform3D = b[0].get_bone_global_rest(skin.get_bind_bone(i)) * skin.get_bind_pose(i)
		for point: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			bind = maxf(bind, 1000.0 * (both * point).distance_to(point))
	check("reposo × bind pose = identidad (< %s mm a 1 m)" % BIND_MM, bind < BIND_MM, "%.6f mm" % bind)


func _check_posed(plain: Node3D, proto: Node3D) -> void:
	for pose: String in POSES:
		var posed := []
		for character: Node3D in [plain, proto]:
			var parts := _parts(character)
			static_pose.apply(parts[0], POSES[pose], "Hips", [])
			posed.append(mesh_baker.bake(parts[1], parts[0])["vertices"])
		var rest: PackedVector3Array = _parts(plain)[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var far := _far(posed[0], posed[1])
		check("%s: la malla deformada es la misma (< %s mm)" % [pose, SAME_POSED_MM], far < SAME_POSED_MM,
			"%.6f mm; la pose mueve la malla %.0f mm" % [far, _far(posed[0], rest)])
		check("%s: la pose mueve la malla (la prueba distingue)" % pose, _far(posed[0], rest) > 100.0)
	for character: Node3D in [plain, proto]:
		static_pose.apply(_parts(character)[0], {}, "Hips", [])


## Devuelve el prototipo con los anclajes como nodos (el personaje que se exportaría).
func _check_sockets(plain: Node3D, proto: Node3D, socket_names: Array) -> Node3D:
	var a: Node3D = sockets.to_nodes(plain, socket_names)
	var b: Node3D = sockets.to_nodes(proto, socket_names)
	var moved := 0.0
	var turned := 0.0
	for socket: String in socket_names:
		var places := []
		for character: Node3D in [a, b]:
			var node := character.find_child(socket, true, false) as Node3D
			var holder := node.get_parent() as BoneAttachment3D
			var skeleton := holder.get_parent() as Skeleton3D
			places.append(skeleton.get_bone_global_rest(skeleton.find_bone(holder.bone_name)) * node.transform)
		moved = maxf(moved, 1000.0 * places[0].origin.distance_to(places[1].origin))
		turned = maxf(turned, _angle(places[0].basis, places[1].basis))
	check("anclajes en el mismo sitio y con el mismo giro (< %s mm, < %s°)" % [SOCKET_MM, SAME_AXES_DEG],
		moved < SOCKET_MM and turned < SAME_AXES_DEG and socket_names.size() == 4, "%.6f mm, %.6f°" % [moved, turned])
	a.free()
	return b


## Escribe el .glb con el exportador real (prepare, compute, finish, write); un error o un archivo sin escribir es FALLO.
func _save(character: Node3D, folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("t_perfil.glb")
	character.free()  # el que se comprobó; se exporta uno igual, hecho como lo hace el exportador real
	var job: Dictionary = exporter.prepare(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)
	exporter.compute(job)
	var error: Error = exporter.write(exporter.finish(job), job["toon"], path)
	check("se escribe " + path, error == OK, error_string(error))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		check("el archivo se vuelve a leer", false)
		return
	var scene := document.generate_scene(state)
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var turned := 0.0
	for bone in skeleton.get_bone_count():
		turned = maxf(turned, _angle(skeleton.get_bone_global_rest(bone).basis, bases[skeleton.get_bone_name(bone)]))
	check("en el archivo, los 56 huesos conservan los ejes del perfil (< %s°)" % FILE_AXES_DEG,
		turned < FILE_AXES_DEG and skeleton.get_bone_count() == 56, "%.6f°" % turned)
	scene.free()
	saved = true


func _angle(a: Basis, b: Basis) -> float:
	return rad_to_deg((a * b.inverse()).get_rotation_quaternion().get_angle())
