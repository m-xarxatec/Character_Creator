extends SceneTree
# Paso 3.6.4: anclajes como nodos vacíos y solo huesos de deformación (sockets.gd).
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_anclajes.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Cuerpos extremo y al azar (asimétrico), con escalas de Proporción, en pose A y en pose T.

const SOCKET_MM := 0.1
const SOCKET_DEG := 1.0
const MESH_MM := 0.01
const OPTIONAL := ["LeftEye", "RightEye", "Jaw"]  # el rig Game engine no los trae
const SCALES := {
	"extremo": {"height": 1.0, "head_size": 1.0, "hand_size_l": 1.0, "hand_size_r": 1.0, "foot_size_l": 1.0, "foot_size_r": 1.0},
	"al_azar": {"height": 0.3, "head_size": 0.8, "hand_size_l": 1.0, "hand_size_r": 0.0, "foot_size_l": 0.2, "foot_size_r": 0.9},
}

var failures := 0
var species
var base: Dictionary
var sockets: GDScript
var character_baker: GDScript
var baker: GDScript
var refit: GDScript
var shapes: GDScript
var proportions: GDScript
var reference: Dictionary
var socket_names: Array


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	sockets = load(addon.path_join("sockets.gd"))
	character_baker = load(addon.path_join("character_baker.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
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
	for body: String in SCALES:
		for variant: bool in [false, true]:
			_check(body, variant)
	_check_refuses()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _bake(body: String, t_variant: bool) -> Node3D:
	var weights := {}
	for candidate: Dictionary in reference["bodies"]:
		if candidate["name"] == body:
			weights = candidate["weights"]
	shapes.apply(species.mesh, weights)
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
	var values: Dictionary = proportions.neutral_values(species.sliders)
	values.merge(SCALES[body], true)
	proportions.apply(species.skeleton, proportions.scales(values, species.sliders))
	return character_baker.bake(species.mesh, species.skeleton, t_variant)


## Gira el antebrazo izquierdo 90° sobre su cabeza (misma posición en el mundo).
func _bend(skeleton: Skeleton3D) -> void:
	var bone := skeleton.find_bone("LeftLowerArm")
	var globals: Array[Transform3D] = baker.global_poses(skeleton)
	var pivot := globals[bone].origin
	var turn := Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var local := globals[skeleton.get_bone_parent(bone)].affine_inverse() * (turn * globals[bone])
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())


## Por vértice, {hueso: peso} con el nombre del hueso (pesos > 0).
func _named_weights(skeleton: Skeleton3D, mesh: MeshInstance3D) -> Array[Dictionary]:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var result: Array[Dictionary] = []
	for i in bones.size() / 4:
		var named := {}
		for k in range(4 * i, 4 * i + 4):
			if weights[k] > 0.0:
				named[skeleton.get_bone_name(mesh.skin.get_bind_bone(bones[k]))] = weights[k]
		result.append(named)
	return result


## Dónde está cada anclaje (global) en el personaje nuevo, con la pose actual.
func _socket_globals(skeleton: Skeleton3D) -> Dictionary:
	var globals: Array[Transform3D] = baker.global_poses(skeleton)
	var found := {}
	for socket: String in socket_names:
		var node := skeleton.find_child(socket, true, false) as Node3D
		var holder := node.get_parent() as BoneAttachment3D if node else null
		if holder:
			found[socket] = globals[skeleton.find_bone(holder.bone_name)] * node.transform
	return found


## Mayor distancia (mm) y mayor giro (°) entre los anclajes nuevos y los huesos de anclaje originales.
func _socket_error(new_skeleton: Skeleton3D, old_globals: Array[Transform3D], old_skeleton: Skeleton3D) -> Vector2:
	var found := _socket_globals(new_skeleton)
	var worst := Vector2.ZERO
	for socket: String in socket_names:
		if not found.has(socket):
			return Vector2(INF, INF)
		var old := old_globals[old_skeleton.find_bone(socket)]
		var now: Transform3D = found[socket]
		var q := (old.basis.inverse() * now.basis).orthonormalized().get_rotation_quaternion()
		worst.x = maxf(worst.x, 1000.0 * old.origin.distance_to(now.origin))
		worst.y = maxf(worst.y, rad_to_deg(2.0 * acos(minf(1.0, absf(q.w)))))
	return worst


func _check(body: String, t_variant: bool) -> void:
	var label := "%s, pose %s: " % [body, "T" if t_variant else "A"]
	var old: Node3D = _bake(body, t_variant)
	var old_skeleton: Skeleton3D = old.get_child(0)
	var old_mesh: MeshInstance3D = old_skeleton.get_child(0)
	check(label + "se puede convertir", sockets.error(old, socket_names) == "", sockets.error(old, socket_names))
	var character: Node3D = sockets.to_nodes(old, socket_names)
	var skeleton: Skeleton3D = character.get_child(0)
	var mesh := skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D

	_check_profile(label, skeleton)
	var rest_error := _socket_error(skeleton, baker.global_poses(old_skeleton), old_skeleton)
	var scaled := false
	var hung := true
	for socket: String in socket_names:
		var node := skeleton.find_child(socket, true, false) as Node3D
		var holder := node.get_parent() as BoneAttachment3D if node else null
		var parent := old_skeleton.get_bone_name(old_skeleton.get_bone_parent(old_skeleton.find_bone(socket)))
		hung = hung and holder != null and holder.bone_name == parent and node.get_child_count() == 0
		scaled = scaled or node == null or not node.transform.basis.get_scale().is_equal_approx(Vector3.ONE)
	check(label + "4 anclajes como nodos vacíos, hijos de su hueso y con escala 1", hung and not scaled)
	check(label + "anclajes donde estaba su hueso (< %s mm, < %s°)" % [SOCKET_MM, SOCKET_DEG],
		rest_error.x < SOCKET_MM and rest_error.y < SOCKET_DEG, "máximo %.5f mm, %.4f°" % [rest_error.x, rest_error.y])

	var old_named := _named_weights(old_skeleton, old_mesh)
	var new_named := _named_weights(skeleton, mesh)
	var changed := 0
	var old_bones: PackedInt32Array = old_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
	var new_bones: PackedInt32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
	for i in old_bones.size():
		if old_bones[i] != new_bones[i]:
			changed += 1
	check(label + "cada peso sigue en el hueso del mismo nombre", old_named == new_named,
		"%d vértices; %d índices de hueso cambiaron" % [new_named.size(), changed])

	_bend(old_skeleton)
	_bend(skeleton)
	var before: PackedVector3Array = baker.bake(old_mesh, old_skeleton)["vertices"]
	var after: PackedVector3Array = baker.bake(mesh, skeleton)["vertices"]
	var mm := 0.0
	for i in before.size():
		mm = maxf(mm, 1000.0 * before[i].distance_to(after[i]))
	check(label + "codo a 90°: malla igual antes y después de quitar los anclajes (< %s mm)" % MESH_MM,
		before.size() == after.size() and mm < MESH_MM, "máximo %.5f mm" % mm)
	var bent_error := _socket_error(skeleton, baker.global_poses(old_skeleton), old_skeleton)
	check(label + "codo a 90°: los anclajes siguen a su hueso (< %s mm, < %s°)" % [SOCKET_MM, SOCKET_DEG],
		bent_error.x < SOCKET_MM and bent_error.y < SOCKET_DEG, "máximo %.5f mm, %.4f°" % [bent_error.x, bent_error.y])
	old.free()
	character.free()


func _check_profile(label: String, skeleton: Skeleton3D) -> void:
	var profile := SkeletonProfileHumanoid.new()
	var wrong: PackedStringArray = []
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		var index := profile.find_bone(bone)
		var parent: StringName = skeleton.get_bone_name(skeleton.get_bone_parent(i)) if skeleton.get_bone_parent(i) >= 0 else &""
		if index < 0 or profile.get_bone_parent(index) != parent:
			wrong.append(bone)
	var missing: PackedStringArray = []
	for i in profile.bone_size:
		if skeleton.find_bone(profile.get_bone_name(i)) < 0 and not profile.get_bone_name(i) in OPTIONAL:
			missing.append(profile.get_bone_name(i))
	check(label + "53 huesos con nombre y padre del perfil humanoide, sin anclajes",
		skeleton.get_bone_count() == 53 and wrong.is_empty() and missing.is_empty(),
		"%d huesos; mal: %s; faltan: %s" % [skeleton.get_bone_count(), wrong, missing])


## Si un vértice tiene peso en un anclaje, no se convierte.
func _check_refuses() -> void:
	var old: Node3D = _bake("extremo", false)
	var skeleton: Skeleton3D = old.get_child(0)
	var mesh: MeshInstance3D = skeleton.get_child(0)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	for bind in mesh.skin.get_bind_count():
		if skeleton.get_bone_name(mesh.skin.get_bind_bone(bind)) == socket_names[0]:
			bones[0] = bind
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_TANGENT] = null
	var broken := ArrayMesh.new()
	broken.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = broken
	var message: String = sockets.error(old, socket_names)
	check("un vértice con peso en un anclaje: se rechaza con un error claro",
		message.contains("peso en un anclaje") and sockets.to_nodes(old, socket_names) == null, message)
	old.free()
