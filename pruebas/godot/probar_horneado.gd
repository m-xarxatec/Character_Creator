extends SceneTree
# Paso 3.6.1: horneado en CPU (mesh_baker.gd) contra el horneado de Godot, que usa la tarjeta gráfica.
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: godot --path pruebas/godot -s probar_horneado.gd 2>&1 | grep -E 'FALLO|AVISO|RESULTADO|ERROR'
# Con --headless se salta la comparación con Godot (el resto sí se prueba).

const CROSS_MM := 0.05  # medido: máx. 0,0196 mm; el horneado de Godot es el menos preciso (contra MPFB, 0,0199 frente a 0,0064 mm). Aprobado el 2026-11-11
const REST_MM := 0.01
const NORMAL_DEG := 0.1  # medido: máx. 0,015°. Aprobado el 2026-11-11
const WEIGHT_SUM := 1e-4

var failures := 0
var species
var base: Dictionary
var baker: GDScript
var refit: GDScript
var shapes: GDScript
var proportions: GDScript
var reference: Dictionary


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	baker = load(addon.path_join("mesh_baker.gd"))
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
	_check_weights()
	var windowed := DisplayServer.get_name() != "headless"
	if not windowed:
		print("  AVISO sin ventana: no se compara con el horneado de Godot")
	var cases := [
		["neutro en reposo", "neutro", {}, false],
		["largo + codo a 90°", "largo", {}, true],
		["extremo + las 6 escalas de Proporción a tope", "extremo",
			{"height": 1.0, "head_size": 1.0, "hand_size_l": 1.0, "hand_size_r": 1.0, "foot_size_l": 1.0, "foot_size_r": 1.0}, false],
		["atlético + hand_size_l = 1 + codo a 90°", "atletico", {"hand_size_l": 1.0}, true],
	]
	for case: Array in cases:
		_set_up(case[1], case[2], case[3])
		var start := Time.get_ticks_msec()
		var baked: Dictionary = baker.bake(species.mesh, species.skeleton)
		var ms := Time.get_ticks_msec() - start
		_check_normals(case[0], baked["normals"], ms)
		if windowed:
			await _check_cross(case[0], baked)
	_set_up("neutro", {}, false)
	var rest: PackedVector3Array = baker.bake(species.mesh, species.skeleton)["vertices"]
	var mm := _worst_mm(rest, species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	check("neutro en reposo: horneado = malla base (< %s mm)" % REST_MM, mm < REST_MM, "%.5f mm" % mm)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _body(name: String) -> Dictionary:
	for body: Dictionary in reference["bodies"]:
		if body["name"] == name:
			return body
	return {}


## Deja el personaje con las formas de un cuerpo, reajustado, con esas escalas y, si se pide, el codo doblado.
func _set_up(body: String, scale_values: Dictionary, bend: bool) -> void:
	var weights: Dictionary = _body(body)["weights"]
	shapes.apply(species.mesh, weights)
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
	var values: Dictionary = proportions.neutral_values(species.sliders)
	values.merge(scale_values, true)
	proportions.apply(species.skeleton, proportions.scales(values, species.sliders))
	if bend:
		_bend_elbow()


## Giro global sobre la cabeza del hueso, igual que en Blender (referencia_reajuste.py).
func _bend_elbow() -> void:
	var elbow: Dictionary = reference["elbow"]
	var skeleton: Skeleton3D = species.skeleton
	var bone := skeleton.find_bone(elbow["bone"])
	var rest := skeleton.get_bone_global_rest(bone)
	var a: Array = elbow["axis"]
	var turn := Transform3D(Basis(Vector3(a[0], a[1], a[2]), deg_to_rad(elbow["degrees"])), Vector3.ZERO)
	var turned := Transform3D(Basis.IDENTITY, rest.origin) * turn * Transform3D(Basis.IDENTITY, -rest.origin) * rest
	var local := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).affine_inverse() * turned
	skeleton.set_bone_pose_position(bone, local.origin)
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())


func _check_weights() -> void:
	var arrays: Array = species.mesh.mesh.surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var wrong := 0
	var worst := 0.0
	for i in count:
		var error := absf(weights[4 * i] + weights[4 * i + 1] + weights[4 * i + 2] + weights[4 * i + 3] - 1.0)
		worst = maxf(worst, error)
		if error > WEIGHT_SUM:
			wrong += 1
	check("4 pesos por vértice que suman 1 (± %s)" % WEIGHT_SUM, weights.size() == 4 * count and wrong == 0,
		"%d de %d vértices no lo cumplen; peor desviación %.6f" % [wrong, count, worst])


func _check_normals(label: String, normals: PackedVector3Array, ms: int) -> void:
	var wrong := 0
	for n in normals:
		if absf(n.length() - 1.0) > 1e-4:
			wrong += 1
	check(label + ": normales de longitud 1", wrong == 0, "%d mal; el horneado tardó %d ms" % [wrong, ms])


## Horneado de Godot: formas en CPU y después esqueleto con la pose que ya llegó a la tarjeta gráfica.
func _check_cross(label: String, baked: Dictionary) -> void:
	var shaped := MeshInstance3D.new()
	shaped.mesh = species.mesh.bake_mesh_from_current_blend_shape_mix()
	shaped.skin = species.mesh.skin
	species.skeleton.add_child(shaped)
	shaped.skeleton = NodePath("..")
	await process_frame
	await process_frame
	var arrays := shaped.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)
	shaped.queue_free()
	var mm := _worst_mm(baked["vertices"], arrays[Mesh.ARRAY_VERTEX])
	check(label + ": CPU = Godot (< %s mm)" % CROSS_MM, mm < CROSS_MM, "máximo %.5f mm" % mm)
	var godot_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var worst := 0.0
	var total := 0.0
	for i in godot_normals.size():
		var angle := rad_to_deg(godot_normals[i].normalized().angle_to(baked["normals"][i]))
		worst = maxf(worst, angle)
		total += angle
	check(label + ": normales CPU = Godot (< %s°)" % NORMAL_DEG, worst < NORMAL_DEG,
		"máximo %.3f°, media %.4f°" % [worst, total / godot_normals.size()])


func _worst_mm(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].distance_to(b[i]))
	return 1000.0 * worst if a.size() == b.size() else INF
