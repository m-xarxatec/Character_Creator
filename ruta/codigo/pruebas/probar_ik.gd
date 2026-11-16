extends SceneTree
# Paso 10.10: cinemática inversa de dos huesos (two_bone_ik.gd). Sin ventana y sin datos/.
# Uso: godot --headless --path pruebas/godot -s <ruta a este archivo> 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
# Busca el núcleo en godot/addons/creador/ y, si no está, en ruta/codigo/nucleo/ (borrador).
# Que detecta el fallo: (1) en solve, cambiar `* upper` por nada en la línea de `lower` -> falla «llega al objetivo»;
# (2) cambiar el signo de `bend * (a * sin_root)` -> falla «el codo se dobla hacia el polo».

const REACH_MM := 0.05  # PROVISIONAL (D26)
const RIGID_MM := 0.01  # PROVISIONAL (D26)
const MAX_DEG := 0.01  # PROVISIONAL (D26)
const SEEDS := [0, 7]  # esqueleto A (ejes del mundo) y B (ejes locales al azar)
const ARM := ["LeftUpperArm", "LeftLowerArm", "LeftHand"]
const LEG := ["RightUpperLeg", "RightLowerLeg", "RightFoot"]
const RANDOM_TARGETS := 50

var failures := 0
var ik: GDScript
var pose: GDScript
var maker: GDScript


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	ik = _load_core(root_dir, "two_bone_ik.gd")
	pose = _load_core(root_dir, "world_pose.gd")
	maker = load((get_script() as Script).resource_path.get_base_dir().path_join("esqueleto_de_prueba.gd"))
	if ik == null or pose == null or maker == null:
		print("ERROR: no se encuentra two_bone_ik.gd, world_pose.gd o esqueleto_de_prueba.gd")
		quit(1)
		return
	_check_solve()
	for seed_value: int in SEEDS:
		var label := "A" if seed_value == 0 else "B"
		_check_reach(label, seed_value)
		_check_far(label, seed_value)
		_check_pole(label, seed_value)
		_check_tip_rotation(label, seed_value)
		_check_leg(label, seed_value)
		_check_random(label, seed_value)
	_check_degenerate()
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


func _point(skeleton: Skeleton3D, bone: String) -> Vector3:
	var points: Array[Vector3] = maker.joints(skeleton)
	return points[skeleton.find_bone(bone)]


## Solo la función pura: triángulo de lados conocidos.
func _check_solve() -> void:
	var root_point := Vector3(0, 0, 0)
	var mid := Vector3(0.3, 0, 0)
	var tip := Vector3(0.55, 0, 0)
	var target := Vector3(0.3, 0.2, 0.1)
	var solved: Dictionary = ik.solve(root_point, mid, tip, target, Vector3(0, -1, 0))
	var new_mid: Vector3 = solved["mid"]
	var new_tip: Vector3 = solved["tip"]
	check("solve: la punta calculada es el objetivo (< %s mm)" % REACH_MM, 1000.0 * new_tip.distance_to(target) < REACH_MM)
	check("solve: los dos huesos conservan su largo (< %s mm)" % RIGID_MM,
		1000.0 * absf(new_mid.length() - 0.3) < RIGID_MM and 1000.0 * absf(new_mid.distance_to(new_tip) - 0.25) < RIGID_MM)
	var upper: Basis = solved["upper"]
	var lower: Basis = solved["lower"]
	check("solve: upper lleva el codo a su sitio (< %s mm)" % RIGID_MM, 1000.0 * (upper * mid).distance_to(new_mid) < RIGID_MM)
	check("solve: lower lleva el antebrazo a su dirección (< %s°)" % MAX_DEG,
		rad_to_deg((lower * (tip - mid)).angle_to(new_tip - new_mid)) < MAX_DEG)
	check("solve: devuelve reached = true", solved["reached"] == true)
	var far: Dictionary = ik.solve(root_point, mid, tip, Vector3(5, 0, 0), Vector3(0, -1, 0))
	check("solve: objetivo lejano -> reached = false", far["reached"] == false)


## Un objetivo al alcance: la mano llega, los huesos no cambian de largo y el resto del cuerpo no se mueve.
func _check_reach(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var before: Array[Vector3] = maker.joints(skeleton)
	var target := Vector3(0.45, 1.2, 0.25)
	var reached: bool = ik.apply(skeleton, ARM[0], ARM[1], ARM[2], target, Vector3(0.4, 0.5, -0.5))
	var after: Array[Vector3] = maker.joints(skeleton)
	var mm := 1000.0 * _point(skeleton, ARM[2]).distance_to(target)
	check("%s: la mano llega al objetivo (< %s mm)" % [label, REACH_MM], reached and mm < REACH_MM, "%.6f mm" % mm)
	var rigid := 0.0
	var others := 0.0
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		if parent >= 0:
			rigid = maxf(rigid, 1000.0 * absf(after[i].distance_to(after[parent]) - before[i].distance_to(before[parent])))
		if not skeleton.get_bone_name(i).begins_with("Left") or skeleton.get_bone_name(i).contains("Leg") \
				or skeleton.get_bone_name(i).contains("Foot") or skeleton.get_bone_name(i).contains("Toes") \
				or skeleton.get_bone_name(i) == ARM[0]:
			others = maxf(others, 1000.0 * after[i].distance_to(before[i]))
	check("%s: ningún hueso cambia de largo (< %s mm)" % [label, RIGID_MM], rigid < RIGID_MM, "%.6f mm" % rigid)
	check("%s: el hombro y el resto del cuerpo no se mueven (< %s mm)" % [label, RIGID_MM], others < RIGID_MM, "%.6f mm" % others)
	skeleton.free()


## Fuera de alcance: brazo estirado apuntando al objetivo, y devuelve false.
func _check_far(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var shoulder := _point(skeleton, ARM[0])
	var full := shoulder.distance_to(_point(skeleton, ARM[1])) + _point(skeleton, ARM[1]).distance_to(_point(skeleton, ARM[2]))
	var target := shoulder + Vector3(1.0, 2.0, -1.5)
	var reached: bool = ik.apply(skeleton, ARM[0], ARM[1], ARM[2], target, Vector3(0, 0, -1))
	var hand := _point(skeleton, ARM[2])
	var degrees := rad_to_deg((hand - shoulder).angle_to(target - shoulder))
	check("%s: fuera de alcance, el brazo apunta al objetivo (< %s°) y devuelve false" % [label, MAX_DEG],
		not reached and degrees < MAX_DEG, "%.6f°" % degrees)
	check("%s: fuera de alcance, el brazo queda estirado (> 99,9 %% de su largo)" % label,
		hand.distance_to(shoulder) > 0.999 * full and hand.distance_to(shoulder) <= full + 0.00001,
		"%.4f de %.4f m" % [hand.distance_to(shoulder), full])
	skeleton.free()


## El codo se dobla hacia el polo y queda en el plano hombro–objetivo–polo.
func _check_pole(label: String, seed_value: int) -> void:
	for pole: Vector3 in [Vector3(0.3, 0.2, -1.0), Vector3(0.3, 3.0, 0.2), Vector3(0.3, -2.0, 0.5)]:
		var skeleton: Skeleton3D = maker.build(seed_value)
		var target := Vector3(0.5, 1.35, 0.2)
		ik.apply(skeleton, ARM[0], ARM[1], ARM[2], target, pole)
		var shoulder := _point(skeleton, ARM[0])
		var elbow := _point(skeleton, ARM[1])
		var axis := (target - shoulder).normalized()
		var elbow_side := (elbow - shoulder) - axis * (elbow - shoulder).dot(axis)
		var pole_side := (pole - shoulder) - axis * (pole - shoulder).dot(axis)
		var degrees := rad_to_deg(elbow_side.angle_to(pole_side))
		check("%s: el codo se dobla hacia el polo %s (< %s°)" % [label, pole, MAX_DEG], degrees < MAX_DEG, "%.6f°" % degrees)
		skeleton.free()


## Con keep_tip_rotation, la mano conserva su giro en el mundo; sin él, sigue al antebrazo.
func _check_tip_rotation(label: String, seed_value: int) -> void:
	var target := Vector3(0.4, 1.1, 0.3)
	var pole := Vector3(0.4, 0.0, -1.0)
	var kept: Skeleton3D = maker.build(seed_value)
	ik.apply(kept, ARM[0], ARM[1], ARM[2], target, pole, true)
	var finger := _point(kept, "LeftMiddleProximal") - _point(kept, ARM[2])
	check("%s: la mano conserva su giro en el mundo (< %s°)" % [label, MAX_DEG],
		rad_to_deg(finger.angle_to(Vector3.RIGHT)) < MAX_DEG, "%.6f°" % rad_to_deg(finger.angle_to(Vector3.RIGHT)))
	var follows: Skeleton3D = maker.build(seed_value)
	ik.apply(follows, ARM[0], ARM[1], ARM[2], target, pole, false)
	var forearm := _point(follows, ARM[2]) - _point(follows, ARM[1])
	finger = _point(follows, "LeftMiddleProximal") - _point(follows, ARM[2])
	check("%s: sin conservar, la mano sigue al antebrazo (< %s°)" % [label, MAX_DEG],
		rad_to_deg(finger.angle_to(forearm)) < MAX_DEG, "%.6f°" % rad_to_deg(finger.angle_to(forearm)))
	check("%s: en los dos casos la muñeca llega (< %s mm)" % [label, REACH_MM],
		1000.0 * _point(kept, ARM[2]).distance_to(target) < REACH_MM and 1000.0 * _point(follows, ARM[2]).distance_to(target) < REACH_MM)
	kept.free()
	follows.free()


## Pierna: el pie sube y la rodilla va hacia delante (+Z).
func _check_leg(label: String, seed_value: int) -> void:
	var skeleton: Skeleton3D = maker.build(seed_value)
	var target := Vector3(-0.1, 0.4, 0.1)
	var hip := _point(skeleton, LEG[0])
	var reached: bool = ik.apply(skeleton, LEG[0], LEG[1], LEG[2], target, hip + Vector3(0, -0.3, 2.0))
	var knee := _point(skeleton, LEG[1])
	var mm := 1000.0 * _point(skeleton, LEG[2]).distance_to(target)
	check("%s: el pie llega (< %s mm) y la rodilla queda delante" % [label, REACH_MM], reached and mm < REACH_MM and knee.z > 0.1,
		"%.6f mm, rodilla en z = %.3f" % [mm, knee.z])
	var toes := _point(skeleton, "RightToes") - _point(skeleton, LEG[2])
	check("%s: el pie conserva su giro en el mundo (< %s°)" % [label, MAX_DEG],
		rad_to_deg(toes.angle_to(Vector3(0.0, -0.06, 0.14))) < MAX_DEG)
	skeleton.free()


## Muchos objetivos al azar, encadenados (cada uno parte de la pose anterior): al alcance -> llega; siempre números finitos.
func _check_random(label: String, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 38
	var skeleton: Skeleton3D = maker.build(seed_value)
	var shoulder := _point(skeleton, ARM[0])
	var worst := 0.0
	var reached_count := 0
	var finite := true
	var consistent := true
	for n in RANDOM_TARGETS:
		var target := shoulder + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7))
		var pole := shoulder + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var reached: bool = ik.apply(skeleton, ARM[0], ARM[1], ARM[2], target, pole)
		var hand := _point(skeleton, ARM[2])
		finite = finite and is_finite(hand.x) and is_finite(hand.y) and is_finite(hand.z)
		var mm := 1000.0 * hand.distance_to(target)
		if reached:
			reached_count += 1
			worst = maxf(worst, mm)
		else:
			consistent = consistent and mm > 0.0005  # la mitad del umbral de «alcanzado» de two_bone_ik.gd
	print("  MEDIDA %s: %d de %d objetivos al alcance; error máximo %.6f mm" % [label, reached_count, RANDOM_TARGETS, worst])
	check("%s: %d objetivos al azar: los alcanzables llegan (< %s mm)" % [label, RANDOM_TARGETS, REACH_MM],
		reached_count > 5 and worst < REACH_MM, "%.6f mm" % worst)
	check("%s: nunca sale un número no finito y «no llega» es verdad" % label, finite and consistent)
	var drift := 1000.0 * _point(skeleton, ARM[0]).distance_to(shoulder)
	check("%s: tras %d movimientos el hombro sigue en su sitio (< %s mm)" % [label, RANDOM_TARGETS, RIGID_MM], drift < RIGID_MM,
		"%.6f mm" % drift)
	skeleton.free()


## Casos límite: objetivo en el hombro, polo en línea con el objetivo, hueso que no existe.
func _check_degenerate() -> void:
	var skeleton: Skeleton3D = maker.build(7)
	var shoulder := _point(skeleton, ARM[0])
	ik.apply(skeleton, ARM[0], ARM[1], ARM[2], shoulder, Vector3(0, 0, -1))
	var hand := _point(skeleton, ARM[2])
	check("objetivo en el hombro: números finitos", is_finite(hand.x) and is_finite(hand.y) and is_finite(hand.z))
	var target := shoulder + Vector3(0.3, -0.2, 0.1)
	var reached: bool = ik.apply(skeleton, ARM[0], ARM[1], ARM[2], target, shoulder + (target - shoulder) * 3.0)
	check("polo en línea con el objetivo: llega igualmente (< %s mm)" % REACH_MM,
		reached and 1000.0 * _point(skeleton, ARM[2]).distance_to(target) < REACH_MM)
	var before: Array[Vector3] = maker.joints(skeleton)
	var missing: bool = ik.apply(skeleton, "NoExiste", ARM[1], ARM[2], Vector3.ZERO, Vector3.UP)
	var after: Array[Vector3] = maker.joints(skeleton)
	check("hueso que no existe: devuelve false y no toca la pose", not missing and before == after)
	skeleton.free()
