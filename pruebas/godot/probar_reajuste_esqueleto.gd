extends SceneTree
# Paso 3.4: reajuste de huesos en el esqueleto real, con sus bind poses (skeleton_refit.gd).
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: godot --path pruebas/godot -s probar_reajuste_esqueleto.gd 2>&1 | grep -E 'FALLO|AVISO|RESULTADO|ERROR'
# Con --headless también funciona, pero se salta las pruebas de malla horneada (necesitan la tarjeta gráfica).

const MAX_MM := 1.0
const MAX_DEG := 1.0
const EXACT_MM := 0.001
const LOAD_MM := 0.01  # articulaciones.json está redondeado a micras
const STILL_MM := 0.01  # Godot calcula con 32 bits: encadenar 57 huesos deja ~0,002 mm de redondeo
const ELBOW_MM := 0.5
const MAX_REFIT_MS := 1.0

var failures := 0
var addon: String
var data_folder: String
var refit: GDScript
var shapes: GDScript
var reference: Dictionary


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	addon = root_dir.path_join("godot/addons/creador")
	data_folder = root_dir.path_join("datos/humana")
	refit = load(addon.path_join("skeleton_refit.gd"))
	shapes = load(addon.path_join("shape_weights.gd"))
	reference = JSON.parse_string(
		FileAccess.get_file_as_string(root_dir.path_join("pruebas/fase_2/salida/referencia_reajuste.json")))
	var species = _load_species()
	var other = _load_species()
	var base: Dictionary = refit.capture_base(species.skeleton)
	var loaded := _snapshot(species)
	var other_loaded := _snapshot(other)
	for body: Dictionary in reference["bodies"]:
		_check_body(species, base, body)
	_check_round_trip(species, base, loaded)
	check("dos personajes: Skin distinta y el otro no cambia tras reajustar el primero",
		species.mesh.skin != other.mesh.skin and _difference_mm(other_loaded, _snapshot(other)) == 0.0)
	_check_scale(species, base)
	_check_time(species, base)
	if DisplayServer.get_name() == "headless":
		print("  AVISO sin ventana: no se prueban la malla quieta ni el codo doblado")
	else:
		await _check_baked(species, base)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _load_species():
	var species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(data_folder):
		print("ERROR: ", species.error)
	root.add_child(species.scene)
	return species


func _body(name: String) -> Dictionary:
	for body: Dictionary in reference["bodies"]:
		if body["name"] == name:
			return body
	return {}


func _refit(species, base: Dictionary, weights: Dictionary) -> void:
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)


## Reposos globales y bind poses, para comparar dos momentos.
func _snapshot(species) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for i in species.skeleton.get_bone_count():
		result.append(species.skeleton.get_bone_global_rest(i))
	for i in species.mesh.skin.get_bind_count():
		result.append(species.mesh.skin.get_bind_pose(i))
	return result


func _difference_mm(a: Array[Transform3D], b: Array[Transform3D]) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].origin.distance_to(b[i].origin))
		for axis in 3:  # el giro, medido a 1 m del hueso
			worst = maxf(worst, a[i].basis[axis].distance_to(b[i].basis[axis]))
	return 1000.0 * worst


func _check_body(species, base: Dictionary, body: Dictionary) -> void:
	_refit(species, base, body["weights"])
	var skeleton: Skeleton3D = species.skeleton
	var skin: Skin = species.mesh.skin
	var mm := 0.0
	var deg := 0.0
	var identity := 0.0
	var pose := true
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		var rest := skeleton.get_bone_global_rest(i)
		var real: Dictionary = body["bones"][bone]
		mm = maxf(mm, 1000.0 * rest.origin.distance_to(_vector(real["head"])))
		# Giro respecto a la base: así no importa el convenio de ejes de hueso de Blender o de glTF.
		var turned := rest.basis * (base[bone] as Basis).inverse()
		var real_turned := _basis(real["basis"]) * _basis(reference["base"][bone]).inverse()
		deg = maxf(deg, _angle(turned, real_turned))
		var still := rest * skin.get_bind_pose(i)
		identity = maxf(identity, 1000.0 * (still.origin.length() + still.basis.x.distance_to(Vector3.RIGHT)
			+ still.basis.y.distance_to(Vector3.UP) + still.basis.z.distance_to(Vector3.BACK)))
		pose = pose and skeleton.get_bone_pose(i).is_equal_approx(skeleton.get_bone_rest(i))
	var name: String = body["name"]
	check(name + ": reposo = MPFB (< %s mm, < %s°)" % [MAX_MM, MAX_DEG], mm < MAX_MM and deg < MAX_DEG,
		"máximo %.4f mm, %.4f°" % [mm, deg])
	check(name + ": reposo × bind pose = identidad (< %s mm) y pose = reposo" % STILL_MM, identity < STILL_MM and pose,
		"%.5f mm" % identity)


func _check_round_trip(species, base: Dictionary, loaded: Array[Transform3D]) -> void:
	_refit(species, base, {})
	var neutral := _snapshot(species)
	var mm := _difference_mm(loaded, neutral)
	check("neutro reajustado = recién cargado (< %s mm)" % LOAD_MM, mm < LOAD_MM, "%.5f mm" % mm)
	_refit(species, base, _body("extremo")["weights"])
	_refit(species, base, {})
	mm = _difference_mm(neutral, _snapshot(species))
	check("ida a extremo y vuelta a neutro: igual (< %s mm)" % EXACT_MM, mm < EXACT_MM, "%.5f mm" % mm)


func _check_scale(species, base: Dictionary) -> void:
	var skeleton: Skeleton3D = species.skeleton
	var hand := skeleton.find_bone("LeftHand")
	skeleton.set_bone_pose_scale(hand, Vector3.ONE * 1.2)
	_refit(species, base, _body("largo")["weights"])
	check("la escala de Proporción sigue tras reajustar", skeleton.get_bone_pose_scale(hand).is_equal_approx(Vector3.ONE * 1.2))
	skeleton.set_bone_pose_scale(hand, Vector3.ONE)


func _check_time(species, base: Dictionary) -> void:
	var weights: Dictionary = _body("al_azar")["weights"]
	var start := Time.get_ticks_usec()
	for i in 100:
		_refit(species, base, weights)
	var ms := (Time.get_ticks_usec() - start) / 100000.0
	print(("  bien  " if ms < MAX_REFIT_MS else "  AVISO ") + "un reajuste tarda %.3f ms (aviso si > %s ms)" % [ms, MAX_REFIT_MS])


## Vértices del personaje con sus formas y su pose actuales (formas en CPU + esqueleto en la tarjeta gráfica).
func _baked_vertices(species) -> PackedVector3Array:
	var shaped := MeshInstance3D.new()
	shaped.mesh = species.mesh.bake_mesh_from_current_blend_shape_mix()
	shaped.skin = species.mesh.skin
	species.skeleton.add_child(shaped)
	shaped.skeleton = NodePath("..")
	await process_frame
	await process_frame
	var baked := shaped.bake_mesh_from_current_skeleton_pose()
	shaped.queue_free()
	return baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _check_baked(species, base: Dictionary) -> void:
	await process_frame
	await process_frame
	var elbow: Dictionary = reference["elbow"]
	var weights: Dictionary = _body(elbow["body"])["weights"]
	shapes.apply(species.mesh, weights)
	_refit(species, base, weights)
	var shaped: PackedVector3Array = species.mesh.bake_mesh_from_current_blend_shape_mix().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var still := await _baked_vertices(species)
	var worst := 0.0
	for i in shaped.size():
		worst = maxf(worst, 1000.0 * shaped[i].distance_to(still[i]))
	check("%s reajustado y en reposo: el esqueleto no mueve la malla (< %s mm)" % [elbow["body"], STILL_MM],
		worst < STILL_MM, "máximo %.5f mm" % worst)
	# Codo: giro global sobre la cabeza del hueso, igual que en Blender.
	var skeleton: Skeleton3D = species.skeleton
	var bone := skeleton.find_bone(elbow["bone"])
	var rest := skeleton.get_bone_global_rest(bone)
	var turn := Transform3D(Basis(_vector(elbow["axis"]), deg_to_rad(elbow["degrees"])), Vector3.ZERO)
	var turned := Transform3D(Basis.IDENTITY, rest.origin) * turn * Transform3D(Basis.IDENTITY, -rest.origin) * rest
	var local := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).affine_inverse() * turned
	skeleton.set_bone_pose_position(bone, local.origin)
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
	var bent := await _baked_vertices(species)
	var base_vertices: PackedVector3Array = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var grid := _skin_grid(reference["neutral_vertices"])
	var real: Array = elbow["vertices"]
	var total := 0.0
	var moved := 0
	worst = 0.0
	for i in bent.size():
		var skin_index := _find(grid, reference["neutral_vertices"], base_vertices[i])
		var mm := 1000.0 * bent[i].distance_to(_vector(real[skin_index])) if skin_index >= 0 else INF
		worst = maxf(worst, mm)
		total += mm
		if bent[i].distance_to(still[i]) > 0.05:
			moved += 1
	check("codo a %d°: malla = MPFB con el esqueleto de Blender (< %s mm)" % [elbow["degrees"], ELBOW_MM], worst < ELBOW_MM,
		"máximo %.4f mm, media %.4f mm (%d vértices; %d movidos más de 5 cm)" % [worst, total / bent.size(), bent.size(), moved])


func _angle(a: Basis, b: Basis) -> float:
	var q := (a.inverse() * b).orthonormalized().get_rotation_quaternion()
	return rad_to_deg(2.0 * acos(minf(1.0, absf(q.w))))


## Rejilla de 1 mm: {celda: [índices de la piel]}.
func _skin_grid(points: Array) -> Dictionary:
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


func _basis(columns: Array) -> Basis:
	return Basis(_vector(columns[0]), _vector(columns[1]), _vector(columns[2]))
