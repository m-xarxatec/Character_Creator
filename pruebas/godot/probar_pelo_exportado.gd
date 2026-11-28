extends SceneTree
# Paso PE.5c (ficha ruta/pasos/PE.5_exportar_pelo.md): HairScene. Con bob02 y long01 (normal y Cabeza ×2,5) exporta en
# pose T con GlbExporter + HairScene a pruebas/godot/salida/pelo_exportado/ y comprueba la .tscn: hereda del .glb por
# ruta relativa, el simulador cuelga del esqueleto con una entrada por cadena y los choques del editor, todos con hueso.
# Luego la carga (con el .glb leído de vuelta y guardado como .tscn: la copia cambia la ruta) y mide como PE.4: quieto,
# la punta se queda atrás al girar la cabeza y vuelve, y no entra en los choques. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_pelo_exportado.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en HairScene.measure, no llamar a `_to_curves` -> falla «quieto» (227 mm); no pasar las «escalas»
# -> falla «el radio menor de las articulaciones crece con la cabeza» (Cabeza ×2,5).

const STILL_MM := 2.0  # los de probar_fisica_pelo (PE.4, aprobados)
const LAG_MM := 10.0
const SINK_MM := 5.0  # × Cabeza › Tamaño del editor
const RADIUS := 0.005  # HairPhysics.DEFAULTS["radio"]
const DT := 1.0 / 60.0
const STILL_FRAMES := 120
const TURN_FRAMES := 30
const SETTLE_FRAMES := 180
const TURN_DEG := 30.0
const HAIRS := ["bob02", "long01"]
const VARIANTS := {"normal": {}, "cabeza ×2,5": {"head_size": 1.0}}
const OUTPUT := "res://salida/pelo_exportado/"
var failures := 0
var root_dir: String
var addon: String
var library


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	addon = root_dir.path_join("godot/addons/creador")
	library = load(addon.path_join("pack_library.gd")).new()
	library.scan(PackedStringArray([root_dir.path_join("godot/packs")]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await process_frame
	for id: String in HAIRS:
		for label: String in VARIANTS:
			await _check(id, label)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Exporta con el peinado y comprueba la .tscn escrita y la cargada.
func _check(id: String, label: String) -> void:
	var species = load(addon.path_join("species_data.gd")).new()
	species.load_folder(root_dir.path_join("godot/datos/humana"))
	root.add_child(species.scene)
	var skeleton: Skeleton3D = species.skeleton
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	var pieces: GDScript = load(addon.path_join("body_piece.gd"))
	var mesh: MeshInstance3D = pieces.attach(library.load_piece("makehuman", id), skeleton)
	pieces.follow(mesh, species.mesh)
	updater.pieces.append(mesh)
	updater.update(VARIANTS[label], false)
	var chains: Array[PackedStringArray] = load(addon.path_join("hair_chains.gd")).build(mesh, skeleton)
	var simulator: SpringBoneSimulator3D = load(addon.path_join("hair_physics.gd")).attach(skeleton, chains, species.mesh)
	var head_scale := skeleton.get_bone_global_pose(skeleton.find_bone("Head")).basis.get_scale().x
	var scene_script: GDScript = load(addon.path_join("hair_scene.gd"))
	var exporter: GDScript = load(addon.path_join("glb_exporter.gd"))
	var hair: Dictionary = scene_script.read(simulator)
	var shapes := _shapes(simulator)
	var job: Dictionary = exporter.prepare(species.mesh, skeleton, species.manifest["bones"]["sockets"], true, [mesh])
	exporter.compute(job)
	var character: Node3D = exporter.finish(job)
	var skeleton_path := "Armature/" + String(character.find_children("*", "Skeleton3D", true, false)[0].name)
	var copied: SpringBoneSimulator3D = scene_script.measure(hair, character)
	var name := "%s_%s" % [id, "cabeza" if VARIANTS[label] else "normal"]
	var glb := ProjectSettings.globalize_path(OUTPUT + name + ".glb")
	var written: bool = exporter.write(character, job["toon"], glb) == OK and scene_script.save(copied, glb, skeleton_path) == OK
	copied.free()
	species.scene.free()
	var tag := "%s, %s" % [id, label]
	var text := FileAccess.get_file_as_string(glb.get_basename() + ".tscn")
	check("%s: deja el .glb y la .tscn" % tag, written and text != "")
	check("%s: la .tscn hereda del .glb por ruta relativa" % tag, ("path=\"%s.glb\"" % name) in text
		and not "res://" in text and not "\\" in text and "instance=ExtResource(\"1_glb\")" in text)
	await _check_loaded(tag, name, skeleton_path, chains.size(), shapes, head_scale)


## Nombres de los choques que no son tiras (las tiras se vuelven a medir).
func _shapes(simulator: SpringBoneSimulator3D) -> Array:
	return simulator.get_children().filter(func(n: Node) -> bool: return not n.name.begins_with("Tira")).map(
		func(n: Node) -> String: return n.name)


## Lee el .glb, lo guarda como .tscn, carga una copia de la del pelo que apunta a él y mide la física.
func _check_loaded(tag: String, name: String, skeleton_path: String, chain_count: int, shapes: Array, head_scale: float) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_file(ProjectSettings.globalize_path(OUTPUT + name + ".glb"), state)
	var glb_scene := document.generate_scene(state)
	for node in glb_scene.find_children("*", "", true, false):
		node.owner = glb_scene
	var packed := PackedScene.new()
	packed.pack(glb_scene)
	ResourceSaver.save(packed, OUTPUT + name + "_glb.tscn")
	glb_scene.free()
	var text := FileAccess.get_file_as_string(OUTPUT + name + ".tscn").replace(name + ".glb", name + "_glb.tscn")
	var file := FileAccess.open(OUTPUT + name + "_prueba.tscn", FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var loaded: PackedScene = ResourceLoader.load(OUTPUT + name + "_prueba.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	var instance: Node3D = loaded.instantiate() if loaded else null
	var skeleton: Skeleton3D = instance.get_node_or_null(skeleton_path) if instance else null
	var simulator: SpringBoneSimulator3D = skeleton.get_node_or_null("FisicaPelo") if skeleton else null
	check("%s: carga y el simulador cuelga de %s" % [tag, skeleton_path], simulator != null)
	if simulator == null:
		if instance:
			instance.free()
		return
	var bones_ok := simulator.get_children().all(func(s: Node) -> bool: return skeleton.find_bone(s.bone_name) >= 0)
	check("%s: una entrada por cadena y los choques del editor, con hueso" % tag, simulator.setting_count == chain_count
		and _shapes(simulator) == shapes and bones_ok, "%d entradas, %s" % [simulator.setting_count, _shapes(simulator)])
	root.add_child(instance)
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	await process_frame  # Godot rehace las articulaciones
	var smallest: float = Array(_radii(simulator)).min()  # HairPhysics: radio 5 mm × Cabeza (con las escalas del editor)
	check("%s: el radio menor de las articulaciones crece con la cabeza" % tag, smallest >= RADIUS * head_scale - 0.0001,
		"%.2f mm" % (smallest * 1000))
	await _run(tag, skeleton, simulator, head_scale)
	instance.free()


## Radio de cada articulación, cadena tras cadena.
func _radii(simulator: SpringBoneSimulator3D) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in simulator.setting_count:
		for j in simulator.get_joint_count(i):
			out.append(simulator.get_joint_radius(i, j))
	return out


## Quieto, giro de la cabeza y vuelta (como probar_fisica_pelo).
func _run(tag: String, skeleton: Skeleton3D, simulator: SpringBoneSimulator3D, head_scale: float) -> void:
	var bones := PackedInt32Array()
	var tips := PackedInt32Array()
	for i in simulator.setting_count:
		for j in simulator.get_joint_count(i):
			bones.append(simulator.get_joint_bone(i, j))
		tips.append(simulator.get_joint_bone(i, simulator.get_joint_count(i) - 1))
	var head := skeleton.find_bone("Head")
	var neck := skeleton.find_bone("Neck")
	var neck_rotation := skeleton.get_bone_pose_rotation(neck)
	var start := {}
	for bone in bones:
		start[bone] = skeleton.get_bone_global_pose(bone).origin
	var head_start := skeleton.get_bone_global_pose(head)
	var seen := {"still": 0.0, "lag": 0.0, "sink": -INF}
	var measure := [false]
	var on_update := func() -> void:
		var carry := skeleton.get_bone_global_pose(head) * head_start.affine_inverse()
		var worst := 0.0
		for bone in bones:
			var now := skeleton.get_bone_global_pose(bone).origin
			worst = maxf(worst, now.distance_to(carry * start[bone]))
			seen["sink"] = maxf(seen["sink"], _sink(simulator, now))
		seen["still"] = worst
		if measure[0]:
			for tip in tips:
				seen["lag"] = maxf(seen["lag"], skeleton.get_bone_global_pose(tip).origin.distance_to(carry * start[tip]))
	skeleton.skeleton_updated.connect(on_update)
	for f in STILL_FRAMES:
		await _step(skeleton)
	var still: float = seen["still"]
	measure[0] = true
	for f in TURN_FRAMES:
		skeleton.set_bone_pose_rotation(neck, Quaternion(Vector3.UP, deg_to_rad(TURN_DEG) * sin(PI * (f + 1) / TURN_FRAMES)) * neck_rotation)
		await _step(skeleton)
	skeleton.set_bone_pose_rotation(neck, neck_rotation)
	measure[0] = false
	for f in SETTLE_FRAMES:
		await _step(skeleton)
	skeleton.skeleton_updated.disconnect(on_update)
	var back: float = seen["still"]
	var limit := SINK_MM * head_scale
	print("  MEDIDA %s: quieto %.2f mm, retraso de la punta %.1f mm, tras volver %.2f mm, entra %.1f mm (límite %.1f)"
		% [tag, still * 1000, seen["lag"] * 1000, back * 1000, seen["sink"] * 1000, limit])
	check("%s: quieto no se mueve" % tag, still * 1000 <= STILL_MM, "%.2f mm" % (still * 1000))
	check("%s: al girar la cabeza se queda atrás" % tag, seen["lag"] * 1000 >= LAG_MM, "%.1f mm" % (seen["lag"] * 1000))
	check("%s: vuelve" % tag, back * 1000 <= STILL_MM, "%.2f mm" % (back * 1000))
	check("%s: no entra en los choques" % tag, seen["sink"] * 1000 <= limit, "%.1f mm" % (seen["sink"] * 1000))


func _step(skeleton: Skeleton3D) -> void:
	skeleton.advance(DT)
	await process_frame


## Lo más que el punto entra en algún choque (negativo = fuera de todos).
func _sink(simulator: SpringBoneSimulator3D, point: Vector3) -> float:
	var worst := -INF
	for shape in simulator.get_children():
		var place: Transform3D = shape.global_transform
		if shape is SpringBoneCollisionCapsule3D:
			var axis := place.basis.y.normalized()
			var half: float = shape.height * 0.5 - shape.radius
			worst = maxf(worst, shape.radius - point.distance_to(place.origin + axis * clampf((point - place.origin).dot(axis), -half, half)))
		elif shape is SpringBoneCollisionSphere3D:
			worst = maxf(worst, shape.radius - point.distance_to(place.origin))
	return worst
