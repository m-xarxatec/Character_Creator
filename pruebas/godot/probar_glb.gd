extends SceneTree
# Paso 1.6: abre cada .glb con el lector glTF de Godot y comprueba que sirve para un juego.
# Uso: godot --headless --path pruebas/godot -s probar_glb.gd -- <carpeta con .glb> [--pose-a] 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Con --pose-a comprueba brazos en pose A en vez de pose T.
# Paso AB.16: con --piezas=N --rigidas=M (los dos juntos) espera el cuerpo y N mallas de piezas, M de ellas rígidas
# (accesorios: una sola articulación). Cuenta mallas, no piezas: unos cuernos son 2. Sin ellos, una sola malla con piel.
# El .glb con piezas lo genera generar_glb_piezas.gd.
# El autorrelleno del BoneMap solo existe en la ventana del editor; aqui se comprueba lo que necesita
# para salir todo en verde: cada hueso con el nombre y el padre del SkeletonProfileHumanoid.

const SOCKETS := {"socket_hand_r": "RightHand", "socket_hand_l": "LeftHand", "socket_back": "UpperChest", "socket_hip": "Hips"}
const OPTIONAL := ["LeftEye", "RightEye", "Jaw"]  # el rig Game engine no los trae
const BIND_MAX_ERROR := 0.001  # aprobado por el responsable el 2026-11-21 (medido 0,000000): diferencia entre la bind pose y la inversa del reposo del hueso
const WEIGHT_MAX_ERROR := 0.001  # aprobado por el responsable el 2026-11-21 (medido 0,00000): desvío de 1 en la suma de pesos de una malla

var failures := 0
var pose_a := "--pose-a" in OS.get_cmdline_user_args()  # variante en pose A del paso 3.6.5
var piece_count := _int_arg("--piezas=")  # -1 = sin modo piezas
var rigid_count := _int_arg("--rigidas=")


func _init() -> void:
	if not _piece_args_ok():
		check("--piezas=N (N >= 1) y --rigidas=M (0 <= M <= N) van juntos", false)
		print("RESULTADO: %d FALLOS" % failures)
		quit(1)
		return
	var folder: String = OS.get_cmdline_user_args()[0]
	var files := Array(DirAccess.get_files_at(folder)).filter(func(f: String) -> bool: return f.ends_with(".glb"))
	check("hay .glb que probar", files.size() > 0, folder)
	for file: String in files:
		print(file)
		_check_file(folder.path_join(file))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


## El número de un argumento «prefijo=N»: -1 si no está, -2 si no es un número.
func _int_arg(prefix: String) -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			var value := arg.trim_prefix(prefix)
			return value.to_int() if value.is_valid_int() and value.to_int() >= 0 else -2
	return -1


func _piece_args_ok() -> bool:
	return (piece_count == -1 and rigid_count == -1) or (piece_count >= 1 and rigid_count >= 0 and rigid_count <= piece_count)


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
	if piece_count >= 0:
		_check_with_pieces(scene, skeletons[0] if skeletons.size() == 1 else null)
	else:
		_check_mesh(scene)
	_check_file_weights(path)
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
	_check_body(meshes[0])


func _check_body(instance: MeshInstance3D) -> void:
	var mesh: Mesh = instance.mesh
	check("una sola superficie y sin formas sueltas", mesh.get_surface_count() == 1 and mesh.get_blend_shape_count() == 0)
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := weights.size() / points.size()
	var worst := _weight_error(weights, per)
	check("4 influencias por vertice que suman 1", per == 4 and worst < 0.001, "desvio %.5f" % worst)
	check("lleva el color de la prenda", arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == points.size())
	var box := mesh.get_aabb()
	check("metros y pies en el suelo", box.size.y > 1.2 and box.size.y < 2.4 and absf(box.position.y) < 0.001, "alto %.3f" % box.size.y)


## El mayor desvío de 1 en la suma de pesos de un vértice.
func _weight_error(weights: PackedFloat32Array, per: int) -> float:
	var worst := 0.0
	for v in weights.size() / per:
		var total := 0.0
		for i in per:
			total += weights[v * per + i]
		worst = maxf(worst, absf(total - 1.0))
	return worst


## Paso AB.16: el cuerpo con sus comprobaciones de siempre y cada pieza por separado.
func _check_with_pieces(scene: Node, skel: Skeleton3D) -> void:
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var bodies := meshes.filter(func(m: MeshInstance3D) -> bool: return m.name == "Body")
	check("un cuerpo con piel", bodies.size() == 1 and bodies[0].skin != null)
	if bodies.size() == 1:
		_check_body(bodies[0])
	var pieces := meshes.filter(func(m: MeshInstance3D) -> bool: return m.name != "Body")
	check("%d mallas de piezas" % piece_count, pieces.size() == piece_count, str(pieces.size()))
	if skel == null:
		return
	var rigid := 0
	for piece: MeshInstance3D in pieces:
		_check_piece(piece, skel)
		if piece.skin != null and piece.skin.get_bind_count() == 1:
			rigid += 1
	check("%d mallas rígidas (una articulación)" % rigid_count, rigid == rigid_count, str(rigid))


func _check_piece(piece: MeshInstance3D, skel: Skeleton3D) -> void:
	check("%s: tiene piel" % piece.name, piece.skin != null)
	if piece.skin == null:
		return
	check("%s: usa el esqueleto de 53 huesos" % piece.name, piece.get_node_or_null(piece.skeleton) == skel and skel.get_bone_count() == 53)
	_check_binds(piece, skel)
	var mesh: Mesh = piece.mesh
	check("%s: una sola superficie y sin formas sueltas" % piece.name, mesh.get_surface_count() == 1 and mesh.get_blend_shape_count() == 0)
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var per := weights.size() / points.size() if points.size() > 0 else 0
	if per != 4 or bones.size() != weights.size():
		check("%s: 4 influencias por vertice" % piece.name, false, "%d pesos, %d huesos, %d vertices" % [weights.size(), bones.size(), points.size()])
		return
	var worst := _weight_error(weights, per)
	check("%s: 4 influencias por vertice que suman 1" % piece.name, worst < WEIGHT_MAX_ERROR, "desvio %.5f" % worst)
	var top := 0
	for i in bones.size():
		if weights[i] > 0.0:
			top = maxi(top, bones[i])
	check("%s: sus indices caben en la piel" % piece.name, top < piece.skin.get_bind_count(), "%d de %d" % [top, piece.skin.get_bind_count()])


## Cada articulación es un hueso del esqueleto y su bind pose es la inversa de su reposo (si no, la pieza se separa al animar).
func _check_binds(piece: MeshInstance3D, skel: Skeleton3D) -> void:
	var skin: Skin = piece.skin
	var unknown := 0
	var worst := 0.0
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(i))
		if bone < 0 or bone >= skel.get_bone_count():
			unknown += 1
			continue
		var expected := skel.get_bone_global_rest(bone).affine_inverse()
		var bind := skin.get_bind_pose(i)
		for pair in [[bind.basis.x, expected.basis.x], [bind.basis.y, expected.basis.y], [bind.basis.z, expected.basis.z], [bind.origin, expected.origin]]:
			worst = maxf(worst, (pair[0] - pair[1]).length())
	check("%s: sus articulaciones son huesos del esqueleto" % piece.name, skin.get_bind_count() > 0 and unknown == 0, "%d binds, %d desconocidos" % [skin.get_bind_count(), unknown])
	check("%s: bind pose = inversa del reposo" % piece.name, worst < BIND_MAX_ERROR, "error %.6f" % worst)


## Los pesos tal como están en el archivo: al importar, Godot los normaliza y una suma mala no se vería en la escena.
func _check_file_weights(path: String) -> void:
	var data := FileAccess.get_file_as_bytes(path)
	var json_size := data.decode_u32(12)
	var json: Dictionary = JSON.parse_string(data.slice(20, 20 + json_size).get_string_from_utf8())
	var binary := 20 + json_size + 8  # tras la cabecera del bloque binario
	for node: Dictionary in json["nodes"]:
		if not node.has("mesh"):
			continue
		var worst := 0.0
		var only_four := true
		for primitive: Dictionary in json["meshes"][int(node["mesh"])]["primitives"]:
			only_four = only_four and not primitive["attributes"].has("WEIGHTS_1")
			worst = maxf(worst, _accessor_weight_error(data, json, int(primitive["attributes"]["WEIGHTS_0"]), binary))
		check("%s: en el archivo, máximo 4 influencias que suman 1" % node["name"], only_four and worst < WEIGHT_MAX_ERROR, "desvio %.5f" % worst)


func _accessor_weight_error(data: PackedByteArray, json: Dictionary, index: int, binary: int) -> float:
	var accessor: Dictionary = json["accessors"][index]
	var view: Dictionary = json["bufferViews"][int(accessor["bufferView"])]
	var kind := int(accessor["componentType"])  # 5126 float, 5123 u16 normalizado, 5121 u8 normalizado
	var size := 4 if kind == 5126 else (2 if kind == 5123 else 1)
	var stride := int(view.get("byteStride", size * 4))
	var start := binary + int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
	var worst := 0.0
	for v in int(accessor["count"]):
		var total := 0.0
		for i in 4:
			var at := start + v * stride + i * size
			total += data.decode_float(at) if kind == 5126 else (data.decode_u16(at) / 65535.0 if kind == 5123 else data[at] / 255.0)
		worst = maxf(worst, absf(total - 1.0))
	return worst
