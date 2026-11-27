extends SceneTree
# Paso 10.3b: el estudio de poses sobre la vista (godot/app/studio_view.gd): entrar hornea y esconde el vivo, salir
# guarda la pose y lo devuelve; la pose vuelve al entrar, también con otro cuerpo. Sin ventana.
# Uso: prlimit --as=4096000000 timeout 120 godot --headless --path godot -s "$PWD/pruebas/godot/probar_estudio.gd" < /dev/null 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
# Que detecta el fallo: en StudioView.leave, no hacer capture -> falla «salir y entrar conserva la pose».

const WorldPose := preload("res://addons/creador/world_pose.gd")
const BodyMaterial := preload("res://addons/creador/body_material.gd")
const JOINT_MAX := 0.0001  # (10.3b, ficha §1.3): metros entre las articulaciones de la misma pose
const TURN_MAX_DEG := 0.01  # (10.3b): grados entre los giros de la misma pose en dos cuerpos
const MOVED_MIN := 0.05  # (10.3b): metros que se mueve la mano al posar (la prueba no es vacía)
## «pack/pieza» → color puesto antes de entrar: una prenda, un peinado con cadenas y un accesorio.
const WORN := {"base/tights": Color(0.1, 0.6, 0.3), "makehuman/bob02": Color(0.7, 0.3, 0.1),
	"base/cuernos": Color(0.2, 0.3, 0.8)}

var failures := 0


func _initialize() -> void:
	var script: GDScript = load("res://app/studio_view.gd")
	var view: SubViewportContainer = load("res://app/body_view.gd").new()
	root.add_child(view)
	await process_frame
	check("carga la especie y el estudio", view.error == "" and script != null and script.can_instantiate(), view.error)
	if failures == 0:
		for key: String in WORN:
			check("poner %s" % key, view.set_piece(key.get_base_dir(), key.get_file(), true))
			view.set_piece_color(key, WORN[key])
		var studio = script.new()
		var t_joints := _check_enter(view, studio)
		if studio.character != null:
			_check_pose_kept(view, studio)
			_check_other_body(view, studio)
			_check_reset(view, studio, t_joints)
	view.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Devuelve las articulaciones en pose T.
func _check_enter(view, studio) -> PackedVector3Array:
	var nodes := _nodes(view)
	var start := Time.get_ticks_msec()
	var error: Error = studio.enter(view)
	print("  MEDIDA 10.3b: entrar en el estudio: %d ms" % (Time.get_ticks_msec() - start))
	check("entrar hornea el personaje y lo pone en la vista", error == OK and studio.character != null
		and studio.character.get_parent() == view.viewport and studio.character.is_visible_in_tree())
	if studio.character == null:
		return PackedVector3Array()
	var live := _live_meshes(view)
	check("el vivo queda oculto", live.all(func(m: MeshInstance3D) -> bool: return not m.is_visible_in_tree()), str(live.size()))
	check("sin sombra de suelo", not view.floor_shadow.visible)
	check("sin física de pelo", studio.character.find_children("*", "SpringBoneSimulator3D", true, false).is_empty())
	var meshes: int = studio.character.find_children("*", "MeshInstance3D", true, false).size()
	var exported := _exported_meshes(view)
	check("las mismas mallas que el .glb", meshes == exported and meshes > WORN.size(), "%d / %d" % [meshes, exported])
	_check_materials(view, studio)
	check("entra en pose T", WorldPose.capture(studio.skeleton).is_empty())
	var again: Error = studio.enter(view)
	check("entrar dos veces no hornea otro", again == OK and _nodes(view) == nodes + _count(studio.character),
		"%d" % _nodes(view))
	var t_joints := _joints(studio.skeleton)
	studio.leave()
	check("salir devuelve el vivo y la sombra", studio.character == null and view.floor_shadow.visible
		and _live_meshes(view).any(func(m: MeshInstance3D) -> bool: return m.is_visible_in_tree()))
	check("salir no deja ningún nodo de más", _nodes(view) == nodes, "%d / %d" % [_nodes(view), nodes])
	studio.leave()
	check("salir sin haber entrado no cambia nada", _nodes(view) == nodes)
	studio.enter(view)
	return t_joints


func _check_materials(view, studio) -> void:
	var soft: bool = BodyMaterial.is_soft(view.species.mesh)
	var meshes: Array = studio.character.find_children("*", "MeshInstance3D", true, false)
	var body := meshes[0].material_override as ShaderMaterial
	check("el cuerpo lleva el toon del .tres con su piel", body != null
		and body.shader.code == BodyMaterial.body_shader(soft).code and body.next_pass != null
		and body.get_shader_parameter("skin_color") == BodyMaterial.get_color(view.species.mesh, "skin_color"))
	for key: String in WORN:
		for live: MeshInstance3D in view.meshes_of(key):
			var baked := studio.character.find_child(live.name, true, false) as MeshInstance3D
			var material: ShaderMaterial = baked.material_override if baked != null else null
			check("%s: toon de pieza con su color (%s)" % [key, live.name], material != null
				and material.shader == BodyMaterial.piece_shader(soft)
				and material.get_shader_parameter("skin_color") == WORN[key]
				and material.get_shader_parameter("garment_color") == WORN[key])
	for eye: MeshInstance3D in view.eyes:
		var baked := studio.character.find_child(eye.name, true, false) as MeshInstance3D
		check("%s: el material del .glb" % eye.name, baked != null and baked.material_override == null
			and (baked.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture != null)


func _check_pose_kept(view, studio) -> void:
	var skeleton: Skeleton3D = studio.skeleton
	var before := _joints(skeleton)
	_turn(skeleton, "LeftUpperArm", Vector3.BACK, 40.0)
	_turn(skeleton, "LeftLowerArm", Vector3.UP, -35.0)
	_turn(skeleton, "Head", Vector3.UP, 20.0)
	var posed := _joints(skeleton)
	var hand := skeleton.find_bone("LeftHand")
	check("posar mueve la mano", posed[hand].distance_to(before[hand]) >= MOVED_MIN, "%.3f m" % posed[hand].distance_to(before[hand]))
	studio.leave()
	check("salir guarda la pose", ["LeftUpperArm", "LeftLowerArm", "Head"].all(func(bone: String) -> bool:
		return studio.pose["huesos"].has(bone)), str(studio.pose["huesos"].keys()))
	studio.enter(view)
	var gap := _gap(_joints(studio.skeleton), posed)
	print("  MEDIDA 10.3b: salir y entrar, articulación más lejos %.6f mm" % (gap * 1000.0))
	check("salir y entrar conserva la pose", gap <= JOINT_MAX, "%.4f mm" % (gap * 1000.0))


## Con otro cuerpo se vuelve a hornear y la pose (en el mundo) se pone encima.
func _check_other_body(view, studio) -> void:
	var saved: Dictionary = WorldPose.capture(studio.skeleton)
	var head: int = studio.skeleton.find_bone("Head")
	var height: float = _joints(studio.skeleton)[head].y
	studio.leave()
	var start: Dictionary = view.values.duplicate()
	var values := start.duplicate()
	values["height"] = 1.0
	view.set_values(values)
	studio.enter(view)
	check("con otra Altura, el horneado es otro", absf(_joints(studio.skeleton)[head].y - height) >= MOVED_MIN,
		"%.3f m" % (_joints(studio.skeleton)[head].y - height))
	var now: Dictionary = WorldPose.capture(studio.skeleton)
	var worst := 0.0 if now.size() == saved.size() and not saved.is_empty() else 180.0
	for bone: String in saved:
		var turn: Quaternion = now.get(bone, Quaternion.IDENTITY)
		worst = maxf(worst, rad_to_deg(WorldPose.angle_between(Basis(turn), Basis(saved[bone] as Quaternion))))
	print("  MEDIDA 10.3b: la pose en otro cuerpo, giro más distinto %.6f°" % worst)
	check("la pose se pone sobre el cuerpo nuevo", worst <= TURN_MAX_DEG, "%.4f°" % worst)
	studio.leave()
	view.set_values(start)
	studio.enter(view)


func _check_reset(view, studio, t_joints: PackedVector3Array) -> void:
	check("antes de restablecer hay pose", _gap(_joints(studio.skeleton), t_joints) >= MOVED_MIN
		and not studio.pose["huesos"].is_empty())
	studio.reset_pose()
	var gap := _gap(_joints(studio.skeleton), t_joints)
	check("restablecer vuelve a la pose T", gap <= JOINT_MAX and studio.pose["huesos"].is_empty(), "%.4f mm" % (gap * 1000.0))
	studio.leave()
	studio.enter(view)
	gap = _gap(_joints(studio.skeleton), t_joints)
	check("y sigue en T al volver a entrar", gap <= JOINT_MAX, "%.4f mm" % (gap * 1000.0))
	_turn(studio.skeleton, "Head", Vector3.UP, 20.0)
	studio.leave()
	studio.reset_pose()
	check("restablecer fuera del estudio vacía la pose", studio.pose["huesos"].is_empty() and studio.character == null)


func _turn(skeleton: Skeleton3D, bone: String, axis: Vector3, degrees: float) -> void:
	WorldPose.turn(skeleton, skeleton.find_bone(bone), skeleton.global_basis.inverse() * axis, deg_to_rad(degrees))


## Cabeza de cada hueso en el espacio del esqueleto, encadenada a mano desde la pose (sin get_bone_global_pose).
func _joints(skeleton: Skeleton3D) -> PackedVector3Array:
	var globals: Array[Transform3D] = []
	var joints := PackedVector3Array()
	for bone in skeleton.get_bone_count():
		var local := Transform3D(Basis(skeleton.get_bone_pose_rotation(bone)).scaled_local(skeleton.get_bone_pose_scale(bone)),
			skeleton.get_bone_pose_position(bone))
		var parent := skeleton.get_bone_parent(bone)
		globals.append(local if parent < 0 else globals[parent] * local)
		joints.append(globals[bone].origin)
	return joints


func _gap(a: PackedVector3Array, b: PackedVector3Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return INF
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].distance_to(b[i]))
	return worst


## Las mallas del personaje vivo: cuerpo, ojos, piezas y accesorios (se ve el cuerpo o su copia del estilo).
func _live_meshes(view) -> Array:
	var meshes: Array = [view.species.mesh, view.style]
	meshes.append_array(view.eyes)
	for key: String in WORN:
		meshes.append_array(view.meshes_of(key))
	return meshes


func _exported_meshes(view) -> int:
	var path := OS.get_user_data_dir().path_join("estudio_prueba.glb")
	var count := -1
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if view.export_glb(path) == OK and document.append_from_file(path, state) == OK:
		var scene := document.generate_scene(state)
		count = scene.find_children("*", "MeshInstance3D", true, false).size()
		scene.free()
	for file: String in [path, path.get_basename() + ".tres", path.get_basename() + ".tscn"]:
		DirAccess.remove_absolute(file)
	return count


## Nodos dentro del SubViewport.
func _nodes(view) -> int:
	return _count(view.viewport) - 1


func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children(true):
		total += _count(child)
	return total
