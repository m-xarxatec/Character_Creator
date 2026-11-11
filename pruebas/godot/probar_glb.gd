extends SceneTree
# Paso 1.6: abre cada .glb con el lector glTF de Godot y comprueba que sirve para un juego.
# Uso: godot --headless --path pruebas/godot -s probar_glb.gd -- <carpeta con .glb> [--pose-a] 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Con --pose-a comprueba brazos en pose A en vez de pose T.
# El autorrelleno del BoneMap solo existe en la ventana del editor; aqui se comprueba lo que necesita
# para salir todo en verde: cada hueso con el nombre y el padre del SkeletonProfileHumanoid.

const SOCKETS := {"socket_hand_r": "RightHand", "socket_hand_l": "LeftHand", "socket_back": "UpperChest", "socket_hip": "Hips"}
const OPTIONAL := ["LeftEye", "RightEye", "Jaw"]  # el rig Game engine no los trae

var failures := 0
var pose_a := "--pose-a" in OS.get_cmdline_user_args()  # variante en pose A del paso 3.6.5


func _init() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var files := Array(DirAccess.get_files_at(folder)).filter(func(f: String) -> bool: return f.ends_with(".glb"))
	check("hay .glb que probar", files.size() > 0, folder)
	for file: String in files:
		print(file)
		_check_file(folder.path_join(file))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_file(path: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error := doc.append_from_file(path, state)
	check("se abre sin errores", error == OK, error_string(error))
	if error != OK:
		return
	var scene := doc.generate_scene(state)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	check("un solo esqueleto", skeletons.size() == 1)
	if skeletons.size() == 1:
		_check_profile(skeletons[0])
		_check_t_pose(skeletons[0])
		_check_sockets(skeletons[0])
	_check_mesh(scene)
	scene.free()


func _check_profile(skel: Skeleton3D) -> void:
	var profile := SkeletonProfileHumanoid.new()
	var missing: PackedStringArray = []
	var wrong_parent: PackedStringArray = []
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		var index := skel.find_bone(bone)
		if index < 0:
			if not bone in OPTIONAL:
				missing.append(bone)
			continue
		var parent := profile.get_bone_parent(i)
		var actual: StringName = skel.get_bone_name(skel.get_bone_parent(index)) if skel.get_bone_parent(index) >= 0 else &""
		if actual != parent:
			wrong_parent.append("%s (padre %s, se esperaba %s)" % [bone, actual, parent])
	var extra: PackedStringArray = []
	for i in skel.get_bone_count():
		if profile.find_bone(skel.get_bone_name(i)) < 0:
			extra.append(skel.get_bone_name(i))
	check("estan los 53 huesos del perfil (menos ojos y mandibula)", missing.is_empty() and skel.get_bone_count() == 53, ", ".join(missing))
	check("no hay huesos que el perfil no conozca", extra.is_empty(), ", ".join(extra))
	check("cada hueso tiene el padre que pide el perfil", wrong_parent.is_empty(), ", ".join(wrong_parent))


func _check_t_pose(skel: Skeleton3D) -> void:
	var at := func(bone: String) -> Vector3: return skel.get_bone_global_rest(skel.find_bone(bone)).origin
	for side in [["Left", 1.0], ["Right", -1.0]]:
		var shoulder: Vector3 = at.call(side[0] + "UpperArm")
		var hand: Vector3 = at.call(side[0] + "Hand")
		var ok: bool = side[1] * hand.x > 0.4 and absf(hand.y - shoulder.y) < 0.01 and absf(hand.z - shoulder.z) < 0.01
		if pose_a:  # brazos hacia abajo y hacia fuera
			ok = side[1] * (hand.x - shoulder.x) > 0.1 and hand.y < shoulder.y - 0.2
		check("brazo %s en pose %s hacia %sX" % [side[0], "A" if pose_a else "T", "+" if side[1] > 0 else "-"], ok, str(hand))
	check("mira a +Z (la punta del pie va delante del tobillo)", at.call("LeftToes").z > at.call("LeftFoot").z + 0.05)
	check("Y hacia arriba", at.call("Head").y > at.call("Hips").y + 0.4)


func _check_sockets(skel: Skeleton3D) -> void:
	for socket: String in SOCKETS:
		var node := skel.find_child(socket, true, false)
		var holder := node.get_parent() as BoneAttachment3D if node else null
		check("%s cuelga de %s" % [socket, SOCKETS[socket]], holder != null and holder.bone_name == SOCKETS[socket])


func _check_mesh(scene: Node) -> void:
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	check("una sola malla con piel (skin)", meshes.size() == 1 and meshes[0].skin != null)
	if meshes.size() != 1:
		return
	var mesh: Mesh = meshes[0].mesh
	check("una sola superficie y sin formas sueltas", mesh.get_surface_count() == 1 and mesh.get_blend_shape_count() == 0)
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := weights.size() / points.size()
	var worst := 0.0
	for v in points.size():
		var total := 0.0
		for i in per:
			total += weights[v * per + i]
		worst = maxf(worst, absf(total - 1.0))
	check("4 influencias por vertice que suman 1", per == 4 and worst < 0.001, "desvio %.5f" % worst)
	check("lleva el color de la prenda", arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == points.size())
	var box := mesh.get_aabb()
	check("metros y pies en el suelo", box.size.y > 1.2 and box.size.y < 2.4 and absf(box.position.y) < 0.001, "alto %.3f" % box.size.y)
