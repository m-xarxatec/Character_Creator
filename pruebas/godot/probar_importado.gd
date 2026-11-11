extends SceneTree
# Paso 3.6.5: comprueba t.glb y a.glb ya importados por el importador del editor en un proyecto vacío.
# No se lanza a mano: lo ejecuta pruebas/fase_3/probar_importador.sh, que crea el proyecto e importa.

const SOCKETS := {"socket_hand_r": "RightHand", "socket_hand_l": "LeftHand", "socket_back": "UpperChest", "socket_hip": "Hips"}
const OPTIONAL := ["LeftEye", "RightEye", "Jaw"]  # el rig Game engine no los trae

var failures := 0


func _initialize() -> void:
	for file: String in ["t", "a"]:
		_check_scene(file)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_scene(file: String) -> void:
	var label := file + ".glb importado: "
	var packed := load("res://%s.glb" % file) as PackedScene
	check(label + "es una escena", packed != null)
	if packed == null:
		return
	var scene := packed.instantiate()
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	check(label + "un esqueleto y una malla", skeletons.size() == 1 and meshes.size() == 1)
	if skeletons.size() != 1 or meshes.size() != 1:
		scene.free()
		return
	var skeleton: Skeleton3D = skeletons[0]
	var mesh: MeshInstance3D = meshes[0]
	var profile := SkeletonProfileHumanoid.new()
	var wrong: PackedStringArray = []
	var unit := true
	for bone in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(bone)
		var index := profile.find_bone(name)
		var parent: StringName = skeleton.get_bone_name(skeleton.get_bone_parent(bone)) if skeleton.get_bone_parent(bone) >= 0 else &""
		if index < 0 or profile.get_bone_parent(index) != parent:
			wrong.append(name)
		unit = unit and skeleton.get_bone_rest(bone).basis.get_scale().is_equal_approx(Vector3.ONE) \
			and skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE)
	check(label + "53 huesos del perfil humanoide, con escala 1", skeleton.get_bone_count() == 53 and wrong.is_empty() and unit,
		"%d huesos; mal: %s" % [skeleton.get_bone_count(), wrong])
	var hung := true
	for socket: String in SOCKETS:
		var node := skeleton.find_child(socket, true, false) as Node3D
		var holder := node.get_parent() as BoneAttachment3D if node else null
		hung = hung and holder != null and holder.bone_name == SOCKETS[socket] \
			and node.transform.basis.get_scale().is_equal_approx(Vector3.ONE)
	check(label + "4 anclajes hijos de su hueso, con escala 1", hung)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var eight: bool = ((mesh.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
	check(label + "una superficie, 0 formas, 4 influencias por vértice y color por vértice",
		mesh.mesh.get_surface_count() == 1 and mesh.mesh.get_blend_shape_count() == 0 and not eight
		and weights.size() == 4 * count and arrays[Mesh.ARRAY_COLOR] != null and mesh.skin != null, "%d vértices" % count)
	var upper := skeleton.get_bone_global_rest(skeleton.find_bone("LeftUpperArm")).origin
	var hand := skeleton.get_bone_global_rest(skeleton.find_bone("LeftHand")).origin
	var horizontal := absf(hand.y - upper.y) < 0.01
	check(label + ("brazos en pose T" if file == "t" else "brazos en pose A"), horizontal if file == "t" else hand.y < upper.y - 0.2)
	scene.free()
