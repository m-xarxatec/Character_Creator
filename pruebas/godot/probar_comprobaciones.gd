extends SceneTree
# Paso 5.3: comprobaciones automáticas del personaje horneado (character_checks.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_comprobaciones.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Cuerpos sanos (neutro, preset anime, todo a 0 y todo a 1; pose T y pose A): todo «bien» (presupuesto: bien o aviso).
# Cinco roturas, cada una con su error. Al renombrar LeftHand también falla `anclajes`: socket_hand_l cuelga de un
# hueso que ya no existe, y eso es un error de verdad.
# Que detecta el fallo: en character_checks.gd, WEIGHT_SUM_EPS := 1.0 -> falla «roto 1».

var failures := 0
var checks: GDScript
var exporter: GDScript
var preset_script: GDScript
var species
var updater
var sockets: Array


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	checks = load(addon.path_join("character_checks.gd"))
	exporter = load(addon.path_join("glb_exporter.gd"))
	preset_script = load(addon.path_join("preset.gd"))
	if not checks.can_instantiate():
		print("ERROR: character_checks.gd no compila")
		quit(1)
		return
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	updater = load(addon.path_join("character_updater.gd")).new(species)
	sockets = species.manifest["bones"]["sockets"]
	_check_healthy()
	_check_broken()
	_report_missing_profile_bones()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _bodies() -> Dictionary:
	var preset: Dictionary = preset_script.from_text(species.preset_text(), "humana", species.sliders)
	var zero := {}
	var one := {}
	for row: Dictionary in species.sliders:
		if row["tipo"] == "Por crear":
			continue
		for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
			zero[row["id"] + side] = 0.0
			one[row["id"] + side] = 1.0
	return {"neutro": {}, "anime": preset["valores"], "todo a 0": zero, "todo a 1": one}


func _errors(results: Array[Dictionary]) -> Dictionary:
	var found := {}
	for result in results:
		if result["nivel"] == "error":
			found[result["id"]] = result["huesos"]
	return found


func _check_healthy() -> void:
	var bodies := _bodies()
	for body: String in bodies:
		updater.update(bodies[body], false)
		for t_pose: bool in [true, false]:
			var character: Node3D = exporter.build(species.mesh, species.skeleton, sockets, t_pose)
			var start := Time.get_ticks_usec()
			var results: Array[Dictionary] = checks.run(character, species.manifest)
			var ms := (Time.get_ticks_usec() - start) / 1000.0
			var bad := []
			var budget := ""
			for result in results:
				if result["id"] == "presupuesto":
					budget = result["texto"]
				elif result["nivel"] != "bien":
					bad.append("%s: %s" % [result["id"], result["texto"]])
			check("%s, pose %s: todo bien" % [body, "T" if t_pose else "A"], bad.is_empty() and results.size() == 8, str(bad))
			print("  MEDIDA comprobaciones (%s, %s): %.1f ms; %s" % [body, "T" if t_pose else "A", ms, budget])
			character.free()
	check("worst: el peor nivel de la lista", checks.worst([{"nivel": "bien"}, {"nivel": "aviso"}]) == "aviso"
		and checks.worst([{"nivel": "error"}, {"nivel": "aviso"}]) == "error" and checks.worst([]) == "bien")


func _neutral() -> Node3D:
	updater.update({}, false)
	return exporter.build(species.mesh, species.skeleton, sockets, true)


func _check_broken() -> void:
	# Roto 1: un peso a 0 en un vértice con dos huesos o más
	var character := _neutral()
	var mesh_node: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var vertex := 0
	while weights[4 * vertex + 1] <= 0.05:
		vertex += 1
	var other := skeleton.get_bone_name(mesh_node.skin.get_bind_bone(bones[4 * vertex + 1]))
	weights[4 * vertex] = 0.0
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var material := mesh_node.mesh.surface_get_material(0)
	var broken := ArrayMesh.new()
	broken.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	broken.surface_set_material(0, material)
	mesh_node.mesh = broken
	var found := _errors(checks.run(character, species.manifest))
	check("roto 1 (un peso a 0): solo pesos_suman_1, y nombra %s" % other,
		found.keys() == ["pesos_suman_1"] and other in found["pesos_suman_1"], str(found))
	character.free()

	# Roto 2: LeftHand pasa a llamarse Mano
	character = _neutral()
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.set_bone_name(skeleton.find_bone("LeftHand"), "Mano")
	found = _errors(checks.run(character, species.manifest))
	var keys := found.keys()
	keys.sort()
	check("roto 2 (LeftHand → Mano): perfil y manifiesto nombran Mano; anclajes, socket_hand_l",
		keys == ["anclajes", "huesos_del_manifiesto", "huesos_del_perfil"] and "Mano" in found["huesos_del_perfil"]
		and "Mano" in found["huesos_del_manifiesto"] and "LeftHand" in found["huesos_del_manifiesto"], str(found))
	character.free()

	# Roto 3: escala 1,1 en la pose de Head
	character = _neutral()
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.set_bone_pose_scale(skeleton.find_bone("Head"), Vector3.ONE * 1.1)
	found = _errors(checks.run(character, species.manifest))
	check("roto 3 (Head a escala 1,1): solo escala_1, y nombra Head",
		found.keys() == ["escala_1"] and found["escala_1"] == PackedStringArray(["Head"]), str(found))
	character.free()

	# Roto 4: sin socket_back_attachment
	character = _neutral()
	character.find_child("socket_back_attachment", true, false).free()
	found = _errors(checks.run(character, species.manifest))
	check("roto 4 (sin socket_back_attachment): solo anclajes", found.keys() == ["anclajes"], str(found))
	character.free()

	# Roto 5: el personaje vivo, con formas
	updater.update({}, false)
	found = _errors(checks.run(species.scene, species.manifest))
	check("roto 5 (personaje vivo): sin_formas da error", found.has("sin_formas"), str(found.keys()))


func _report_missing_profile_bones() -> void:
	var profile := SkeletonProfileHumanoid.new()
	var missing := PackedStringArray()
	for i in profile.bone_size:
		if not profile.get_bone_name(i) in species.manifest["bones"]["deform"]:
			missing.append(profile.get_bone_name(i))
	print("  MEDIDA huesos del perfil que no tiene el personaje: ", ", ".join(missing))
