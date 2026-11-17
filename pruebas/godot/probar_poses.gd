extends SceneTree
# Paso 5.2: poses extremas del banco (brazos arriba, sentadilla, giro de tronco), escritas en
# datos/animaciones/humanoide.json y puestas con StaticPose. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_poses.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Cada pose se comprueba midiendo los huesos del personaje, no los números del archivo.

const POSES := ["brazos_arriba", "sentadilla", "giro_tronco"]
const UP_DEG := 10.0  # brazos arriba: brazo contra la vertical (medida real: 5,00°)
const THIGH_DEG := 10.0  # sentadilla: muslo contra la horizontal (medida real: 3,7–5,8°, según el cuerpo)
const KNEE_DEG := [100.0, 120.0]  # sentadilla: cuánto se dobla la rodilla (medida real: 109,5–112,0°)
const DROP := 0.25  # sentadilla: la cadera baja al menos esta parte de su altura (medida real: 40–61 %)
const TWIST_DEG := [43.0, 47.0]  # giro de tronco: hombros contra caderas (medida real: 45,00°)
const FLOOR_MM := 0.1  # el pie más bajo queda a la altura de la pose T
const BODIES := {"neutro": {}, "alto": {"height": 1.0, "leg_length": 1.0}, "bajo": {"height": 0.0, "leg_length": 0.0},
		"cabeza y manos grandes": {"head_size": 1.0, "hand_size_l": 1.0, "hand_size_r": 1.0}}

var failures := 0
var species
var updater
var animations
var pose: GDScript
var skeleton: Skeleton3D


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	skeleton = species.skeleton
	updater = load(addon.path_join("character_updater.gd")).new(species)
	pose = load(addon.path_join("static_pose.gd"))
	animations = load(addon.path_join("animation_set.gd")).new()
	var error: String = animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	check("el juego de animaciones carga", error == "", error)
	if error == "":
		root.add_child(animations.scene)
		await process_frame  # fuera del árbol, Skeleton3D no refresca la pose global al mover los huesos
		var ids: Array = animations.poses.map(func(p: Dictionary) -> String: return p["id"])
		check("trae las 3 poses del paso 5.2", ids == POSES, str(ids))
		check("una pose que no existe da un diccionario vacío", animations.pose_turns("volar").is_empty())
		check("la lista junta clips y poses", animations.entries().size() == animations.clips.size() + POSES.size())
		for body: String in BODIES:
			_check_arms_up(body, BODIES[body])
			_check_squat(body, BODIES[body])
			_check_twist(body, BODIES[body])
		_check_children_follow()
		_check_restore()
		animations.scene.free()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


# Pone el cuerpo en pose T, apunta el suelo y las escalas, y aplica la pose.
func _pose(values: Dictionary, id: String) -> Dictionary:
	updater.update(values, true)
	var before := {"floor": _lowest(), "hips": _at("Hips").y, "scales": _scales(), "feet": [_at("LeftFoot"), _at("RightFoot")]}
	pose.apply(skeleton, animations.pose_turns(id), animations.hips, animations.feet)
	return before


func _check_common(label: String, before: Dictionary) -> void:
	var floor_mm := absf(_lowest() - before["floor"]) * 1000.0
	check("%s: el pie más bajo sigue en el suelo (< %s mm)" % [label, FLOOR_MM], floor_mm < FLOOR_MM, "%.4f mm" % floor_mm)
	check("%s: la pose no toca la escala de los huesos" % label, _scales() == before["scales"])


func _check_arms_up(body: String, values: Dictionary) -> void:
	var before := _pose(values, "brazos_arriba")
	var worst := 0.0
	for side: String in ["Left", "Right"]:
		worst = maxf(worst, rad_to_deg((_at(side + "LowerArm") - _at(side + "UpperArm")).angle_to(Vector3.UP)))
		worst = maxf(worst, rad_to_deg((_at(side + "Hand") - _at(side + "LowerArm")).angle_to(Vector3.UP)))
	var above := minf(_at("LeftHand").y, _at("RightHand").y) - _at("Head").y
	print("  MEDIDA %s, brazos arriba: brazo contra la vertical máx. %.2f°; manos %.3f m sobre la cabeza" % [body, worst, above])
	check("%s, brazos arriba: brazos casi verticales (< %s°)" % [body, UP_DEG], worst < UP_DEG)
	check("%s, brazos arriba: las manos quedan sobre la cabeza" % body, above > 0.0)
	_check_common(body + ", brazos arriba", before)


func _check_squat(body: String, values: Dictionary) -> void:
	var before := _pose(values, "sentadilla")
	var thigh := 0.0
	var knee := [INF, 0.0]
	for side: String in ["Left", "Right"]:
		var upper := _at(side + "LowerLeg") - _at(side + "UpperLeg")
		var lower := _at(side + "Foot") - _at(side + "LowerLeg")
		thigh = maxf(thigh, absf(90.0 - rad_to_deg(upper.angle_to(Vector3.DOWN))))
		var bend := rad_to_deg(upper.angle_to(lower))
		knee = [minf(knee[0], bend), maxf(knee[1], bend)]
	var drop: float = (before["hips"] - _at("Hips").y) / before["hips"]
	var knees_forward := minf(_at("LeftLowerLeg").z, _at("RightLowerLeg").z) - _at("Hips").z
	print("  MEDIDA %s, sentadilla: muslo contra la horizontal máx. %.2f°; rodilla %.2f–%.2f°; cadera baja %.1f %%; rodillas %.3f m delante" % [
			body, thigh, knee[0], knee[1], drop * 100.0, knees_forward])
	check("%s, sentadilla: muslos casi horizontales (< %s°)" % [body, THIGH_DEG], thigh < THIGH_DEG)
	check("%s, sentadilla: rodillas dobladas entre %s y %s°" % [body, KNEE_DEG[0], KNEE_DEG[1]], knee[0] > KNEE_DEG[0] and knee[1] < KNEE_DEG[1])
	check("%s, sentadilla: la cadera baja (> %d %%)" % [body, DROP * 100], drop > DROP)
	check("%s, sentadilla: las rodillas van hacia delante" % body, knees_forward > 0.1)
	_check_common(body + ", sentadilla", before)


func _check_twist(body: String, values: Dictionary) -> void:
	var before := _pose(values, "giro_tronco")
	var shoulders := _flat(_at("LeftUpperArm") - _at("RightUpperArm"))
	var hips := _flat(_at("LeftUpperLeg") - _at("RightUpperLeg"))
	var twist := rad_to_deg(shoulders.angle_to(hips))
	var feet_mm := maxf(_at("LeftFoot").distance_to(before["feet"][0]), _at("RightFoot").distance_to(before["feet"][1])) * 1000.0
	print("  MEDIDA %s, giro de tronco: hombros contra caderas %.2f°; los pies se mueven %.4f mm" % [body, twist, feet_mm])
	check("%s, giro de tronco: entre %s y %s°" % [body, TWIST_DEG[0], TWIST_DEG[1]], twist > TWIST_DEG[0] and twist < TWIST_DEG[1])
	check("%s, giro de tronco: los pies no se mueven (< %s mm)" % [body, FLOOR_MM], feet_mm < FLOOR_MM)
	_check_common(body + ", giro de tronco", before)


# El giro de un hueso arrastra a sus hijos: con solo el hombro girado, la mano se mueve; sin giros, nada se mueve.
func _check_children_follow() -> void:
	updater.update({}, true)
	var hand := _at("LeftHand")
	pose.apply(skeleton, {}, animations.hips, animations.feet)
	check("una pose sin giros deja la pose T", _at("LeftHand").distance_to(hand) < 0.00001)
	var twist := rad_to_deg(_flat(_at("LeftUpperArm") - _at("RightUpperArm")).angle_to(_flat(_at("LeftUpperLeg") - _at("RightUpperLeg"))))
	check("sin pose el tronco no está girado: la medida del giro distingue (< 1°)", twist < 1.0, "%.3f°" % twist)
	pose.apply(skeleton, {"LeftShoulder": [0, 0, 30], "HuesoQueNoExiste": [90, 0, 0]}, animations.hips, animations.feet)
	check("girar el hombro sube la mano; un hueso desconocido se ignora", _at("LeftHand").y > hand.y + 0.2,
			"%.3f → %.3f m" % [hand.y, _at("LeftHand").y])


func _check_restore() -> void:
	updater.update({}, false)
	var before := _globals()
	updater.update({}, true)
	pose.apply(skeleton, animations.pose_turns("sentadilla"), animations.hips, animations.feet)
	check("la pose mueve el personaje", _globals() != before)
	updater.update({}, false)
	check("update() después de la pose deja el reposo exacto", _globals() == before)


func _at(bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _lowest() -> float:
	var lowest := INF
	for bone: String in animations.feet:
		lowest = minf(lowest, _at(bone).y)
	return lowest


func _globals() -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		globals.append(skeleton.get_bone_global_pose(bone))
	return globals


func _scales() -> Array[Vector3]:
	var scales: Array[Vector3] = []
	for bone in skeleton.get_bone_count():
		scales.append(skeleton.get_bone_pose_scale(bone))
	return scales
