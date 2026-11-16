extends SceneTree
# Ficha A3: la pose como giros en el mundo (world_pose.gd). Sin ventana y sin datos/.
# Uso: godot --headless --path pruebas/godot -s <ruta a este archivo> 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
# Busca world_pose.gd en godot/addons/creador/ y, si no está, en ruta/codigo/nucleo/ (borrador).
# Cada caso se prueba con dos esqueletos: A (ejes del mundo) y B (ejes locales girados al azar).
# Que detecta el fallo: en WorldPose.apply, cambiar `delta * rest[i]` por `rest[i] * delta` -> fallan los casos de B.

const MAX_DEG := 0.001  # PROVISIONAL (D26)
const MAX_MM := 0.01  # PROVISIONAL (D26)
const SEED_B := 7
const POSE := {  # 6 huesos, giros cualesquiera
	"Spine": [Vector3(1, 0, 0), 20.0],
	"LeftUpperArm": [Vector3(0, 0, 1), -70.0],
	"LeftLowerArm": [Vector3(0, 1, 0), 95.0],
	"RightUpperArm": [Vector3(1, 1, 0), 40.0],
	"LeftUpperLeg": [Vector3(1, 0, 0), -80.0],
	"LeftLowerLeg": [Vector3(1, 0, 0), 30.0],
}

var failures := 0
var pose: GDScript
var maker: GDScript


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	pose = _load_core(root_dir, "world_pose.gd")
	maker = load((get_script() as Script).resource_path.get_base_dir().path_join("esqueleto_de_prueba.gd"))
	if pose == null or maker == null:
		print("ERROR: no se encuentra world_pose.gd o esqueleto_de_prueba.gd")
		quit(1)
		return
	for seed_value: int in [0, SEED_B]:
		var label := "A" if seed_value == 0 else "B"
		_check_rest(label, seed_value)
		_check_one_bone(label, seed_value)
		_check_scale(label, seed_value)
	_check_same_pose()
	_check_copy()
	_check_hips()
	_check_mirror()
	_check_data()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _load_core(root_dir: String, file: String) -> GDScript:
	for folder: String in ["godot/addons/creador", "ruta/codigo/nucleo"]:
		var path := root_dir.path_join(folder).path_join(file)
		if FileAccess.file_exists(path):
			return load(path)
	return null


func _deltas() -> Dictionary:
	var deltas := {}
	for bone: String in POSE:
		deltas[bone] = Quaternion((POSE[bone][0] as Vector3).normalized(), deg_to_rad(POSE[bone][1]))
	return deltas


func _degrees(a: Quaternion, b: Quaternion) -> float:
	return rad_to_deg(pose.angle_between(Basis(a), Basis(b)))


## Caso 1: sin deltas, cada hueso queda con el giro de su reposo.
func _check_rest(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	skeleton.set_bone_pose_rotation(3, Quaternion(Vector3.UP, 1.0))  # una pose cualquiera, que apply debe borrar
	pose.apply(skeleton, {})
	var worst := 0.0
	for i in skeleton.get_bone_count():
		worst = maxf(worst, _degrees(skeleton.get_bone_pose_rotation(i), skeleton.get_bone_rest(i).basis.get_rotation_quaternion()))
	check("%s: sin deltas, la pose es el reposo (< %s°)" % [label, MAX_DEG], worst < MAX_DEG, "máximo %.6f°" % worst)
	check("%s: sin deltas, capture devuelve un diccionario vacío" % label, pose.capture(skeleton).is_empty())
	skeleton.free()


## Casos 2 a 5: un solo hueso girado 90° sobre Z; los descendientes le siguen; capture lo lee; repetir da lo mismo.
func _check_one_bone(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var deltas := {"LeftUpperArm": Quaternion(Vector3(0, 0, 1), PI / 2.0)}
	pose.apply(skeleton, deltas)
	var points: Array[Vector3] = maker.joints(skeleton)
	var worst := 0.0
	for pair: Array in [["LeftUpperArm", "LeftLowerArm"], ["LeftLowerArm", "LeftHand"], ["LeftHand", "LeftMiddleProximal"]]:
		var direction := points[skeleton.find_bone(pair[1])] - points[skeleton.find_bone(pair[0])]
		worst = maxf(worst, rad_to_deg(direction.angle_to(Vector3.UP)))  # +X girado 90° sobre Z = +Y
	check("%s: el brazo gira 90° sobre Z y antebrazo y mano le siguen (< %s°)" % [label, MAX_DEG], worst < MAX_DEG,
		"máximo %.6f°" % worst)
	var still := maker.build(seed_value) as Skeleton3D
	var rest_points: Array[Vector3] = maker.joints(still)
	var moved_mm := 0.0
	for i in skeleton.get_bone_count():
		if not skeleton.get_bone_name(i) in ["LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftMiddleProximal", "LeftIndexProximal"]:
			moved_mm = maxf(moved_mm, 1000.0 * points[i].distance_to(rest_points[i]))
	check("%s: el resto de huesos no se mueve (< %s mm)" % [label, MAX_MM], moved_mm < MAX_MM, "%.6f mm" % moved_mm)
	still.free()

	var captured: Dictionary = pose.capture(skeleton)
	var angle := _degrees(Quaternion.IDENTITY, captured.get("LeftUpperArm", Quaternion.IDENTITY))
	check("%s: capture devuelve solo LeftUpperArm, a 90° (< %s°)" % [label, MAX_DEG],
		captured.size() == 1 and absf(angle - 90.0) < MAX_DEG, "%d claves, %.6f°" % [captured.size(), angle])

	var first: Array[Quaternion] = []
	for i in skeleton.get_bone_count():
		first.append(skeleton.get_bone_pose_rotation(i))
	pose.apply(skeleton, deltas)
	var same := true
	for i in skeleton.get_bone_count():
		same = same and skeleton.get_bone_pose_rotation(i) == first[i]
	check("%s: aplicarla dos veces da exactamente lo mismo" % label, same)

	pose.apply(skeleton, captured)
	check("%s: aplicar lo capturado deja la misma pose (< %s mm)" % [label, MAX_MM],
		_worst(points, maker.joints(skeleton)) < MAX_MM, "%.6f mm" % _worst(points, maker.joints(skeleton)))
	skeleton.free()


## La escala de la pose (Proporción) se conserva y no cambia las direcciones.
func _check_scale(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var hand := skeleton.find_bone("LeftHand")
	var root_bone := skeleton.find_bone("Root")
	skeleton.set_bone_pose_scale(hand, Vector3.ONE * 1.2)
	skeleton.set_bone_pose_scale(root_bone, Vector3.ONE * 1.15)
	pose.apply(skeleton, {"LeftUpperArm": Quaternion(Vector3(0, 0, 1), PI / 2.0)})
	var points: Array[Vector3] = maker.joints(skeleton)
	var direction := points[skeleton.find_bone("LeftMiddleProximal")] - points[hand]
	check("%s: con escalas de Proporción, se conservan y la mano apunta arriba (< %s°)" % [label, MAX_DEG],
		skeleton.get_bone_pose_scale(hand).is_equal_approx(Vector3.ONE * 1.2)
		and skeleton.get_bone_pose_scale(root_bone).is_equal_approx(Vector3.ONE * 1.15)
		and rad_to_deg(direction.angle_to(Vector3.UP)) < MAX_DEG, "%.6f°" % rad_to_deg(direction.angle_to(Vector3.UP)))
	skeleton.free()


## Caso 6: la misma pose de 6 huesos en dos esqueletos con ejes locales distintos da las mismas articulaciones.
func _check_same_pose() -> void:
	var a: Skeleton3D = maker.build(0)
	var b: Skeleton3D = maker.build(SEED_B)
	check("A y B tienen las mismas articulaciones en reposo (< %s mm)" % MAX_MM, maker.worst_mm(a, b) < MAX_MM,
		"%.6f mm" % maker.worst_mm(a, b))
	var rest_points: Array[Vector3] = maker.joints(a)
	pose.apply(a, _deltas())
	pose.apply(b, _deltas())
	check("la pose mueve de verdad el esqueleto (> 100 mm)", _worst(rest_points, maker.joints(a)) > 100.0)
	check("misma pose en A y en B: mismas articulaciones (< %s mm)" % MAX_MM, maker.worst_mm(a, b) < MAX_MM,
		"%.6f mm" % maker.worst_mm(a, b))
	a.free()
	b.free()


## Caso 7: copy lleva la pose de un esqueleto a otro con ejes distintos, en los dos sentidos.
func _check_copy() -> void:
	for seeds: Array in [[0, SEED_B], [SEED_B, 0], [SEED_B, 23]]:
		var source: Skeleton3D = maker.build(seeds[0])
		var target: Skeleton3D = maker.build(seeds[1])
		pose.apply(source, _deltas())
		pose.copy(source, target)
		check("copy de %d a %d: mismas articulaciones (< %s mm)" % [seeds[0], seeds[1], MAX_MM],
			maker.worst_mm(source, target) < MAX_MM, "%.6f mm" % maker.worst_mm(source, target))
		source.free()
		target.free()


## Caso 8: la cadera baja en proporción a su altura, también si su padre tiene los ejes girados.
func _check_hips() -> void:
	for seeds: Array in [[0, 0], [0, SEED_B], [SEED_B, 23]]:
		var source: Skeleton3D = maker.build(seeds[0])
		var target: Skeleton3D = maker.build(seeds[1], 2.0)  # el doble de alto
		var hips := source.find_bone("Hips")
		var parent_globals: Array[Transform3D] = maker.globals_of(source)
		var down := parent_globals[source.get_bone_parent(hips)].basis.inverse() * Vector3(0.0, -0.10, 0.0)
		source.set_bone_pose_position(hips, source.get_bone_rest(hips).origin + down)
		pose.copy(source, target)
		var got: Vector3 = maker.joints(target)[target.find_bone("Hips")]
		var mm := 1000.0 * got.distance_to(Vector3(0.0, 2.0 - 0.20, 0.0))
		check("cadera de %d a %d: baja 0,10 m en el origen y 0,20 m en el destino (< %s mm)" % [seeds[0], seeds[1], MAX_MM],
			mm < MAX_MM, "%.6f mm" % mm)
		source.free()
		target.free()


## La pose en espejo es el reflejo en X de la original.
func _check_mirror() -> void:
	var a: Skeleton3D = maker.build(SEED_B)
	var b: Skeleton3D = maker.build(23)
	pose.apply(a, _deltas())
	pose.apply(b, pose.mirror(_deltas()))
	var pa: Array[Vector3] = maker.joints(a)
	var pb: Array[Vector3] = maker.joints(b)
	var worst := 0.0
	for i in a.get_bone_count():
		var bone := a.get_bone_name(i)
		var other := bone
		if bone.begins_with("Left"):
			other = "Right" + bone.substr(4)
		elif bone.begins_with("Right"):
			other = "Left" + bone.substr(5)
		var reflected := pb[b.find_bone(other)] * Vector3(-1.0, 1.0, 1.0)
		worst = maxf(worst, 1000.0 * pa[i].distance_to(reflected))
	check("mirror: la pose en espejo es el reflejo en X (< %s mm)" % MAX_MM, worst < MAX_MM, "%.6f mm" % worst)
	check("mirror dos veces devuelve los mismos huesos", pose.mirror(pose.mirror(_deltas())).keys() == _deltas().keys())
	a.free()
	b.free()


## to_data y from_data: ida y vuelta por JSON, y rechazo de datos mal formados.
func _check_data() -> void:
	var data: Dictionary = pose.to_data(_deltas())
	var text := JSON.stringify(data, "", true)
	var back: Dictionary = pose.from_data(JSON.parse_string(text))
	var a: Skeleton3D = maker.build(SEED_B)
	var b: Skeleton3D = maker.build(SEED_B)
	pose.apply(a, _deltas())
	pose.apply(b, back)
	check("to_data -> JSON -> from_data: misma pose (< %s mm)" % MAX_MM, back.size() == POSE.size() and maker.worst_mm(a, b) < MAX_MM,
		"%.6f mm" % maker.worst_mm(a, b))
	check("to_data: mismo texto al repetir", JSON.stringify(pose.to_data(back), "", true) == text)
	var all_positive := true
	for bone: String in data:
		all_positive = all_positive and data[bone].size() == 4 and data[bone][3] >= 0.0
	check("to_data: 4 números por hueso y w >= 0", all_positive)
	check("from_data rechaza una lista de 3 números", pose.from_data({"Hips": [0, 0, 1]}).is_empty())
	check("from_data rechaza texto", pose.from_data({"Hips": "girado"}).is_empty())
	check("from_data rechaza un giro nulo", pose.from_data({"Hips": [0, 0, 0, 0]}).is_empty())
	pose.apply(a, {"NoExiste": Quaternion(Vector3.UP, 1.0)})
	check("apply ignora un hueso que el esqueleto no tiene", pose.capture(a).is_empty())
	a.free()
	b.free()


func _worst(a: Array[Vector3], b: Array[Vector3]) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, 1000.0 * a[i].distance_to(b[i]))
	return worst
