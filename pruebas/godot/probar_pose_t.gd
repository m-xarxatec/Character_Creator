extends SceneTree
# Paso 3.6.2: pose T como pose del esqueleto (t_pose.gd).
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: godot --headless --path pruebas/godot -s probar_pose_t.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
# Las líneas MEDIDA (perfil humanoide) son solo informativas.

const MAX_DEG := 1.0
const RIGID_MM := 0.01
const BLENDER_MM := 0.05  # medido: máx. 0,0063 mm. Aprobado el 2026-11-11
const REPEAT_MM := 0.01  # medido: 0,0028 mm leyendo la pose; 0 desde que parte del reposo. Aprobado el 2026-11-11
const SIDES := {"Left": Vector3.RIGHT, "Right": Vector3.LEFT}
const ARM := ["UpperArm", "LowerArm", "Hand"]
const NEXT := {"Shoulder": "UpperArm", "UpperArm": "LowerArm", "LowerArm": "Hand", "Hand": "MiddleProximal"}

var failures := 0
var species
var base: Dictionary
var t_pose: GDScript
var baker: GDScript
var refit: GDScript
var shapes: GDScript
var reference: Dictionary


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	t_pose = load(addon.path_join("t_pose.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	refit = load(addon.path_join("skeleton_refit.gd"))
	shapes = load(addon.path_join("shape_weights.gd"))
	reference = JSON.parse_string(
		FileAccess.get_file_as_string(root_dir.path_join("pruebas/fase_2/salida/referencia_reajuste.json")))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	base = refit.capture_base(species.skeleton)
	for body: String in ["neutro", "extremo", "al_azar"]:
		_check_body(body)
	_check_scale()
	_check_profile()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _weights(name: String) -> Dictionary:
	for body: Dictionary in reference["bodies"]:
		if body["name"] == name:
			return body["weights"]
	return {}


func _set_up(body: String) -> void:
	var weights := _weights(body)
	shapes.apply(species.mesh, weights)
	refit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)


func _bone(name: String) -> int:
	return species.skeleton.find_bone(name)


## Índices del hueso y de todos sus descendientes.
func _branch(name: String) -> Dictionary:
	var found := {}
	var pending: Array[int] = [_bone(name)]
	while not pending.is_empty():
		var bone: int = pending.pop_back()
		found[bone] = true
		pending.append_array(species.skeleton.get_bone_children(bone))
	return found


func _check_body(body: String) -> void:
	var skeleton: Skeleton3D = species.skeleton
	_set_up(body)
	var before: Array[Transform3D] = baker.global_poses(skeleton)
	var before_local: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		before_local.append(skeleton.get_bone_pose(i))
	var before_vertices: PackedVector3Array = baker.bake(species.mesh, skeleton)["vertices"]
	t_pose.apply(skeleton)
	var after: Array[Transform3D] = baker.global_poses(skeleton)
	var after_vertices: PackedVector3Array = baker.bake(species.mesh, skeleton)["vertices"]

	var worst := 0.0
	var palm := 0.0
	var arms := {}
	var fingers_same := true
	for side: String in SIDES:
		var target: Vector3 = SIDES[side]
		for part: String in ARM:
			var direction := after[_bone(side + NEXT[part])].origin - after[_bone(side + part)].origin
			worst = maxf(worst, rad_to_deg(direction.angle_to(target)))
		var across := after[_bone(side + "IndexProximal")].origin - after[_bone(side + "LittleProximal")].origin
		palm = maxf(palm, rad_to_deg((across - target * across.dot(target)).angle_to(Vector3.BACK)))
		arms.merge(_branch(side + "UpperArm"))
		for bone: int in _branch(side + "Hand"):
			if bone != _bone(side + "Hand"):
				fingers_same = fingers_same and skeleton.get_bone_pose(bone) == before_local[bone]
	check(body + ": brazo, antebrazo y mano horizontales (< %s°)" % MAX_DEG, worst < MAX_DEG, "máximo %.4f°" % worst)
	check(body + ": palma hacia abajo, índice delante (< %s°)" % MAX_DEG, palm < MAX_DEG, "máximo %.4f°" % palm)
	var others_same := true
	for bone in skeleton.get_bone_count():
		if not arms.has(bone):
			others_same = others_same and after[bone] == before[bone]
	check(body + ": el resto de huesos no cambia y los dedos conservan su pose", others_same and fingers_same)
	for side: String in SIDES:
		_check_rigid_hand(body, side, before_vertices, after_vertices)

	t_pose.apply(skeleton)
	var again: Array[Transform3D] = baker.global_poses(skeleton)
	var repeat_mm := 0.0
	for bone in skeleton.get_bone_count():
		repeat_mm = maxf(repeat_mm, 1000.0 * again[bone].origin.distance_to(after[bone].origin))
		for axis in 3:
			repeat_mm = maxf(repeat_mm, 1000.0 * again[bone].basis[axis].distance_to(after[bone].basis[axis]))
	check(body + ": aplicarla dos veces da lo mismo (< %s mm)" % REPEAT_MM, repeat_mm < REPEAT_MM, "%.5f mm" % repeat_mm)
	if reference["t_pose"].has(body):
		_check_against_blender(body, after_vertices)


## Los vértices que dependen solo de la mano y sus dedos se mueven como un bloque: sus distancias no cambian.
func _check_rigid_hand(body: String, side: String, before: PackedVector3Array, after: PackedVector3Array) -> void:
	var arrays: Array = species.mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = species.mesh.skin
	var hand := _branch(side + "Hand")
	var rigid: PackedInt32Array = []
	for i in before.size():
		var only_hand := true
		for k in range(4 * i, 4 * i + 4):
			if weights[k] > 0.0 and not hand.has(skin.get_bind_bone(bones[k])):
				only_hand = false
		if only_hand:
			rigid.append(i)
	var worst := 0.0
	for i in rigid:
		for anchor: int in [rigid[0], rigid[rigid.size() / 2], rigid[rigid.size() - 1]]:
			worst = maxf(worst, 1000.0 * absf(before[i].distance_to(before[anchor]) - after[i].distance_to(after[anchor])))
	check("%s: mano %s sin deformar (< %s mm)" % [body, side, RIGID_MM], rigid.size() > 100 and worst < RIGID_MM,
		"%d vértices, máximo %.5f mm" % [rigid.size(), worst])


func _check_against_blender(body: String, vertices: PackedVector3Array) -> void:
	var arrays: Array = species.mesh.mesh.surface_get_arrays(0)
	var base_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = species.mesh.skin
	var shoulder := {}
	for side: String in SIDES:
		shoulder[_bone(side + "Shoulder")] = true
		shoulder[_bone(side + "UpperArm")] = true
	var grid := _skin_grid(reference["neutral_vertices"])
	var real: Array = reference["t_pose"][body]
	var worst := [0.0, 0.0]  # resto, hombro y axila
	var total := [0.0, 0.0]
	var count := [0, 0]
	for i in vertices.size():
		var group := 0
		for k in range(4 * i, 4 * i + 4):
			if weights[k] > 0.0 and shoulder.has(skin.get_bind_bone(bones[k])):
				group = 1
		var skin_index := _find(grid, reference["neutral_vertices"], base_vertices[i])
		var mm := 1000.0 * vertices[i].distance_to(_vector(real[skin_index])) if skin_index >= 0 else INF
		worst[group] = maxf(worst[group], mm)
		total[group] += mm
		count[group] += 1
	check(body + ": hombro y axila = pose T de Blender (< %s mm)" % BLENDER_MM, worst[1] < BLENDER_MM,
		"máximo %.4f mm, media %.4f mm (%d vértices)" % [worst[1], total[1] / count[1], count[1]])
	check(body + ": resto del cuerpo = pose T de Blender (< %s mm)" % BLENDER_MM, worst[0] < BLENDER_MM,
		"máximo %.4f mm, media %.4f mm (%d vértices)" % [worst[0], total[0] / count[0], count[0]])


func _check_scale() -> void:
	var skeleton: Skeleton3D = species.skeleton
	_set_up("neutro")
	var hand := _bone("LeftHand")
	skeleton.set_bone_pose_scale(hand, Vector3.ONE * 1.2)
	skeleton.set_bone_pose_scale(_bone("Root"), Vector3.ONE * 1.15)
	t_pose.apply(skeleton)
	var globals: Array[Transform3D] = baker.global_poses(skeleton)
	var direction := globals[_bone("LeftMiddleProximal")].origin - globals[hand].origin
	check("con escalas de Proporción: se conservan y la mano queda horizontal",
		skeleton.get_bone_pose_scale(hand).is_equal_approx(Vector3.ONE * 1.2)
		and skeleton.get_bone_pose_scale(_bone("Root")).is_equal_approx(Vector3.ONE * 1.15)
		and rad_to_deg(direction.angle_to(Vector3.RIGHT)) < MAX_DEG)
	skeleton.set_bone_pose_scale(hand, Vector3.ONE)
	skeleton.set_bone_pose_scale(_bone("Root"), Vector3.ONE)


## Pose de referencia del SkeletonProfileHumanoid de Godot, en global.
func _profile_global(profile: SkeletonProfileHumanoid, bone: String) -> Transform3D:
	var index := profile.find_bone(bone)
	var local := profile.get_reference_pose(index)
	var parent := profile.get_bone_parent(index)
	return local if parent == &"" else _profile_global(profile, parent) * local


func _check_profile() -> void:
	_set_up("neutro")
	t_pose.apply(species.skeleton)
	var globals: Array[Transform3D] = baker.global_poses(species.skeleton)
	var profile := SkeletonProfileHumanoid.new()
	for side: String in SIDES:
		for part: String in NEXT:
			var bone: String = side + part
			var child: String = side + NEXT[part]
			var ours := globals[_bone(child)].origin - globals[_bone(bone)].origin
			var theirs := _profile_global(profile, child).origin - _profile_global(profile, bone).origin
			var turn := (globals[_bone(bone)].basis.orthonormalized().inverse() * _profile_global(profile, bone).basis.orthonormalized())
			print("  MEDIDA perfil humanoide, %s: dirección del hueso %.2f°; giro completo (ejes del hueso) %.2f°"
				% [bone, rad_to_deg(ours.angle_to(theirs)), rad_to_deg(turn.get_rotation_quaternion().get_angle())])


func _skin_grid(points: Array) -> Dictionary:
	var grid := {}
	for i in points.size():
		var cell := Vector3i((_vector(points[i]) * 1000.0).floor())
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(i)
	return grid


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
