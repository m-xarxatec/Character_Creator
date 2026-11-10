extends SceneTree
# Paso 3.2: deslizadores Forma con simetría (shape_weights.gd).
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: godot --headless --path pruebas/godot -s probar_formas.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Los pesos de referencia salen de shape_weights() de blender/exportar_datos.py, la regla comparada con MPFB en el 2.3.

const MAX_WEIGHT_ERROR := 1e-6
const MAX_MM := 0.1
const CORRECTIONS := 81

var failures := 0
var shapes: GDScript
var names: PackedStringArray


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	shapes = load(root.path_join("godot/addons/creador/shape_weights.gd"))
	var species = load(root.path_join("godot/addons/creador/species_data.gd")).new()
	if species.load_folder(root.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	names = shapes.shape_names(species.mesh.mesh)
	var reference: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(root.path_join("pruebas/fase_2/salida/referencia_reajuste.json")))
	check("la referencia usa las 159 formas del .glb", PackedStringArray(reference["shapes"]) == names)
	_check_weights(reference)
	_check_values(species.sliders)
	_check_apply(species.mesh)
	for body: Dictionary in reference["bodies"]:
		if body.has("vertices"):
			_check_end_to_end(species, body, reference["neutral_vertices"])
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_weights(reference: Dictionary) -> void:
	var corrections := Array(names).filter(func(n: String) -> bool: return "*" in n).size()
	check("hay %d correcciones" % CORRECTIONS, corrections == CORRECTIONS, str(corrections))
	var cases := []
	for body: Dictionary in reference["bodies"]:
		cases.append([body["name"], body["values"], body["weights"]])
	for corner: Dictionary in reference["corners"]:
		cases.append(["esquina", corner["values"], corner["weights"]])
	for triple: Dictionary in reference["continuity"]:
		for i in 3:
			cases.append([triple["name"], triple["values"][i], triple["weights"][i]])
	var worst := 0.0
	var where := ""
	var complete := true
	var used := {}
	for case: Array in cases:
		var weights: Dictionary = shapes.weights(case[1], names)
		complete = complete and weights.size() == names.size()
		for name in names:
			var error := absf(weights[name] - case[2].get(name, 0.0))
			if weights[name] > 0.0:
				used[name] = true
			if error > worst:
				worst = error
				where = "%s, %s" % [case[0], name]
		if case[0] == "neutro":
			check("neutro: todos los pesos a 0", weights.values().max() == 0.0)
	check("pesos = script de Blender en %d casos (< %s)" % [cases.size(), MAX_WEIGHT_ERROR], worst < MAX_WEIGHT_ERROR,
		"máximo %.9f (%s)" % [worst, where])
	check("cada caso da un peso a las 159 formas", complete)
	var corrections_used := used.keys().filter(func(n: String) -> bool: return "*" in n).size()
	check("las %d correcciones entran en algún caso" % CORRECTIONS, corrections_used == CORRECTIONS, str(corrections_used))


func _check_values(sliders: Array) -> void:
	var values: Dictionary = shapes.neutral_values(sliders)
	check("39 valores (33 Forma, 6 con dos lados)", values.size() == 39, str(values.size()))
	shapes.set_value(values, "arm_muscle_l", 0.8, true)
	check("con simetría, el izquierdo mueve el derecho", values["arm_muscle_r"] == 0.8)
	shapes.set_value(values, "arm_muscle_l", 0.3, false)
	check("sin simetría, no", values["arm_muscle_l"] == 0.3 and values["arm_muscle_r"] == 0.8)
	shapes.set_value(values, "gender", 0.7, true)
	check("simetría en un deslizador de un lado: solo él", values["gender"] == 0.7)
	shapes.set_value(values, "muscle", 1.2, false)
	check("1,2 se recorta a 1", values["muscle"] == 1.0)
	shapes.set_value(values, "muscle", -0.1, false)
	check("-0,1 se recorta a 0", values["muscle"] == 0.0)
	var accepted: bool = shapes.set_value(values, "muscle", NAN, false)
	check("NaN se rechaza y no cambia nada", not accepted and values["muscle"] == 0.0)
	accepted = shapes.set_value(values, "muscle", INF, false)
	check("infinito se rechaza", not accepted and values["muscle"] == 0.0)
	check("una clave que no existe se rechaza", not shapes.set_value(values, "cola", 0.5, false))


func _check_apply(mesh: MeshInstance3D) -> void:
	var weights := {}
	for i in names.size():
		weights[names[i]] = 0.001 * i
	var missing: PackedStringArray = shapes.apply(mesh, weights)
	var ok := true
	for i in names.size():
		ok = ok and is_equal_approx(mesh.get_blend_shape_value(mesh.find_blend_shape_by_name(names[i])), 0.001 * i)
	check("apply pone cada peso en su forma", ok and missing.is_empty())
	weights["no_existe_incr"] = 1.0
	missing = shapes.apply(mesh, weights)
	check("apply avisa de una forma que no existe", missing == PackedStringArray(["no_existe_incr"]))


func _check_end_to_end(species, body: Dictionary, neutral: Array) -> void:
	var mesh: MeshInstance3D = species.mesh
	var missing: PackedStringArray = shapes.apply(mesh, shapes.weights(body["values"], names))
	var baked := mesh.bake_mesh_from_current_blend_shape_mix()
	var base: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved: PackedVector3Array = baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var to_scene := _to_scene(mesh, species.scene)
	var index := _skin_index(neutral)
	var real: Array = body["vertices"]
	var worst := 0.0
	var total := 0.0
	var unmatched := 0
	for i in base.size():
		var skin := _find(index, neutral, to_scene * base[i])
		if skin < 0:
			unmatched += 1
			continue
		var mm := 1000.0 * (to_scene * moved[i]).distance_to(_vector(real[skin]))
		worst = maxf(worst, mm)
		total += mm
	var label: String = body["name"]
	check(label + ": los vértices del .glb son los de la piel de MPFB", unmatched == 0 and missing.is_empty(),
		"%d sin pareja" % unmatched)
	check(label + ": horneado = MPFB (< %s mm)" % MAX_MM, worst < MAX_MM,
		"máximo %.4f mm, media %.4f mm (%d vértices)" % [worst, total / base.size(), base.size()])


func _to_scene(node: Node, scene: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	while node != scene:
		result = (node as Node3D).transform * result
		node = node.get_parent()
	return result


## Rejilla de 1 mm: {celda: [índices de la piel]}.
func _skin_index(points: Array) -> Dictionary:
	var grid := {}
	for i in points.size():
		var cell := Vector3i((_vector(points[i]) * 1000.0).floor())
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(i)
	return grid


## Índice del punto de la piel a menos de 0,01 mm de p, o -1.
func _find(grid: Dictionary, points: Array, p: Vector3) -> int:
	var cell := Vector3i((p * 1000.0).floor())
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				for i: int in grid.get(cell + Vector3i(x, y, z), []):
					if _vector(points[i]).distance_to(p) < 1e-5:
						return i
	return -1


func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
