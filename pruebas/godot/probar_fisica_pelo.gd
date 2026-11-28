extends SceneTree
# Paso PE.4a: HairPhysics (ficha ruta/pasos/PE.4_fisica_pelo.md). Con bob02 y long01 sobre la especie, en tamaño normal,
# con Altura 0,65 y con Cabeza ×2,5: quieto, el pelo no se mueve; al girar la cabeza se queda atrás y vuelve; ninguna
# articulación entra en las colisiones (5 mm por el tamaño de la cabeza: el pelo crece con ella). Coste: el fotograma con
# el simulador encendido y apagado (dentro de advance no se simula: corre después, en el fotograma). Sin ventana.
# El esqueleto avanza a mano (MODIFIER_CALLBACK_MODE_PROCESS_MANUAL + advance, un fotograma entre pasos, como PE.2); la
# pose simulada solo se lee en skeleton_updated.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_fisica_pelo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en HairPhysics.attach, set_stiffness(i, 0.0) -> falla «vuelve».

const STILL_MM := 2.0  # PROVISIONAL: quieto (y tras volver), cada articulación a esto como mucho (medido 1,03 mm)
const LAG_MM := 10.0  # PROVISIONAL: al girar la cabeza, la punta se separa al menos esto (medido 32,9 mm como mínimo)
const SINK_MM := 5.0  # PROVISIONAL: con la cabeza a ×1; × Cabeza › Tamaño (medido 11,9 mm a ×2,5, en el giro)
const COST_MS := 1.0  # PROVISIONAL: diferencia del fotograma con el simulador encendido y apagado
const COST_FRAMES := 300
const DT := 1.0 / 60.0
const STILL_FRAMES := 120  # 2 s
const TURN_FRAMES := 30  # gira 30° y vuelve en 0,5 s
const SETTLE_FRAMES := 180  # 3 s
const TURN_DEG := 30.0
const HAIRS := ["bob02", "long01"]
const VARIANTS := {"normal": {}, "altura 0,65": {"height": 0.0}, "cabeza ×2,5": {"head_size": 1.0}}
var failures := 0
var root_dir: String
var addon: String
var library
var physics: GDScript
var chains_script: GDScript
var piece_script: GDScript


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	addon = root_dir.path_join("godot/addons/creador")
	physics = load(addon.path_join("hair_physics.gd"))
	chains_script = load(addon.path_join("hair_chains.gd"))
	piece_script = load(addon.path_join("body_piece.gd"))
	library = load(addon.path_join("pack_library.gd")).new()
	for warning: String in library.scan(PackedStringArray([root_dir.path_join("godot/packs")])):
		print("ERROR: ", warning)
	await process_frame
	for id: String in HAIRS:
		await _check_hair("makehuman", id)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_hair(pack: String, id: String) -> void:
	var species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		return
	root.add_child(species.scene)
	var skeleton: Skeleton3D = species.skeleton
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	updater.update({}, false)
	var mesh: MeshInstance3D = piece_script.attach(library.load_piece(pack, id), skeleton)
	piece_script.follow(mesh, species.mesh)
	updater.pieces.append(mesh)
	var chains: Array[PackedStringArray] = chains_script.build(mesh, skeleton)
	var simulator: SpringBoneSimulator3D = physics.attach(skeleton, chains, species.mesh)
	check("%s: hay simulador" % id, simulator != null)
	if simulator != null:
		_print_colliders(id, simulator)
		for label: String in VARIANTS:
			updater.update(VARIANTS[label], false)
			physics.refit(simulator, species.mesh)
			await _run(id + ", " + label, skeleton, simulator, chains)
		await _check_cost(id, skeleton, simulator)
	species.scene.free()


func _print_colliders(id: String, simulator: SpringBoneSimulator3D) -> void:
	var parts := PackedStringArray()
	for shape in simulator.get_children():
		if shape is SpringBoneCollisionCapsule3D:
			parts.append("%s r %.0f h %.0f" % [shape.bone_name, shape.radius * 1000, shape.height * 1000])
		elif shape is SpringBoneCollisionSphere3D:
			parts.append("%s r %.0f" % [shape.bone_name, shape.radius * 1000])
	print("  MEDIDA %s: colisiones (mm) %s" % [id, ", ".join(parts)])


## Quieto, giro de la cabeza y vuelta; mide desvío, retraso de la punta, choques y coste.
func _run(label: String, skeleton: Skeleton3D, simulator: SpringBoneSimulator3D, chains: Array[PackedStringArray]) -> void:
	var bones := PackedInt32Array()
	var tips := PackedInt32Array()
	for chain in chains:
		for bone_name in chain:
			bones.append(skeleton.find_bone(bone_name))
		tips.append(skeleton.find_bone(chain[chain.size() - 1]))
	var head := skeleton.find_bone("Head")
	var neck := skeleton.find_bone("Neck")
	var neck_rotation := skeleton.get_bone_pose_rotation(neck)
	var start := {}  # hueso → posición sin simular
	for bone in bones:
		start[bone] = skeleton.get_bone_global_pose(bone).origin
	var head_start := skeleton.get_bone_global_pose(head)
	var seen := {"still": 0.0, "lag": 0.0, "sink": -INF}
	var measure := [false]  # el retraso solo se mide durante el giro
	var on_update := func() -> void:
		var carry := skeleton.get_bone_global_pose(head) * head_start.affine_inverse()  # la cabeza: no se simula
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
		var angle := deg_to_rad(TURN_DEG) * sin(PI * (f + 1) / TURN_FRAMES)
		skeleton.set_bone_pose_rotation(neck, Quaternion(Vector3.UP, angle) * neck_rotation)
		await _step(skeleton)
	skeleton.set_bone_pose_rotation(neck, neck_rotation)
	measure[0] = false
	for f in SETTLE_FRAMES:
		await _step(skeleton)
	skeleton.skeleton_updated.disconnect(on_update)
	var back: float = seen["still"]
	var sink_limit := SINK_MM * skeleton.get_bone_pose_scale(head).x  # Cabeza › Tamaño
	print("  MEDIDA %s: quieto %.2f mm, retraso de la punta %.1f mm, tras volver %.2f mm, entra %.1f mm (límite %.1f)"
		% [label, still * 1000, seen["lag"] * 1000, back * 1000, seen["sink"] * 1000, sink_limit])
	check("%s: quieto no se mueve" % label, still * 1000 <= STILL_MM, "%.2f mm" % (still * 1000))
	check("%s: al girar la cabeza se queda atrás" % label, seen["lag"] * 1000 >= LAG_MM, "%.1f mm" % (seen["lag"] * 1000))
	check("%s: vuelve" % label, back * 1000 <= STILL_MM, "%.2f mm" % (back * 1000))
	check("%s: no entra en las colisiones" % label, seen["sink"] * 1000 <= sink_limit, "%.1f mm" % (seen["sink"] * 1000))


## Un paso del esqueleto y un fotograma (el simulador corre en el fotograma).
func _step(skeleton: Skeleton3D) -> void:
	skeleton.advance(DT)
	await process_frame


## Tiempo medio del fotograma con el simulador encendido menos apagado.
func _check_cost(id: String, skeleton: Skeleton3D, simulator: SpringBoneSimulator3D) -> void:
	var average := {}
	for active in [true, false]:
		simulator.active = active
		var total := 0
		for f in COST_FRAMES:
			skeleton.advance(DT)
			var started := Time.get_ticks_usec()
			await process_frame
			total += Time.get_ticks_usec() - started
		average[active] = total / float(COST_FRAMES) / 1000.0
	simulator.active = true
	var cost: float = average[true] - average[false]
	print("  MEDIDA %s: fotograma %.3f ms con el simulador, %.3f ms sin él" % [id, average[true], average[false]])
	check("%s: coste del simulador" % id, cost <= COST_MS, "%.3f ms" % cost)


## Lo más que el punto entra en alguna colisión del simulador (negativo = fuera de todas).
func _sink(simulator: SpringBoneSimulator3D, point: Vector3) -> float:
	var worst := -INF
	for shape in simulator.get_children():
		var place: Transform3D = shape.global_transform
		if shape is SpringBoneCollisionCapsule3D:
			var axis := place.basis.y.normalized()
			var half: float = shape.height * 0.5 - shape.radius
			var t := clampf((point - place.origin).dot(axis), -half, half)
			worst = maxf(worst, shape.radius - point.distance_to(place.origin + axis * t))
		elif shape is SpringBoneCollisionSphere3D:
			worst = maxf(worst, shape.radius - point.distance_to(place.origin))
	return worst
