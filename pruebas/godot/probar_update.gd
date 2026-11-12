extends SceneTree
# Paso 3.9: CharacterUpdater (update_character): el orden, el estado completo y la pose al exportar. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_update.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|medida')
# «medida» = sin límite aprobado: no falla. Cuerpos al azar con semilla fija, todos los deslizadores y sin simetría.

const Compare := preload("comparar_glb.gd")

const SAME_MM := 0.001  # el del suelo del 3.6.3 (en las comparaciones de _same() se exige 0 exacto: son las mismas operaciones)
const DIFFERENT_MM := 1.0  # solo para comprobar que la prueba distingue lo distinto (no es un límite del código)
const COUNT := 3
const SEED := 39
const SOCKETS := ["socket_hand_r", "socket_hand_l", "socket_back", "socket_hip"]

var failures := 0
var species
var updater
var exporter: GDScript
var baker: GDScript
var bodies: Array[Dictionary] = []


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	exporter = load(addon.path_join("glb_exporter.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	updater = load(addon.path_join("character_updater.gd")).new(species)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in COUNT + 1:
		bodies.append(_random_body(rng))
	_check_rejected()
	_check_idempotent()
	_check_no_carry_over()
	_check_pose_back_to_rest()
	_check_export_pose()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _random_body(rng: RandomNumberGenerator) -> Dictionary:
	var values := {}
	for row: Dictionary in species.sliders:
		if row["tipo"] == "Por crear":
			continue
		for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
			values[row["id"] + side] = rng.randf()
	return values


## Todo lo que cambia update(): pose de cada hueso, reposo, bind poses y la malla horneada en CPU.
func _snapshot() -> Dictionary:
	var skeleton: Skeleton3D = species.skeleton
	var poses := []
	var rests := []
	for bone in skeleton.get_bone_count():
		poses.append(Transform3D(Basis(skeleton.get_bone_pose_rotation(bone)).scaled(skeleton.get_bone_pose_scale(bone)),
			skeleton.get_bone_pose_position(bone)))
		rests.append(skeleton.get_bone_rest(bone))
	var binds := []
	for bind in species.mesh.skin.get_bind_count():
		binds.append(species.mesh.skin.get_bind_pose(bind))
	return {"poses": poses, "rests": rests, "binds": binds, "vertices": baker.bake(species.mesh, skeleton)["vertices"]}


## Máximo y media de cada diferencia entre dos instantáneas: {pose_mm, pose_deg, rest_mm, bind_mm, vertex_mm}.
func _diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var result := {}
	for part: String in ["poses", "rests", "binds"]:
		var mm := []
		var deg := []
		for i in a[part].size():
			mm.append(1000.0 * a[part][i].origin.distance_to(b[part][i].origin))
			deg.append(Compare.angle(a[part][i].basis, b[part][i].basis))
		result[part.trim_suffix("s") + "_mm"] = Compare.stats(mm)
		result[part.trim_suffix("s") + "_deg"] = Compare.stats(deg)
	var vertices := []
	for i in a["vertices"].size():
		vertices.append(1000.0 * a["vertices"][i].distance_to(b["vertices"][i]))
	result["vertex_mm"] = Compare.stats(vertices)
	return result


func _same(label: String, a: Dictionary, b: Dictionary) -> void:
	var d := _diff(a, b)
	var worst: float = maxf(maxf(d["pose_mm"].x, d["rest_mm"].x), maxf(d["bind_mm"].x, d["vertex_mm"].x))
	check(label + " (posiciones y malla: 0 mm exactos)", worst == 0.0,
		"pose %.6f / %.6f mm, reposo %.6f, bind %.6f, malla %.6f / %.6f mm" % [d["pose_mm"].x, d["pose_mm"].y, d["rest_mm"].x,
		d["bind_mm"].x, d["vertex_mm"].x, d["vertex_mm"].y])
	print("  medida  %s, giros: pose máx. %.6f° / media %.6f°, reposo %.6f°, bind %.6f°" % [label, d["pose_deg"].x, d["pose_deg"].y,
		d["rest_deg"].x, d["bind_deg"].x])


func _different(label: String, a: Dictionary, b: Dictionary) -> void:
	var d := _diff(a, b)
	check(label + " (la prueba distingue: malla > %s mm)" % DIFFERENT_MM, d["vertex_mm"].x > DIFFERENT_MM, "%.2f mm" % d["vertex_mm"].x)


func _check_rejected() -> void:
	updater.update({"gender": 0.9}, false)
	var reference := _snapshot()
	var rejected: Array[String] = updater.update(
		{"gender": 0.9, "forma_futura": 0.5, "hand_size": 0.3, "height": NAN, "muscle": "alto", "weight": INF}, false)
	rejected.sort()
	check("claves no aplicadas, en una lista: desconocida, sin lado, NaN, texto e infinito", rejected == ["forma_futura", "hand_size", "height", "muscle", "weight"], str(rejected))
	_same("lo rechazado no cambia nada: igual que solo con 'gender'", _snapshot(), reference)
	check("todo bien aplicado: lista vacía", updater.update(bodies[0], false).is_empty())


func _check_idempotent() -> void:
	for pose_t: bool in [false, true]:
		for i in COUNT:
			updater.update(bodies[i], pose_t)
			var first := _snapshot()
			updater.update(bodies[i], pose_t)
			_same("cuerpo %d, pose %s: llamarla dos veces da lo mismo" % [i, "T" if pose_t else "A"], first, _snapshot())
	updater.update(bodies[0], false)
	var in_a := _snapshot()
	updater.update(bodies[0], true)
	_different("la pose T cambia el personaje (brazos)", in_a, _snapshot())


## El resultado no depende de la llamada anterior (otro cuerpo, o la otra pose).
func _check_no_carry_over() -> void:
	for pose_t: bool in [false, true]:
		var label := "pose %s: " % ("T" if pose_t else "A")
		updater.update(bodies[1], not pose_t)
		updater.update(bodies[2], pose_t)
		var after_other_pose := _snapshot()
		updater.update(bodies[3], pose_t)
		updater.update(bodies[2], pose_t)
		_same(label + "tras otra pose o tras otro cuerpo da lo mismo", after_other_pose, _snapshot())
		updater.update(bodies[1], pose_t)
		_different(label + "dos cuerpos distintos", after_other_pose, _snapshot())


func _check_pose_back_to_rest() -> void:
	updater.update(bodies[0], true)
	updater.update(bodies[0], false)
	var skeleton: Skeleton3D = species.skeleton
	var deg := []
	var mm := []
	for bone in skeleton.get_bone_count():
		deg.append(Compare.angle(Basis(skeleton.get_bone_pose_rotation(bone)), skeleton.get_bone_rest(bone).basis))
		mm.append(1000.0 * skeleton.get_bone_pose_position(bone).distance_to(skeleton.get_bone_rest(bone).origin))
	check("pose A tras la pose T: todos los huesos en su reposo (< %s mm)" % SAME_MM, Compare.stats(mm).x < SAME_MM,
		"posición máx. %.6f mm, giro máx. %.6f°" % [Compare.stats(mm).x, Compare.stats(deg).x])


## El exportador fija la pose de cada variante: sale igual con el editor en A, en T o con una pose cualquiera.
func _check_export_pose() -> void:
	for i in COUNT:
		for t_variant: bool in [true, false]:
			var label := "cuerpo %d, variante %s: " % [i, "T" if t_variant else "A"]
			updater.update(bodies[i], false)
			var reference := _export(t_variant)
			updater.update(bodies[i], true)
			var before := _snapshot()
			_same_export(label + "con el editor en T", reference, _export(t_variant))
			_same(label + "el editor queda como estaba", before, _snapshot())
			updater.update(bodies[i], false)
			_pose_by_hand()
			before = _snapshot()
			_same_export(label + "con el editor en una pose cualquiera (codos, columna y cabeza girados)", reference, _export(t_variant))
			_same(label + "el editor queda como estaba", before, _snapshot())
			reference["scene"].free()
	updater.update(bodies[0], false)
	var a := _export(true)
	updater.update(bodies[1], false)
	var b := _export(true)
	check("la prueba distingue dos cuerpos exportados (malla > %s mm)" % DIFFERENT_MM,
		Compare.stats(_vertex_distances(a, b)).x > DIFFERENT_MM)
	a["scene"].free()
	b["scene"].free()


func _pose_by_hand() -> void:
	var skeleton: Skeleton3D = species.skeleton
	for bone_name: String in ["LeftLowerArm", "RightLowerArm", "Spine", "Head"]:
		var bone := skeleton.find_bone(bone_name)
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, deg_to_rad(70.0)))


## {scene, skeleton, vertices} del personaje que sale del exportador (en memoria).
func _export(t_variant: bool) -> Dictionary:
	var scene: Node3D = exporter.build(species.mesh, species.skeleton, SOCKETS, t_variant)
	var skeleton := scene.get_child(0) as Skeleton3D
	var mesh := skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	return {"scene": scene, "skeleton": skeleton, "vertices": mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]}


func _vertex_distances(a: Dictionary, b: Dictionary) -> Array:
	var distances := []
	for i in a["vertices"].size():
		distances.append(1000.0 * a["vertices"][i].distance_to(b["vertices"][i]))
	return distances


## Compara un personaje exportado con la referencia (huesos y malla) y lo libera.
func _same_export(label: String, reference: Dictionary, other: Dictionary) -> void:
	var bones: Dictionary = Compare.bone_errors(other["skeleton"], reference["skeleton"])
	var mesh := Compare.stats(_vertex_distances(reference, other))
	check(label + ": 53 huesos y malla iguales (< %s mm)" % SAME_MM,
		bones["count"] == 53 and Compare.stats(bones["mm"]).x < SAME_MM and mesh.x < SAME_MM,
		"huesos máx. %.6f mm / media %.6f, malla máx. %.6f mm / media %.6f" % [Compare.stats(bones["mm"]).x,
		Compare.stats(bones["mm"]).y, mesh.x, mesh.y])
	print("  medida  %s, giro de huesos: máx. %.6f°" % [label, Compare.stats(bones["deg"]).x])
	other["scene"].free()
