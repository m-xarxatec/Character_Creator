extends SceneTree
# Paso 5.10: medidas de deformación de la malla (mesh_checks.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_medidas_malla.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# 1) Casos construidos con resultado conocido. 2) Personaje horneado (pose T) en reposo: nada avisa.
# 3) Neutro y todo a 1, variantes T y A, en las poses del 5.2, codo a 90° y «Sentarse» (mitad del clip): solo MEDIDA, para proponer
#    los umbrales de MeshChecks.LIMITS (PROVISIONALES hasta que el responsable los apruebe).
# Que detecta el fallo: en section_loss, dividir al revés (r_rest / r_posed) -> falla «anillo de 5 a 4 cm».

const ELBOWS := {"LeftLowerArm": [0, -90, 0], "RightLowerArm": [0, 90, 0]}  # T: el antebrazo gira hacia delante

var failures := 0
var mesh_checks: GDScript
var exporter: GDScript
var static_pose: GDScript
var retarget_script: GDScript
var species
var updater
var animations


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	mesh_checks = load(addon.path_join("mesh_checks.gd"))
	if not mesh_checks.can_instantiate():
		print("ERROR: mesh_checks.gd no compila")
		quit(1)
		return
	exporter = load(addon.path_join("glb_exporter.gd"))
	static_pose = load(addon.path_join("static_pose.gd"))
	retarget_script = load(addon.path_join("pose_retarget.gd"))
	_check_built_cases()
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	updater = load(addon.path_join("character_updater.gd")).new(species)
	animations = load(addon.path_join("animation_set.gd")).new()
	var error: String = animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	if error:
		print("ERROR: ", error)
		quit(1)
		return
	root.add_child(animations.scene)
	await process_frame
	var one := {}
	for row: Dictionary in species.sliders:
		if row["tipo"] != "Por crear":
			for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
				one[row["id"] + side] = 1.0
	for body: String in ["neutro", "todo a 1"]:
		updater.update({} if body == "neutro" else one, false)
		for t_pose: bool in [true, false]:  # variante T horneada y A (las poses parten de su reposo, sin corrección)
			var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], t_pose)
			root.add_child(character)
			await process_frame
			_measure_body("%s, %s" % [body, "T" if t_pose else "A"], character)
			character.free()
	animations.scene.free()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _ring(radius: float, turn: Basis, shift: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(turn * Vector3(cos(angle) * radius, 0.0, sin(angle) * radius) + shift)
	return points


func _check_built_cases() -> void:
	var ring := PackedInt32Array(range(16))
	var rest := _ring(0.05, Basis.IDENTITY, Vector3.ZERO)
	var loss: float = mesh_checks.section_loss(rest, _ring(0.04, Basis.IDENTITY, Vector3.ZERO), ring, Vector3.ZERO, Vector3.ZERO)
	check("sección: anillo de 5 a 4 cm pierde un 20 % (± 0,01)", absf(loss - 20.0) < 0.01, "%.4f" % loss)
	var turn := Basis(Vector3(1, 2, 3).normalized(), 0.8)
	var shift := Vector3(0.3, -0.2, 1.0)
	loss = mesh_checks.section_loss(rest, _ring(0.05, turn, shift), ring, Vector3.ZERO, shift)
	check("sección: el mismo anillo movido y girado pierde 0 % (± 0,01)", absf(loss) < 0.01, "%.4f" % loss)

	var a := {"a": Vector3(0, 0, 0), "b": Vector3(0, 1, 0), "r": 0.03}
	var far := {"a": Vector3(0.1, 0, 0), "b": Vector3(0.1, 1, 0), "r": 0.03}
	var near := {"a": Vector3(0.04, 0, 0), "b": Vector3(0.04, 1, 0), "r": 0.03}
	var apart: float = mesh_checks.capsule_overlap(a, far)
	var touching: float = mesh_checks.capsule_overlap(a, near)
	check("cruce: cápsulas de 3 cm a 10 cm no se tocan; a 4 cm se solapan 2 cm (± 0,01 mm)",
		apart == 0.0 and absf(touching - 0.02) < 0.00001, "%.6f m, %.6f m" % [apart, touching])

	var triangle := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.01, 0, 0), Vector3(0, 0.01, 0)])
	var stretched := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.03, 0, 0), Vector3(0, 0.01, 0)])
	var indices := PackedInt32Array([0, 1, 2])
	var factor: float = mesh_checks.stretch(triangle, stretched, indices)
	check("estiramiento: un lado de 1 a 3 cm da 3 (± 0,001)", absf(factor - 3.0) < 0.001, "%.5f" % factor)
	var flat := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.01, 0, 0), Vector3(0.02, 0, 0)])
	check("degenerados: un triángulo con los 3 vértices en línea cuenta 1",
		mesh_checks.degenerate_count(triangle, flat, indices) == 1 and mesh_checks.degenerate_count(triangle, triangle, indices) == 0)


func _measure_body(body: String, character: Node3D) -> void:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
	var start := Time.get_ticks_msec()
	var results: Array[Dictionary] = mesh_checks.run(mesh, skeleton)
	var ms := Time.get_ticks_msec() - start
	var bad := results.filter(func(r: Dictionary) -> bool: return r["nivel"] != "bien")
	check("%s en reposo: nada avisa" % body, bad.is_empty(), str(bad))
	print("  MEDIDA medidas de malla (%s): %d ms" % [body, ms])
	var retarget = retarget_script.new(animations.skeleton, skeleton, animations.bones, animations.hips)
	retarget.capture()
	for pose: String in ["brazos_arriba", "sentadilla", "giro_tronco", "codo_90", "sentarse"]:
		skeleton.reset_bone_poses()
		if pose == "sentarse":
			animations.play("sentarse")
			animations.seek(animations.length() * 0.5)
			retarget.apply()
		else:
			var turns: Dictionary = ELBOWS if pose == "codo_90" else animations.pose_turns(pose)
			static_pose.apply(skeleton, turns, animations.hips, animations.feet)
		_print_worst(body, pose, mesh_checks.run(mesh, skeleton))
	skeleton.reset_bone_poses()


## Por cada medida, el peor valor y su texto.
func _print_worst(body: String, pose: String, results: Array[Dictionary]) -> void:
	var worst := {}
	var counts := {}
	for result in results:
		var id: String = result["id"]
		if result["nivel"] != "bien":
			counts[id] = counts.get(id, 0) + 1
		if not worst.has(id) or result["valor"] > worst[id]["valor"]:
			worst[id] = result
	for id: String in worst:
		print("  MEDIDA %s, %s, %s: %.2f (%s) [%s; %d sobre el aviso]" % [body, pose, id, worst[id]["valor"], worst[id]["texto"],
			worst[id]["nivel"], counts.get(id, 0)])
