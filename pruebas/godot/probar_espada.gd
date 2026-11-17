extends SceneTree
# Paso 5.6: una espada de prueba (godot/app/test_sword.gd) en socket_hand_r del personaje exportado, durante «Atacar».
# Sin ventana. Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_espada.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# La espada no debe cambiar de tamaño aunque la mano sea grande o pequeña, y debe seguir a la mano.
# Que detecta el fallo: la última comprobación cuelga la espada del maniquí VIVO con hand_size_r = 1 y mide que ahí la
# escala NO es 1: el mismo cálculo que da 1 en el exportado ve la escala de la mano.

const SCALE_EPS := 0.001  # PROVISIONAL (D26)
const FOLLOW_MM := 0.1  # PROVISIONAL (D26)
const MIN_TRAVEL := 0.30  # m; PROVISIONAL (D26)
const STEPS := 10

var failures := 0
var sword_script: GDScript
var exporter: GDScript
var retarget_script: GDScript
var species
var updater
var animations


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	sword_script = load(root_dir.path_join("godot/app/test_sword.gd"))
	exporter = load(addon.path_join("glb_exporter.gd"))
	retarget_script = load(addon.path_join("pose_retarget.gd"))
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
	for hand: float in [0.0, 0.5, 1.0]:
		await _check_hand(hand)
	await _check_live()
	animations.scene.free()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _hand(skeleton: Skeleton3D) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))


func _check_hand(hand: float) -> void:
	updater.update({"hand_size_r": hand}, false)
	var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)
	root.add_child(character)
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var sword: Node3D = sword_script.add(character)
	await process_frame
	var label := "mano %.1f" % hand
	var scale := sword.global_transform.basis.get_scale()
	var off := (scale - Vector3.ONE).abs()
	check("%s: la espada tiene escala 1 (± %s)" % [label, SCALE_EPS], maxf(off.x, maxf(off.y, off.z)) < SCALE_EPS, str(scale))

	var retarget = retarget_script.new(animations.skeleton, skeleton, animations.bones, animations.hips)
	retarget.capture()
	animations.play("atacar")
	var first := Vector3.INF
	var drift := 0.0
	var low := Vector3.INF
	var high := -Vector3.INF
	for step in STEPS:
		animations.seek(animations.length() * float(step) / STEPS)
		retarget.apply()
		await process_frame
		var local := _hand(skeleton).affine_inverse() * sword.global_position
		if first == Vector3.INF:
			first = local
		drift = maxf(drift, 1000.0 * local.distance_to(first))
		var tip: Vector3 = sword.global_transform * sword_script.tip()
		low = low.min(tip)
		high = high.max(tip)
	check("%s: la espada sigue a la mano en «Atacar» (< %s mm)" % [label, FOLLOW_MM], drift < FOLLOW_MM, "%.5f mm" % drift)
	var travel := (high - low).length()
	check("%s: la punta recorre más de %s m" % [label, MIN_TRAVEL], travel > MIN_TRAVEL, "%.2f m" % travel)

	animations.play("reposo")
	var lowest := INF
	for step in STEPS:
		animations.seek(animations.length() * float(step) / STEPS)
		retarget.apply()
		await process_frame
		lowest = minf(lowest, (sword.global_transform * sword_script.tip()).y)
	check("%s: en «Reposo» la punta no baja del suelo" % label, lowest >= 0.0, "y mínima %.3f m" % lowest)

	if hand == 0.0:
		check("con un anclaje que no existe devuelve null", sword_script.add(character, "socket_nada") == null)
		var made := 0
		for socket: String in species.manifest["bones"]["sockets"]:
			if sword_script.add(character, socket) != null:
				made += 1
		check("los 4 anclajes aceptan la espada", made == 4, str(made))
	character.free()


## El maniquí vivo lleva la escala de Proporción en la mano: ahí la espada crece (por eso se prueba el exportado).
func _check_live() -> void:
	updater.update({"hand_size_r": 1.0}, false)
	var holder := BoneAttachment3D.new()
	holder.bone_name = "socket_hand_r"
	species.skeleton.add_child(holder)
	var node := Node3D.new()
	node.name = "socket_hand_r_vivo"
	holder.add_child(node)
	var sword: Node3D = sword_script.add(holder, "socket_hand_r_vivo")
	await process_frame
	var scale := sword.global_transform.basis.get_scale().x
	print("  MEDIDA escala de la espada en el maniquí vivo con la mano a 1: %.3f" % scale)
	check("en el vivo la escala no es 1 (la prueba distingue)", absf(scale - 1.0) > 10 * SCALE_EPS, "%.3f" % scale)
	holder.free()
