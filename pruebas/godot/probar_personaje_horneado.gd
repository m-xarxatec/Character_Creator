extends SceneTree
# Paso 3.6.3: hornear el personaje en uno nuevo y limpio (character_baker.gd).
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: godot --headless --path pruebas/godot -s probar_personaje_horneado.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
# Cuerpos extremo y al azar (asimétrico), con escalas de Proporción, en pose A y en pose T.
# Las líneas MEDIDA son informativas: cuánto difiere doblar la variante T horneada
# de doblar el personaje del editor puesto en T (hornear una pose cambia cómo se dobla después; ver PLAN, 5.7).

const SAME_MM := 0.1
const A_BEND_MM := 0.1  # vuelve a 0,1 tras limpiar los pesos cruzados (paso 2.5)
const MAX_DEG := 1.0
const GROUND_MM := 0.001  # medido: 0,000000 mm. Aprobado el 2026-11-11
const WEIGHT_SUM := 1e-4
const SCALES := {
	"extremo": {"height": 1.0, "head_size": 1.0, "hand_size_l": 1.0, "hand_size_r": 1.0, "foot_size_l": 1.0, "foot_size_r": 1.0},
	"al_azar": {"height": 0.3, "head_size": 0.8, "hand_size_l": 1.0, "hand_size_r": 0.0, "foot_size_l": 0.2, "foot_size_r": 0.9},
}

var failures := 0
var species
var base: Dictionary
var character_baker: GDScript
var baker: GDScript
var t_pose: GDScript
var refit: GDScript
var shapes: GDScript
var proportions: GDScript
var reference: Dictionary


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	character_baker = load(addon.path_join("character_baker.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	t_pose = load(addon.path_join("t_pose.gd"))
	refit = load(addon.path_join("skeleton_refit.gd"))
	shapes = load(addon.path_join("shape_weights.gd"))
	proportions = load(addon.path_join("proportions.gd"))
	reference = JSON.parse_string(
		FileAccess.get_file_as_string(root_dir.path_join("pruebas/fase_2/salida/referencia_reajuste.json")))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	base = refit.capture_base(species.skeleton)
	for body: String in SCALES:
		for variant: bool in [false, true]:
			_check(body, variant)
		_check_t_against_blender(body)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _set_up(body: String, scaled := true) -> void:
	var weights := {}
	for candidate: Dictionary in reference["bodies"]:
		if candidate["name"] == body:
			weights = candidate["weights"]
	shapes.apply(species.mesh, weights)
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
	var values: Dictionary = proportions.neutral_values(species.sliders)
	if scaled:
		values.merge(SCALES[body], true)
	proportions.apply(species.skeleton, proportions.scales(values, species.sliders))


func _poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(bone))
		result.append(skeleton.get_bone_rest(bone))
	return result


func _vertices(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	return baker.bake(mesh, skeleton)["vertices"]


func _worst_mm(a: PackedVector3Array, b: PackedVector3Array, offset: Vector3) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].distance_to(b[i] + offset))
	return 1000.0 * worst if a.size() == b.size() else INF


func _lowest(vertices: PackedVector3Array) -> float:
	var lowest := INF
	for vertex in vertices:
		lowest = minf(lowest, vertex.y)
	return lowest


## Gira el antebrazo izquierdo 90° sobre su cabeza con un giro global (misma posición en el mundo).
func _bend_global(skeleton: Skeleton3D) -> void:
	var bone := skeleton.find_bone("LeftLowerArm")
	var globals: Array[Transform3D] = baker.global_poses(skeleton)
	var pivot := globals[bone].origin
	var turn := Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var local := globals[skeleton.get_bone_parent(bone)].affine_inverse() * (turn * globals[bone])
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())


## Gira el antebrazo izquierdo 90° con el mismo giro local, añadido a la pose que tenga.
func _bend_local(skeleton: Skeleton3D) -> void:
	var bone := skeleton.find_bone("LeftLowerArm")
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, PI / 2.0))


func _check(body: String, t_variant: bool) -> void:
	var label := "%s, pose %s: " % [body, "T" if t_variant else "A"]
	var skeleton: Skeleton3D = species.skeleton
	_set_up(body)
	var before := _poses(skeleton)
	var character: Node3D = character_baker.bake(species.mesh, skeleton, t_variant)
	check(label + "el personaje del editor no cambia", _poses(skeleton) == before)
	var new_skeleton: Skeleton3D = character.get_child(0)
	var new_mesh: MeshInstance3D = new_skeleton.get_child(0)

	if t_variant:
		t_pose.apply(skeleton)  # a partir de aquí el original se compara en pose T
	var expected := _vertices(species.mesh, skeleton)
	var to_ground := Vector3(0.0, -_lowest(expected), 0.0)
	var baked := _vertices(new_mesh, new_skeleton)
	var raw: PackedVector3Array = new_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var clean := new_skeleton.get_bone_count() == skeleton.get_bone_count()
	for bone in new_skeleton.get_bone_count():
		clean = clean and new_skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE) \
			and new_skeleton.get_bone_rest(bone).basis.get_scale().is_equal_approx(Vector3.ONE) \
			and new_skeleton.get_bone_pose(bone).is_equal_approx(new_skeleton.get_bone_rest(bone)) \
			and new_skeleton.get_bone_name(bone) == skeleton.get_bone_name(bone)
	check(label + "57 huesos con escala 1 y pose = reposo", clean)
	var mm := _worst_mm(baked, expected, to_ground)
	check(label + "malla igual que antes de hornear (< %s mm)" % SAME_MM, mm < SAME_MM, "máximo %.5f mm" % mm)
	mm = _worst_mm(raw, baked, Vector3.ZERO)
	check(label + "en reposo, el esqueleto nuevo no mueve la malla (< %s mm)" % SAME_MM, mm < SAME_MM, "máximo %.5f mm" % mm)
	var ground_mm := 1000.0 * absf(_lowest(raw))
	check(label + "apoyado en el suelo: punto más bajo en y = 0 (< %s mm)" % GROUND_MM, ground_mm < GROUND_MM, "%.6f mm" % ground_mm)
	_check_clean_mesh(label, new_mesh)

	var arm := new_skeleton.get_bone_global_rest(new_skeleton.find_bone("LeftLowerArm")).origin \
		- new_skeleton.get_bone_global_rest(new_skeleton.find_bone("LeftUpperArm")).origin
	var angle := rad_to_deg(arm.angle_to(Vector3.RIGHT))
	check(label + ("brazos horizontales en el reposo (< %s°)" % MAX_DEG if t_variant else "brazos en A en el reposo (> 30°)"),
		angle < MAX_DEG if t_variant else angle > 30.0, "%.3f°" % angle)

	if t_variant:
		_bend_global(skeleton)
		_bend_global(new_skeleton)
	else:
		_bend_local(skeleton)
		_bend_local(new_skeleton)
	mm = _worst_mm(_vertices(new_mesh, new_skeleton), _vertices(species.mesh, skeleton), to_ground)
	if t_variant:
		print("  MEDIDA %scodo a 90°: doblar el horneado difiere del editor en T hasta %.2f mm" % [label, mm])
	else:
		check(label + "codo a 90° (mismo giro local): se dobla igual que en el editor (< %s mm)" % A_BEND_MM, mm < A_BEND_MM,
			"máximo %.5f mm" % mm)
	character.free()


## Variante T sin escalas, con el codo a 90°, contra Blender: pose T fijada como reposo con blender/pose_t.py.
func _check_t_against_blender(body: String) -> void:
	_set_up(body, false)
	var character: Node3D = character_baker.bake(species.mesh, species.skeleton, true)
	var new_skeleton: Skeleton3D = character.get_child(0)
	_bend_global(new_skeleton)
	var bent := _vertices(new_skeleton.get_child(0), new_skeleton)
	var base_vertices: PackedVector3Array = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var neutral: Array = reference["neutral_vertices"]
	var grid := {}
	for i in neutral.size():
		var cell := Vector3i((Vector3(neutral[i][0], neutral[i][1], neutral[i][2]) * 1000.0).floor())
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(i)
	var real: Array = reference["t_rest_elbow"][body]
	var worst := 0.0
	var total := 0.0
	for i in bent.size():
		var mm := INF
		var cell := Vector3i((base_vertices[i] * 1000.0).floor())
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					for k: int in grid.get(cell + Vector3i(x, y, z), []):
						if Vector3(neutral[k][0], neutral[k][1], neutral[k][2]).distance_to(base_vertices[i]) < 1e-5:
							mm = 1000.0 * bent[i].distance_to(Vector3(real[k][0], real[k][1], real[k][2]))
		worst = maxf(worst, mm)
		total += mm
	check("%s, pose T + codo a 90°: horneado = Blender con la pose T como reposo (< %s mm)" % [body, SAME_MM],
		worst < SAME_MM, "máximo %.4f mm, media %.4f mm" % [worst, total / bent.size()])
	character.free()


func _check_clean_mesh(label: String, mesh: MeshInstance3D) -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var original := (species.mesh as MeshInstance3D).mesh.surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var wrong := 0
	for i in count:
		if absf(weights[4 * i] + weights[4 * i + 1] + weights[4 * i + 2] + weights[4 * i + 3] - 1.0) > WEIGHT_SUM:
			wrong += 1
	check(label + "malla sin formas, 4 influencias que suman 1 (± %s)" % WEIGHT_SUM,
		mesh.mesh.get_blend_shape_count() == 0 and weights.size() == 4 * count and wrong == 0,
		"%d vértices no lo cumplen" % wrong)
	check(label + "UV, color garment, índices, huesos y pesos iguales que en el original",
		arrays[Mesh.ARRAY_TEX_UV] == original[Mesh.ARRAY_TEX_UV] and arrays[Mesh.ARRAY_COLOR] == original[Mesh.ARRAY_COLOR]
		and arrays[Mesh.ARRAY_INDEX] == original[Mesh.ARRAY_INDEX] and arrays[Mesh.ARRAY_BONES] == original[Mesh.ARRAY_BONES]
		and arrays[Mesh.ARRAY_WEIGHTS] == original[Mesh.ARRAY_WEIGHTS])
