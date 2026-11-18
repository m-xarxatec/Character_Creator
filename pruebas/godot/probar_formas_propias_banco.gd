extends SceneTree
# Paso 6.3: las formas propias (6.1) al animar. Ocho cuerpos (neutro; shoulder_height, buttocks_height y
# buttocks_roundness a 0 y a 1; y los tres a 1 con músculo y grasa a 1), horneados en T y puestos en las poses fijas
# del 5.2 y en los extremos del rango de movimiento (5.9) que tocan su zona. Compara cada medida del 5.10 con la de su
# referencia en la misma pose: el neutro, o «músculo y grasa» para «todo» (así se mide el efecto de las formas, no el
# de las macros). Exporta cada cuerpo a <salida>/<cuerpo>.glb para pasarle probar_glb.gd. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 900 godot --headless --path pruebas/godot -s probar_formas_propias_banco.gd -- [--salida=<carpeta>] 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
#      después: godot --headless --path pruebas/godot -s probar_glb.gd -- <salida>
# Que detecta el fallo: --romper pone la forma shoulder_height_incr a 3 en el cuerpo «shoulder_height 1» saltándose el
# recorte del deslizador -> las medidas se disparan.

const SECTION_POINTS := 5.0  # PROVISIONAL: lo que puede empeorar la pérdida de sección respecto al neutro
const STRETCH_RATIO := 1.25  # PROVISIONAL
const HAND_MM := 1.0
const SHOULDER_MOVES := ["hombro_arriba", "hombro_delante", "hombro_torsion"]
const HIP_MOVES := ["cadera_delante", "cadera_lado", "rodilla"]
const BODIES := {
	"neutro": {},
	"shoulder_height 0": {"shoulder_height": 0.0}, "shoulder_height 1": {"shoulder_height": 1.0},
	"buttocks_height 0": {"buttocks_height": 0.0}, "buttocks_height 1": {"buttocks_height": 1.0},
	"buttocks_roundness 0": {"buttocks_roundness": 0.0}, "buttocks_roundness 1": {"buttocks_roundness": 1.0},
	"músculo y grasa": {"muscle": 1.0, "weight": 1.0},
	"todo": {"shoulder_height": 1.0, "buttocks_height": 1.0, "buttocks_roundness": 1.0, "muscle": 1.0, "weight": 1.0},
}
const REFERENCES := ["neutro", "músculo y grasa"]
## Cruces nuevos justificados uno a uno (ficha 6.3 §6), con su medida del 2026-11-18. Los ve el responsable.
const JUSTIFIED := {
	"shoulder_height 0 hombro_delante@hasta": "las manos ya se cruzan en esa pose en el neutro (50 mm, igual que aquí); solo cambian los dedos",
	"buttocks_roundness 1 sentadilla": "contacto muslo-pecho al agacharse con glúteo más redondo: 10 mm (neutro 7), en el aviso, lejos del error (30)",
}

var failures := 0
var options := {}
var species
var updater
var animations
var rom
var exporter: GDScript
var static_pose: GDScript
var mesh_checks: GDScript
var character_checks: GDScript
var reference := {}  # cuerpo de referencia -> pose -> {medida: resultado peor}


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var addon := root_dir.path_join("godot/addons/creador")
	exporter = load(addon.path_join("glb_exporter.gd"))
	static_pose = load(addon.path_join("static_pose.gd"))
	mesh_checks = load(addon.path_join("mesh_checks.gd"))
	character_checks = load(addon.path_join("character_checks.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	animations = load(addon.path_join("animation_set.gd")).new()
	rom = load(root_dir.path_join("godot/app/rom.gd")).new()
	var error: String = species.load_folder(root_dir.path_join("godot/datos/humana"))
	error = error if error else animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	error = error if error else rom.load_file(root_dir.path_join("godot/datos/animaciones/rom.json"))
	if error:
		print("ERROR: ", error)
		quit(1)
		return
	root.add_child(species.scene)
	updater = load(addon.path_join("character_updater.gd")).new(species)
	var out: String = options.get("salida", "pruebas/fase_6/salida/banco")
	out = out if out.is_absolute_path() else root_dir.path_join(out).simplify_path()
	DirAccess.make_dir_recursive_absolute(out)
	var hand_height := {}
	for body: String in BODIES:
		updater.update(BODIES[body], false)
		if options.has("romper") and body == "shoulder_height 1":
			species.mesh.set_blend_shape_value(species.mesh.find_blend_shape_by_name("shoulder_height_incr"), 3.0)
		var file := out.path_join(body.replace(" ", "_") + ".glb")
		check("%s: se exporta" % body, exporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"],
			file, true) == OK)
		var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)
		root.add_child(character)
		await process_frame
		_check_character(body, character)
		var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
		var mesh: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
		for pose: String in _poses(body):
			skeleton.reset_bone_poses()
			static_pose.apply(skeleton, _turns(pose), animations.hips, [])
			_compare(body, pose, _worst(mesh_checks.run(mesh, skeleton)))
			if pose == "brazos_arriba":
				hand_height[body] = _origin(skeleton, "RightHand").y - _origin(skeleton, "RightUpperArm").y
		character.free()
	for body: String in ["shoulder_height 0", "shoulder_height 1"]:
		var mm: float = 1000.0 * absf(hand_height[body] - hand_height["neutro"])
		check("%s: en «Brazos arriba» la mano queda igual de alta sobre el hombro que en el neutro (< %s mm)" % [body, HAND_MM],
			mm < HAND_MM, "%.4f mm" % mm)
	print("GUARDADO ", out)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _origin(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


## Poses fijas del 5.2 y extremos del 5.9 («<movimiento>@desde» o «@hasta») que tocan la zona del cuerpo.
func _poses(body: String) -> Array:
	var list: Array = animations.poses.map(func(pose: Dictionary) -> String: return pose["id"])
	var moves: Array = []
	if body in REFERENCES or body == "todo" or body.begins_with("shoulder"):
		moves.append_array(SHOULDER_MOVES)
	if body in REFERENCES or body == "todo" or body.begins_with("buttocks"):
		moves.append_array(HIP_MOVES)
	for move: String in moves:
		list.append_array([move + "@desde", move + "@hasta"])
	return list


func _turns(pose: String) -> Dictionary:
	if not "@" in pose:
		return animations.pose_turns(pose)
	var parts := pose.split("@")
	return rom.turns(parts[0], 0.25 if parts[1] == "desde" else 0.75)


func _worst(results: Array[Dictionary]) -> Dictionary:
	var worst := {}
	for result in results:
		if not worst.has(result["id"]) or result["valor"] > worst[result["id"]]["valor"]:
			worst[result["id"]] = result
	worst["pares"] = PackedStringArray()
	for result in results:  # pares de huesos que se cruzan por encima del aviso
		if result["id"] == "cruce" and result["valor"] >= mesh_checks.LIMITS["cruce"][0]:
			worst["pares"].append(",".join(result["huesos"]))
	return worst


func _check_character(body: String, character: Node3D) -> void:
	var bad := []
	for result: Dictionary in character_checks.run(character, species.manifest):
		if result["nivel"] != "bien":
			bad.append("%s: %s" % [result["id"], result["texto"]])
	check("%s: comprobaciones del personaje, todo bien" % body, bad.is_empty(), str(bad))


func _compare(body: String, pose: String, worst: Dictionary) -> void:
	var section: float = worst["seccion"]["valor"]
	var stretch: float = worst["estiramiento"]["valor"]
	print("  MEDIDA %s %s: sección %.1f %% (%s), estiramiento ×%.2f, cruce %.0f mm, degenerados %d" % [body, pose, section,
		",".join(worst["seccion"]["huesos"]), stretch, worst["cruce"]["valor"], worst["degenerados"]["valor"]])
	if body in REFERENCES:
		reference.get_or_add(body, {})[pose] = worst
		return
	var base: Dictionary = reference["músculo y grasa" if body == "todo" else "neutro"][pose]
	check("%s %s: la sección no empeora más de %s puntos" % [body, pose, SECTION_POINTS],
		section - base["seccion"]["valor"] <= SECTION_POINTS, "%+.1f" % (section - base["seccion"]["valor"]))
	var ratio: float = stretch / maxf(base["estiramiento"]["valor"], 1e-6)
	check("%s %s: estiramiento < ×%s el del neutro" % [body, pose, STRETCH_RATIO], ratio < STRETCH_RATIO, "×%.3f" % ratio)
	check("%s %s: sin degenerados nuevos" % [body, pose], worst["degenerados"]["valor"] <= base["degenerados"]["valor"],
		"%d (neutro %d)" % [worst["degenerados"]["valor"], base["degenerados"]["valor"]])
	var new_pairs := []
	for pair: String in worst["pares"]:
		if not pair in base["pares"]:
			new_pairs.append(pair)
	var key := "%s %s" % [body, pose]
	if not new_pairs.is_empty() and JUSTIFIED.has(key):
		print("  MEDIDA %s: cruces nuevos justificados (%s): %s" % [key, JUSTIFIED[key], new_pairs])
		return
	check("%s: sin cruces nuevos" % key, new_pairs.is_empty(), str(new_pairs))
