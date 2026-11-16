extends SceneTree
# Paso 16.1: largo y grosor de hueso sin herencia (bone_shape.gd). Sin ventana y sin datos/.
# Uso: godot --headless --path pruebas/godot -s <ruta a este archivo> 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Busca el núcleo en godot/addons/creador/ y, si no está, en ruta/codigo/nucleo/ (borrador).
# ES LA PRUEBA QUE VALIDA EL DISEÑO de ruta/ARQUITECTURA.md §2.2. Si falla «sin cizalla al doblar», el diseño está mal:
# parar y avisar; no «probar combinaciones».
# La «malla» es una nube de puntos con pesos, movida aquí con la misma fórmula que Godot: pose global × bind pose.
# Que detecta el fallo: en BoneShape.apply, cambiar `Transform3D(local_scales[bone], …) * originals[bone].affine_inverse()`
# por `originals[bone].affine_inverse() * Transform3D(local_scales[bone], …)` -> fallan casi todos los casos.

const MAX_MM := 0.01  # PROVISIONAL (D26)
const MAX_DEG := 0.01  # PROVISIONAL (D26)
const SEEDS := [0, 7]
const SHOULDER := Vector3(0.2, 1.45, 0.0)
const ELBOW := Vector3(0.5, 1.45, 0.0)
const WRIST := Vector3(0.75, 1.45, 0.0)
const X := Vector3(1.0, 0.0, 0.0)

var failures := 0
var shape: GDScript
var pose: GDScript
var maker: GDScript
var points: Array = []  # [posición en reposo, {hueso: peso}]


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	shape = _load_core(root_dir, "bone_shape.gd")
	pose = _load_core(root_dir, "world_pose.gd")
	maker = load((get_script() as Script).resource_path.get_base_dir().path_join("esqueleto_de_prueba.gd"))
	if shape == null or pose == null or maker == null:
		print("ERROR: no se encuentra bone_shape.gd, world_pose.gd o esqueleto_de_prueba.gd")
		quit(1)
		return
	_make_points()
	_check_scale_along()
	_check_normals()
	for seed_value: int in SEEDS:
		var label := "A" if seed_value == 0 else "B"
		_check_identity(label, seed_value)
		_check_upper_arm(label, seed_value)
		_check_bent(label, seed_value)
		_check_off_axis(label, seed_value)
		_check_chain(label, seed_value)
		_check_with_proportion(label, seed_value)
	_check_ignored()
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


## Puntos alrededor de los huesos de los dos brazos, uno en cada codo a medias entre dos huesos, y un triángulo en cada mano.
func _make_points() -> void:
	var offsets: Array[Vector3] = [Vector3(0, 0.03, 0), Vector3(0, 0, 0.03), Vector3(0, -0.03, 0.01)]
	for side: Array in [["Left", 1.0], ["Right", -1.0]]:
		var mirror := Vector3(side[1], 1.0, 1.0)
		for segment: Array in [["UpperArm", SHOULDER, ELBOW], ["LowerArm", ELBOW, WRIST]]:
			for fraction: float in [0.2, 0.5, 0.8]:
				for offset: Vector3 in offsets:
					var point: Vector3 = (segment[1] as Vector3).lerp(segment[2], fraction) + offset
					points.append([point * mirror, {side[0] + segment[0]: 1.0}])
		points.append([ELBOW * mirror, {side[0] + "UpperArm": 0.5, side[0] + "LowerArm": 0.5}])
		for corner: Vector3 in [Vector3(0.02, 0, 0), Vector3(0.08, 0.01, 0.03), Vector3(0.05, -0.01, -0.03)]:
			points.append([(WRIST + corner) * mirror, {side[0] + "Hand": 1.0}])


func _skin_of(skeleton: Skeleton3D) -> Skin:
	var skin := Skin.new()
	for i in skeleton.get_bone_count():
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())
	return skin


## Dónde queda cada punto: Σ peso × (pose global × bind pose) × punto.
func _skinned(skeleton: Skeleton3D, skin: Skin) -> Array[Vector3]:
	var globals: Array[Transform3D] = maker.globals_of(skeleton)
	var result: Array[Vector3] = []
	for row: Array in points:
		var moved := Vector3.ZERO
		for bone: String in row[1]:
			var index := skeleton.find_bone(bone)
			moved += (row[1][bone] as float) * (globals[index] * skin.get_bind_pose(index) * (row[0] as Vector3))
		result.append(moved)
	return result


func _joint(skeleton: Skeleton3D, bone: String) -> Vector3:
	var joints: Array[Vector3] = maker.joints(skeleton)
	return joints[skeleton.find_bone(bone)]


func _has(index: int, bone: String) -> bool:
	return (points[index][1] as Dictionary).has(bone)


func _only(index: int, bone: String) -> bool:
	return _has(index, bone) and (points[index][1] as Dictionary).size() == 1


func _mm(a: Vector3, b: Vector3) -> float:
	return 1000.0 * a.distance_to(b)


func _check_scale_along() -> void:
	var axis := Vector3(1, 2, -1).normalized()
	var across := axis.cross(Vector3.UP).normalized()
	var scale: Basis = shape.scale_along(axis, 1.5, 0.7)
	check("scale_along: 1,5 a lo largo y 0,7 a lo ancho", (scale * axis).is_equal_approx(axis * 1.5)
		and (scale * across).is_equal_approx(across * 0.7))
	var one: Basis = shape.scale_along(axis, 1.0, 1.0)
	check("scale_along(1, 1) es la identidad", one.is_equal_approx(Basis.IDENTITY))


## La normal calculada con normal_basis sigue perpendicular a la superficie estirada; con la matriz tal cual, no.
func _check_normals() -> void:
	var matrix: Basis = shape.scale_along(X, 2.0, 0.5)
	var tangent_a := Vector3(1, 1, 0).normalized()
	var tangent_b := Vector3(0, 0, 1)
	var normal := tangent_a.cross(tangent_b).normalized()
	var good: Vector3 = (shape.normal_basis(matrix) * normal).normalized()
	var naive := (matrix * normal).normalized()
	var error_good := maxf(absf(good.dot(matrix * tangent_a)), absf(good.dot(matrix * tangent_b)))
	var error_naive := absf(naive.dot((matrix * tangent_a).normalized()))
	check("normal_basis: la normal sigue perpendicular a la superficie estirada", error_good < 0.00001, "%.7f" % error_good)
	check("(la matriz tal cual daría una normal torcida: por eso existe normal_basis)", error_naive > 0.1, "%.3f" % error_naive)


## Sin formas, o con (1, 1), no cambia nada.
func _check_identity(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var skin := _skin_of(skeleton)
	var joints_before: Array[Vector3] = maker.joints(skeleton)
	var before := _skinned(skeleton, skin)
	shape.apply(skeleton, skin, {"LeftUpperArm": Vector2(1, 1)}, {"LeftUpperArm": X})
	var after := _skinned(skeleton, skin)
	var joints_after: Array[Vector3] = maker.joints(skeleton)
	var worst := 0.0
	for i in before.size():
		worst = maxf(worst, _mm(before[i], after[i]))
	for i in joints_before.size():
		worst = maxf(worst, _mm(joints_before[i], joints_after[i]))
	check("%s: con (1, 1) no cambia nada (< %s mm)" % [label, MAX_MM], worst < MAX_MM, "%.6f mm" % worst)
	var rest_error := 0.0
	for i in before.size():
		rest_error = maxf(rest_error, _mm(before[i], points[i][0]))
	check("%s: en reposo la nube de puntos está donde se definió (< %s mm)" % [label, MAX_MM], rest_error < MAX_MM)
	skeleton.free()


## Brazo izquierdo: largo 1,5 y grosor 1,3. Comprobaciones (1), (2) y la continuidad en el codo.
func _check_upper_arm(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var skin := _skin_of(skeleton)
	var before := _skinned(skeleton, skin)
	shape.apply(skeleton, skin, {"LeftUpperArm": Vector2(1.5, 1.3)}, {"LeftUpperArm": ELBOW - SHOULDER})
	var after := _skinned(skeleton, skin)
	var push := Vector3(0.15, 0, 0)  # 0,3 m × (1,5 − 1)
	var elbow := _joint(skeleton, "LeftLowerArm")
	check("%s: el hombro no se mueve y el codo queda a 1,5 veces la distancia (< %s mm)" % [label, MAX_MM],
		_mm(_joint(skeleton, "LeftUpperArm"), SHOULDER) < MAX_MM and _mm(elbow, ELBOW + push) < MAX_MM, "%.6f mm" % _mm(elbow, ELBOW + push))
	var own := 0.0
	var followers := 0.0
	var others := 0.0
	var blend := 0.0
	for i in points.size():
		var rest: Vector3 = points[i][0]
		if _only(i, "LeftUpperArm"):
			var offset := rest - SHOULDER
			own = maxf(own, _mm(after[i], SHOULDER + Vector3(offset.x * 1.5, offset.y * 1.3, offset.z * 1.3)))
		elif _only(i, "LeftLowerArm") or _only(i, "LeftHand"):
			followers = maxf(followers, _mm(after[i], rest + push))
		elif _has(i, "LeftUpperArm"):
			blend = maxf(blend, _mm(after[i], elbow))
		else:
			others = maxf(others, _mm(after[i], before[i]))
	check("%s: los puntos del brazo se estiran 1,5 a lo largo y 1,3 a lo ancho (< %s mm)" % [label, MAX_MM], own < MAX_MM, "%.6f mm" % own)
	check("%s: antebrazo y mano se trasladan enteros, sin cambiar de tamaño (< %s mm)" % [label, MAX_MM], followers < MAX_MM,
		"%.6f mm" % followers)
	check("%s: el punto a medias entre brazo y antebrazo sigue en el codo (< %s mm)" % [label, MAX_MM], blend < MAX_MM, "%.6f mm" % blend)
	check("%s: asimetría: el brazo derecho y el resto no cambian (< %s mm)" % [label, MAX_MM], others < MAX_MM, "%.6f mm" % others)
	var joints: Array[Vector3] = maker.joints(skeleton)
	check("%s: los dedos siguen a la mano (< %s mm)" % [label, MAX_MM],
		_mm(joints[skeleton.find_bone("LeftIndexProximal")], Vector3(0.85, 1.45, 0.03) + push) < MAX_MM)
	skeleton.free()


## Comprobación (3): con el codo a 90° y con el hombro a 90°, nada se cizalla: cada parte gira entera.
func _check_bent(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var skin := _skin_of(skeleton)
	shape.apply(skeleton, skin, {"LeftUpperArm": Vector2(1.5, 1.3), "LeftLowerArm": Vector2(0.8, 1.6)},
		{"LeftUpperArm": ELBOW - SHOULDER, "LeftLowerArm": WRIST - ELBOW})
	var straight := _skinned(skeleton, skin)
	var elbow := _joint(skeleton, "LeftLowerArm")
	var turn := Basis(Vector3(0, 0, 1), PI / 2.0)

	pose.apply(skeleton, {"LeftLowerArm": Quaternion(Vector3(0, 0, 1), PI / 2.0)})
	var bent := _skinned(skeleton, skin)
	var worst := 0.0
	var upper_still := 0.0
	for i in points.size():
		if _only(i, "LeftLowerArm") or _only(i, "LeftHand"):
			worst = maxf(worst, _mm(bent[i], elbow + turn * (straight[i] - elbow)))  # giro rígido alrededor del codo
		elif _only(i, "LeftUpperArm"):
			upper_still = maxf(upper_still, _mm(bent[i], straight[i]))
	check("%s: codo a 90°: antebrazo y mano giran enteros alrededor del codo, sin cizalla (< %s mm)" % [label, MAX_MM],
		worst < MAX_MM, "%.6f mm" % worst)
	check("%s: codo a 90°: el brazo no cambia (< %s mm)" % [label, MAX_MM], upper_still < MAX_MM, "%.6f mm" % upper_still)
	var hand: Array[int] = []
	for i in points.size():
		if _only(i, "LeftHand"):
			hand.append(i)
	var degrees := 0.0
	for k in 3:
		var a: int = hand[k]
		var b: int = hand[(k + 1) % 3]
		var c: int = hand[(k + 2) % 3]
		var corner: Vector3 = points[a][0]
		var rest_angle := ((points[b][0] as Vector3) - corner).angle_to((points[c][0] as Vector3) - corner)
		degrees = maxf(degrees, rad_to_deg(absf((bent[b] - bent[a]).angle_to(bent[c] - bent[a]) - rest_angle)))
	check("%s: codo a 90°: los ángulos del triángulo de la mano no cambian (< %s°)" % [label, MAX_DEG], degrees < MAX_DEG,
		"%.6f°" % degrees)

	pose.apply(skeleton, {"LeftUpperArm": Quaternion(Vector3(0, 0, 1), PI / 2.0)})
	var raised := _skinned(skeleton, skin)
	worst = 0.0
	for i in points.size():
		if _has(i, "LeftUpperArm") or _only(i, "LeftLowerArm") or _only(i, "LeftHand"):
			worst = maxf(worst, _mm(raised[i], SHOULDER + turn * (straight[i] - SHOULDER)))
	check("%s: hombro a 90°: todo el brazo, ya estirado, gira entero alrededor del hombro (< %s mm)" % [label, MAX_MM],
		worst < MAX_MM, "%.6f mm" % worst)
	skeleton.free()


## Un hijo fuera del eje (el índice respecto a la mano) se separa con el grosor; uno en el eje, no.
func _check_off_axis(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var skin := _skin_of(skeleton)
	shape.apply(skeleton, skin, {"LeftHand": Vector2(1.0, 2.0)}, {"LeftHand": X})
	check("%s: mano con grosor 2: el dedo medio (en el eje) no se mueve (< %s mm)" % [label, MAX_MM],
		_mm(_joint(skeleton, "LeftMiddleProximal"), Vector3(0.85, 1.45, 0.0)) < MAX_MM)
	check("%s: mano con grosor 2: el índice (a 3 cm del eje) queda a 6 cm (< %s mm)" % [label, MAX_MM],
		_mm(_joint(skeleton, "LeftIndexProximal"), Vector3(0.85, 1.45, 0.06)) < MAX_MM,
		"%.6f mm" % _mm(_joint(skeleton, "LeftIndexProximal"), Vector3(0.85, 1.45, 0.06)))
	check("%s: mano con grosor 2: la muñeca no se mueve (< %s mm)" % [label, MAX_MM], _mm(_joint(skeleton, "LeftHand"), WRIST) < MAX_MM)
	skeleton.free()


## Dos huesos seguidos: los largos se suman a lo largo de la cadena.
func _check_chain(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var skin := _skin_of(skeleton)
	shape.apply(skeleton, skin, {"LeftUpperArm": Vector2(1.5, 1.0), "LeftLowerArm": Vector2(2.0, 1.0), "RightUpperArm": Vector2(0.5, 1.0)},
		{"LeftUpperArm": X, "LeftLowerArm": X, "RightUpperArm": -X})
	check("%s: brazo ×1,5 y antebrazo ×2: la muñeca avanza 0,15 + 0,25 m (< %s mm)" % [label, MAX_MM],
		_mm(_joint(skeleton, "LeftHand"), WRIST + Vector3(0.4, 0, 0)) < MAX_MM, "%.6f mm" % _mm(_joint(skeleton, "LeftHand"), WRIST + Vector3(0.4, 0, 0)))
	check("%s: brazo derecho ×0,5: su codo retrocede 0,15 m (< %s mm)" % [label, MAX_MM],
		_mm(_joint(skeleton, "RightLowerArm"), Vector3(-0.35, 1.45, 0.0)) < MAX_MM)
	skeleton.free()


## Con la escala de Proporción en la pose (uniforme, heredada), el resultado es el mismo multiplicado por esa escala.
func _check_with_proportion(label: String, seed_value: int) -> void:
	var plain: Skeleton3D = maker.build(seed_value)
	var plain_skin := _skin_of(plain)
	shape.apply(plain, plain_skin, {"LeftUpperArm": Vector2(1.5, 1.3)}, {"LeftUpperArm": X})
	var expected := _skinned(plain, plain_skin)
	var scaled: Skeleton3D = maker.build(seed_value)
	var scaled_skin := _skin_of(scaled)
	shape.apply(scaled, scaled_skin, {"LeftUpperArm": Vector2(1.5, 1.3)}, {"LeftUpperArm": X})
	scaled.set_bone_pose_scale(scaled.find_bone("Root"), Vector3.ONE * 1.15)  # Proportions.apply va después
	var got := _skinned(scaled, scaled_skin)
	var worst := 0.0
	for i in got.size():
		worst = maxf(worst, _mm(got[i], expected[i] * 1.15))
	check("%s: con Proporción 1,15 en Root, todo sale igual ×1,15 (< %s mm)" % [label, MAX_MM], worst < MAX_MM, "%.6f mm" % worst)
	plain.free()
	scaled.free()


func _check_ignored() -> void:
	var skeleton: Skeleton3D = maker.build(7)
	var skin := _skin_of(skeleton)
	var before := _skinned(skeleton, skin)
	var ignored: Array[String] = shape.apply(skeleton, skin,
		{"LeftUpperArm": Vector2(2, 2), "LeftHand": Vector2(NAN, 1), "NoExiste": Vector2(2, 2)}, {"LeftHand": X})
	check("hueso sin eje y factor no finito: se ignoran y se devuelven", ignored.size() == 2 and "LeftUpperArm" in ignored
		and "LeftHand" in ignored, str(ignored))
	check("lo ignorado no cambia nada", before == _skinned(skeleton, skin) or _same(before, _skinned(skeleton, skin)))
	shape.apply(skeleton, skin, {"LeftUpperArm": Vector2(100, 0.0001)}, {"LeftUpperArm": X})
	check("los factores se recortan a [0,2, 5]", _mm(_joint(skeleton, "LeftLowerArm"), SHOULDER + Vector3(1.5, 0, 0)) < MAX_MM)
	skeleton.free()


func _same(a: Array[Vector3], b: Array[Vector3]) -> bool:
	for i in a.size():
		if _mm(a[i], b[i]) >= MAX_MM:
			return false
	return true
