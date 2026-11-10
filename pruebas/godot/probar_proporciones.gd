extends SceneTree
# Paso 3.3: deslizadores Proporción, escala uniforme de huesos (proportions.gd).
# La malla se hornea en CPU (mesh_baker.gd, paso 3.6.1): no necesita ventana.
# Uso: godot --headless --path pruebas/godot -s probar_proporciones.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Espera 2 fotogramas tras añadir la escena: si se lee una pose antes de la primera actualización del
# esqueleto, este no ve los cambios de pose hechos hasta entonces.

const MAX_MM := 0.1

var failures := 0
var proportions: GDScript
var shapes: GDScript
var baker: GDScript
var species


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	proportions = load(addon.path_join("proportions.gd"))
	shapes = load(addon.path_join("shape_weights.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	await process_frame
	await process_frame
	_check_formula()
	_check_skeleton()
	_check_mesh()
	_check_symmetry()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _scales(changes: Dictionary) -> Dictionary:
	var values: Dictionary = proportions.neutral_values(species.sliders)
	for key: String in changes:
		shapes.set_value(values, key, changes[key], false)
	return proportions.scales(values, species.sliders)


func _check_formula() -> void:
	var values: Dictionary = proportions.neutral_values(species.sliders)
	check("6 valores de Proporción", values.size() == 6, str(values.keys()))
	var expected := {"Root": [0.85, 1.15], "Head": [0.8, 1.3], "LeftHand": [0.8, 1.2], "RightHand": [0.8, 1.2],
		"LeftFoot": [0.8, 1.2], "RightFoot": [0.8, 1.2]}
	var ok := true
	for v: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var all := {}
		for key: String in values:
			all[key] = v
		var result := _scales(all)
		for bone: String in expected:
			var low: float = expected[bone][0]
			var high: float = expected[bone][1]
			var want := lerpf(low, 1.0, 2.0 * v) if v < 0.5 else lerpf(1.0, high, 2.0 * v - 1.0)
			ok = ok and result.size() == 6 and is_equal_approx(result[bone], want)
	check("fórmula en 0, 0,25, 0,5, 0,75 y 1 (6 huesos)", ok)
	check("height 0,25 → Root × 0,925", is_equal_approx(_scales({"height": 0.25})["Root"], 0.925))


func _pose(bone: String) -> Transform3D:
	var skeleton: Skeleton3D = species.skeleton
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone))


func _distance(a: String, b: String) -> float:
	return _pose(a).origin.distance_to(_pose(b).origin)


## Aplica los cambios y devuelve la proporción entre la distancia a-b después y antes, para cada par.
func _ratios(changes: Dictionary, pairs: Array) -> Array:
	proportions.apply(species.skeleton, _scales({}))
	var before := pairs.map(func(p: Array) -> float: return _distance(p[0], p[1]))
	proportions.apply(species.skeleton, _scales(changes))
	var after := pairs.map(func(p: Array) -> float: return _distance(p[0], p[1]))
	proportions.apply(species.skeleton, _scales({}))
	var result := []
	for i in pairs.size():
		result.append(after[i] / before[i])
	return result


func _near(values: Array, wanted: Array) -> bool:
	for i in values.size():
		if absf(values[i] - wanted[i]) > 1e-4:
			return false
	return true


func _check_skeleton() -> void:
	var r := _ratios({"height": 1.0}, [["Root", "Head"], ["LeftHand", "LeftMiddleDistal"]])
	check("height 1: cabeza × 1,15 desde Root (y todo lo demás)", _near(r, [1.15, 1.15]), str(r))
	r = _ratios({"hand_size_l": 1.0}, [["LeftHand", "LeftMiddleDistal"], ["LeftUpperArm", "LeftHand"],
		["RightHand", "RightMiddleDistal"]])
	check("hand_size_l 1: dedos izq. × 1,2; antebrazo y mano dcha. igual", _near(r, [1.2, 1.0, 1.0]), str(r))
	r = _ratios({"hand_size_l": 1.0}, [["LeftHand", "socket_hand_l"]])
	check("el anclaje de la mano sigue a la mano", _near(r, [1.2]), str(r))
	r = _ratios({"foot_size_r": 0.0}, [["RightFoot", "RightToes"], ["LeftFoot", "LeftToes"],
		["RightUpperLeg", "RightFoot"]])
	check("foot_size_r 0: pie dcho. × 0,8; pie izq. y pierna igual", _near(r, [0.8, 1.0, 1.0]), str(r))
	proportions.apply(species.skeleton, _scales({"head_size": 1.0}))
	var head_scale := _pose("Head").basis.get_scale()
	var neck_scale := _pose("Neck").basis.get_scale()
	proportions.apply(species.skeleton, _scales({}))
	check("head_size 1: cabeza × 1,3 en los tres ejes, cuello igual",
		head_scale.is_equal_approx(Vector3.ONE * 1.3) and neck_scale.is_equal_approx(Vector3.ONE), str(head_scale))


## (altura, punto más bajo) de la malla deformada por el esqueleto con esas escalas, horneada en CPU.
func _baked_extent(scales: Dictionary) -> Vector2:
	proportions.apply(species.skeleton, scales)
	var low := INF
	var high := -INF
	for v: Vector3 in baker.bake(species.mesh, species.skeleton)["vertices"]:
		low = minf(low, v.y)
		high = maxf(high, v.y)
	return Vector2(high - low, low)


func _check_mesh() -> void:
	var before := _baked_extent(_scales({}))
	var after := _baked_extent(_scales({"height": 1.0}))
	proportions.apply(species.skeleton, _scales({}))
	var height_mm := 1000.0 * absf(after.x - 1.15 * before.x)
	var ground_mm := 1000.0 * absf(after.y - before.y)
	check("malla horneada: altura × 1,15 (< %s mm)" % MAX_MM, height_mm < MAX_MM,
		"%.4f m → %.4f m, error %.4f mm" % [before.x, after.x, height_mm])
	check("malla horneada: pies en el suelo (< %s mm)" % MAX_MM, ground_mm < MAX_MM, "%.4f mm" % ground_mm)


func _check_symmetry() -> void:
	var values: Dictionary = proportions.neutral_values(species.sliders)
	shapes.set_value(values, "hand_size_l", 1.0, true)
	var result: Dictionary = proportions.scales(values, species.sliders)
	check("simetría: mano izq. → dcha.", is_equal_approx(result["RightHand"], 1.2) and is_equal_approx(result["LeftHand"], 1.2))
	shapes.set_value(values, "foot_size_l", NAN, true)
	check("NaN se rechaza", values["foot_size_l"] == 0.5)
