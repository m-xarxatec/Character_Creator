extends SceneTree
# Paso 5.1: animaciones de prueba (AnimationSet) pasadas al personaje del editor (PoseRetarget). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_animaciones.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Mide, en 8 instantes de cada clip, el ángulo entre cada hueso largo del personaje y el mismo hueso de la fuente.
# Ese ángulo debe ser el mismo que en la pose de referencia (deriva 0): el personaje gira lo que gira la fuente.
# En la referencia, los brazos coinciden (las dos son pose T); las piernas del personaje están algo más abiertas
# y esa diferencia se conserva al animar, igual que en un juego.

const CLIPS := ["reposo", "caminar", "correr", "atacar", "sentarse"]
const STEPS := 8
const SAME_DEG := 0.01  # sin animación, el personaje se queda en su pose T
const ARM_DEG := 3.0  # brazo y antebrazo contra la fuente, en la referencia (medida real: 0,99°)
const DRIFT_DEG := 0.1  # cuánto cambia ese ángulo al animar, en brazos y piernas
const FLOOR_MM := 45.0  # al caminar, el pie más bajo contra el de la fuente a escala (medida real: 30,9 mm, cuerpo alto).
# En los demás clips solo se mide: sin IK, con las rodillas dobladas el pie flota según las proporciones (hasta 168 mm).
const BROKEN_DEG := 20.0  # con la referencia mal tomada (pose A) el brazo debe pasar de aquí: la prueba lo detecta
const ARMS := [["LeftUpperArm", "LeftLowerArm"], ["LeftLowerArm", "LeftHand"], ["RightUpperArm", "RightLowerArm"], ["RightLowerArm", "RightHand"]]
const LEGS := [["LeftUpperLeg", "LeftLowerLeg"], ["LeftLowerLeg", "LeftFoot"], ["RightUpperLeg", "RightLowerLeg"], ["RightLowerLeg", "RightFoot"]]
const FEET := ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]
const BODIES := {"neutro": {}, "alto": {"height": 1.0, "leg_length": 1.0}, "bajo": {"height": 0.0, "leg_length": 0.0},
		"cabeza y manos grandes": {"head_size": 1.0, "hand_size_l": 1.0, "hand_size_r": 1.0}}

var failures := 0
var species
var updater
var animations
var retarget


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	updater = load(addon.path_join("character_updater.gd")).new(species)
	animations = load(addon.path_join("animation_set.gd")).new()
	var start := Time.get_ticks_msec()
	var error: String = animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	print("  MEDIDA cargar las animaciones: %d ms" % (Time.get_ticks_msec() - start))
	check("el juego de animaciones carga", error == "", error)
	if error == "":
		root.add_child(animations.scene)
		await process_frame  # fuera del árbol, Skeleton3D no refresca la pose global al mover los huesos
		check("trae los 5 clips del paso 5.1", animations.clip_ids() == CLIPS, str(animations.clip_ids()))
		check("un clip que no existe se rechaza", not animations.play("volar"))
		check("un archivo que no existe da error", load(addon.path_join("animation_set.gd")).new().load_file("nada.json") != "")
		retarget = load(addon.path_join("pose_retarget.gd")).new(animations.skeleton, species.skeleton, animations.bones, animations.hips)
		var sockets: Array = species.manifest["bones"]["sockets"].duplicate()
		sockets.sort()
		check("todos los huesos de deformación tienen pareja", _unpaired() == sockets, str(_unpaired()))
		check("cada hueso y su pareja están en el mismo lado", _wrong_side() == [], str(_wrong_side()))
		_check_identity()
		for body: String in BODIES:
			_check_body(body, BODIES[body])
		_check_detects_wrong_reference()
		_check_restore()
		_measure_time()
		animations.scene.free()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _unpaired() -> Array:
	var names := []
	for bone in species.skeleton.get_bone_count():
		if retarget.pairs[bone] < 0:
			names.append(species.skeleton.get_bone_name(bone))
	names.sort()
	return names


# Comprobación de la tabla de huesos que no depende del cálculo: izquierda con izquierda y derecha con derecha.
func _wrong_side() -> Array:
	var names := []
	for bone in species.skeleton.get_bone_count():
		var pair: int = retarget.pairs[bone]
		if pair >= 0:
			var mine: float = species.skeleton.get_bone_global_rest(bone).origin.x
			var theirs: float = animations.skeleton.get_bone_global_rest(pair).origin.x
			if absf(mine) > 0.01 and signf(mine) != signf(theirs):
				names.append(species.skeleton.get_bone_name(bone))
	return names


# Fuente en su reposo (sin animación): el personaje no debe moverse de su pose T.
func _check_identity() -> void:
	updater.update({}, true)
	retarget.capture()
	var skeleton: Skeleton3D = species.skeleton
	var before := _globals(skeleton)
	animations.player.stop()
	animations.skeleton.reset_bone_poses()
	retarget.apply()
	var after := _globals(skeleton)
	var worst_deg := 0.0
	var worst_mm := 0.0
	for bone in before.size():
		worst_deg = maxf(worst_deg, _turn_deg(before[bone], after[bone]))
		worst_mm = maxf(worst_mm, before[bone].origin.distance_to(after[bone].origin) * 1000.0)
	print("  MEDIDA fuente en reposo: giro máx. %.5f°, posición máx. %.4f mm" % [worst_deg, worst_mm])
	check("con la fuente en reposo el personaje sigue en pose T (< %s°)" % SAME_DEG, worst_deg < SAME_DEG and worst_mm < 0.01)


func _check_body(label: String, values: Dictionary) -> void:
	updater.update(values, true)
	retarget.capture()
	var scales := _scales(species.skeleton)
	var rest_floor := _lowest(species.skeleton, true)
	var source_floor := _lowest_source(true)
	animations.player.stop()
	animations.skeleton.reset_bone_poses()
	var arm_ref := _angles(ARMS)
	var leg_ref := _angles(LEGS)
	var drift := [0.0, 0.0, 0]
	var floor_mm := {}
	var moved := 0.0
	for clip: String in CLIPS:
		animations.play(clip)
		for step in STEPS:
			animations.seek(animations.length() * float(step) / STEPS)
			retarget.apply()
			_add_drift(drift, _angles(ARMS), arm_ref)
			_add_drift(drift, _angles(LEGS), leg_ref)
			moved = maxf(moved, absf(_lowest_source(false) - source_floor))
			var lifted: float = (_lowest(species.skeleton, false) - rest_floor) - (_lowest_source(false) - source_floor) * retarget.hips_ratio
			floor_mm[clip] = maxf(floor_mm.get(clip, 0.0), snappedf(absf(lifted) * 1000.0, 0.1))
	print("  MEDIDA %s: referencia brazos %.2f° piernas %.2f° | deriva al animar máx. %.4f° media %.4f° | caderas ×%.3f | pies contra el suelo de la fuente (mm) %s" % [
			label, arm_ref.max(), leg_ref.max(), drift[0], drift[1] / drift[2], retarget.hips_ratio, floor_mm])
	check("%s: la fuente se mueve de verdad (pies > 5 cm)" % label, moved > 0.05, "%.3f m" % moved)
	check("%s: en la referencia los brazos coinciden con la fuente (< %s°)" % [label, ARM_DEG], arm_ref.max() < ARM_DEG)
	check("%s: brazos y piernas giran lo que la fuente (deriva < %s°)" % [label, DRIFT_DEG], drift[0] < DRIFT_DEG)
	check("%s: al caminar los pies siguen al suelo de la fuente (< %s mm)" % [label, FLOOR_MM], floor_mm["caminar"] < FLOOR_MM)
	check("%s: la animación no toca la escala de los huesos" % label, _scales(species.skeleton) == scales)


# Si la referencia se toma en pose A (el fallo más fácil de cometer), los brazos salen torcidos y la prueba lo ve.
func _check_detects_wrong_reference() -> void:
	updater.update({}, false)
	retarget.capture()
	animations.player.stop()
	animations.skeleton.reset_bone_poses()
	var worst: float = _angles(ARMS).max()
	print("  MEDIDA referencia en pose A (mal): brazos %.2f°" % worst)
	check("la prueba detecta una referencia mal tomada (> %s°)" % BROKEN_DEG, worst > BROKEN_DEG)


func _check_restore() -> void:
	updater.update({}, false)
	var before := _globals(species.skeleton)
	updater.update({}, true)
	retarget.capture()
	animations.play("atacar")
	animations.seek(0.7)
	retarget.apply()
	check("la animación mueve el personaje", _globals(species.skeleton) != before)
	updater.update({}, false)
	check("update() después de animar deja el reposo exacto", _globals(species.skeleton) == before)


func _measure_time() -> void:
	updater.update({}, true)
	retarget.capture()
	animations.play("correr")
	var start := Time.get_ticks_usec()
	for i in 200:
		animations.advance(1.0 / 60.0)
		retarget.apply()
	print("  MEDIDA un fotograma (avanzar + pasar la pose): %.3f ms" % ((Time.get_ticks_usec() - start) / 200000.0))


# Ángulo (°) entre cada hueso del personaje y el mismo hueso de la fuente.
func _angles(bones: Array) -> Array:
	var angles := []
	for pair: Array in bones:
		var mine := _direction(species.skeleton, pair[0], pair[1])
		var theirs := _direction(animations.skeleton, animations.bones[pair[0]], animations.bones[pair[1]])
		angles.append(rad_to_deg(mine.angle_to(theirs)))
	return angles


func _add_drift(total: Array, angles: Array, reference: Array) -> void:
	for i in angles.size():
		var drift := absf(angles[i] - reference[i])
		total[0] = maxf(total[0], drift)
		total[1] += drift
		total[2] += 1


# Giro entre dos transformaciones, en grados. Con el seno: acos pierde precisión cerca de 0 (da ~0,04° de ruido).
func _turn_deg(a: Transform3D, b: Transform3D) -> float:
	var turn := a.basis.get_rotation_quaternion().inverse() * b.basis.get_rotation_quaternion()
	return rad_to_deg(2.0 * asin(minf(1.0, Vector3(turn.x, turn.y, turn.z).length())))


func _direction(skeleton: Skeleton3D, from: String, to: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(to)).origin - skeleton.get_bone_global_pose(skeleton.find_bone(from)).origin


func _lowest(skeleton: Skeleton3D, _reference: bool) -> float:
	var lowest := INF
	for bone: String in FEET:
		lowest = minf(lowest, skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin.y)
	return lowest


func _lowest_source(reference: bool) -> float:
	var skeleton: Skeleton3D = animations.skeleton
	var lowest := INF
	for bone: String in FEET:
		var index := skeleton.find_bone(animations.bones[bone])
		lowest = minf(lowest, (skeleton.get_bone_global_rest(index) if reference else skeleton.get_bone_global_pose(index)).origin.y)
	return lowest


func _globals(skeleton: Skeleton3D) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		globals.append(skeleton.get_bone_global_pose(bone))
	return globals


func _scales(skeleton: Skeleton3D) -> Array[Vector3]:
	var scales: Array[Vector3] = []
	for bone in skeleton.get_bone_count():
		scales.append(skeleton.get_bone_pose_scale(bone))
	return scales
