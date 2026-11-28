extends SceneTree
# Paso PE.3a: HairChains.build (ficha ruta/pasos/PE.3_cadenas_pelo.md). Con varios peinados reales: cadenas al final
# del esqueleto (los huesos del cuerpo no cambian), ≤ 4 pesos que suman 1, padres bien, la punta en lo más bajo de su
# sector, rapado sin cadenas, en reposo la malla horneada no se mueve y dos veces sale lo mismo. Sin ventana.
# Paso PE.3b: al cambiar el cuerpo (CharacterUpdater.update), el peinado con cadenas hornea igual que sin ellas;
# con Cabeza › Tamaño (decidido el 2026-11-26: el pelo crece con la cabeza, como en VRoid), lo que pesaba solo en Head
# queda igual que sin cadenas y lo que pesa solo en Head y cadenas crece exactamente como la cabeza;
# HairChains.remove deja el esqueleto como estaba (huesos, reposo, pose, cuerpo horneado y un BoneAttachment3D).
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_cadenas_pelo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en HairChains._add_bones, skin.add_bind(bone, Transform3D.IDENTITY) -> falla «en reposo no se mueve»;
# en BodyPiece.follow, quitar la rama de is_chain_bone -> falla «sigue al cuerpo: torso largo».

const MAX_REST_MM := 0.1  # PROVISIONAL
const MAX_TIP_M := 0.01  # PROVISIONAL: la punta, a esto como mucho del vértice más bajo de su cadena
const SUM_EPS := 1e-4
const VALUES := {"head_width": 0.8, "head_height": 0.7}  # con formas activas en la cabeza
const CASES := [["makehuman", "bob02"], ["makehuman", "long01"], ["makehuman", "ponytail01"],
	["quaternius", "hair_long"], ["quaternius", "hair_buzzed"]]
const NO_CHAINS := ["hair_buzzed"]
const BODY_CASES := {"altura 0,65": {"height": 0.0}, "altura 1,15": {"height": 1.0},
	"cabeza alta": {"head_height": 1.0}, "torso largo": {"torso_length": 1.0}, "cuello largo": {"neck_length": 1.0}}
const BIG_HEAD := {"head_size": 1.0}  # ×2,5
var failures := 0
var root_dir: String
var addon: String
var library
var chains_script: GDScript
var piece_script: GDScript
var baker: GDScript


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	addon = root_dir.path_join("godot/addons/creador")
	chains_script = load(addon.path_join("hair_chains.gd"))
	piece_script = load(addon.path_join("body_piece.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	library = load(addon.path_join("pack_library.gd")).new()
	for warning: String in library.scan(PackedStringArray([root_dir.path_join("godot/packs")])):
		print("ERROR: ", warning)
	for case: Array in CASES:
		_check_case(case[0], case[1])
	_check_repeat("makehuman", "bob02")
	_check_follow_body("makehuman", "long01")
	await _check_remove("makehuman", "bob02")
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Especie nueva (las cadenas de un caso no pasan al siguiente) con VALUES aplicados.
func _species() -> Array:
	var species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
	root.add_child(species.scene)
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	updater.update(VALUES, false)
	return [species, updater]


func _put(species, pack: String, id: String) -> MeshInstance3D:
	var mesh: MeshInstance3D = piece_script.attach(library.load_piece(pack, id), species.skeleton)
	if mesh != null:
		piece_script.follow(mesh, species.mesh)
	return mesh


func _check_case(pack: String, id: String) -> void:
	var loaded := _species()
	var species = loaded[0]
	var skeleton: Skeleton3D = species.skeleton
	var mesh := _put(species, pack, id)
	check("%s: se pone" % id, mesh != null)
	if mesh == null:
		return
	var body_bones := _bone_names(skeleton)
	var before: PackedVector3Array = baker.bake(mesh, skeleton)["vertices"]
	var started := Time.get_ticks_msec()
	var chains: Array[PackedStringArray] = chains_script.build(mesh, skeleton)
	var spent := Time.get_ticks_msec() - started
	var bones := 0
	for chain in chains:
		bones += chain.size()
	print("  MEDIDA %s: %d cadenas, %d huesos, %d ms" % [id, chains.size(), bones, spent])
	if id in NO_CHAINS:
		check("%s: sin cadenas" % id, chains.is_empty() and skeleton.get_bone_count() == body_bones.size())
	else:
		check("%s: tiene cadenas" % id, not chains.is_empty())
	check("%s: los huesos del cuerpo no cambian de índice" % id, _bone_names(skeleton).slice(0, body_bones.size()) == body_bones)
	check("%s: los huesos nuevos son las cadenas, al final" % id, skeleton.get_bone_count() == body_bones.size() + bones)
	_check_parents(id, skeleton, chains)
	_check_weights(id, mesh)
	var after: PackedVector3Array = baker.bake(mesh, skeleton)["vertices"]
	var moved := _max_distance(before, after) * 1000.0
	print("  MEDIDA %s: en reposo se mueve %.4f mm" % [id, moved])
	check("%s: en reposo no se mueve" % id, moved <= MAX_REST_MM, "%.4f mm" % moved)
	_check_tips(id, mesh, skeleton, chains)
	species.scene.free()


func _check_parents(id: String, skeleton: Skeleton3D, chains: Array[PackedStringArray]) -> void:
	var ok := true
	for chain in chains:
		for k in chain.size():
			var bone := skeleton.find_bone(chain[k])
			var parent_name := skeleton.get_bone_name(skeleton.get_bone_parent(bone))
			ok = ok and chains_script.is_chain_bone(chain[k]) and parent_name == ("Head" if k == 0 else chain[k - 1])
	check("%s: cadenas hijas de Head, cada hueso del anterior" % id, ok)


func _check_weights(id: String, mesh: MeshInstance3D) -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per := weights.size() / count
	var worst_sum := 0.0
	var most := 0
	for i in count:
		var total := 0.0
		var used := 0
		for k in per:
			total += weights[i * per + k]
			used += 1 if weights[i * per + k] > 0.0 else 0
		worst_sum = maxf(worst_sum, absf(total - 1.0))
		most = maxi(most, used)
	check("%s: ≤ 4 pesos por vértice" % id, most <= 4, "%d" % most)
	check("%s: los pesos suman 1" % id, worst_sum <= SUM_EPS, "%.6f" % worst_sum)
	check("%s: las formas siguen en la malla" % id, mesh.mesh.get_blend_shape_count() > 0)


## La punta de cada cadena, a la altura del vértice más bajo de los que pesan sobre todo en esa cadena.
func _check_tips(id: String, mesh: MeshInstance3D, skeleton: Skeleton3D, chains: Array[PackedStringArray]) -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = baker.bake(mesh, skeleton)["vertices"]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / points.size()
	var lowest := {}  # cadena → altura del vértice más bajo
	for i in points.size():
		var share := {}
		for k in per:
			var bone_name := String(mesh.skin.get_bind_name(bones[i * per + k]))
			if weights[i * per + k] > 0.0 and chains_script.is_chain_bone(bone_name):
				var chain := bone_name.get_slice("_", 2)
				share[chain] = share.get(chain, 0.0) + weights[i * per + k]
		for chain: String in share:
			if share[chain] > 0.5:
				lowest[chain] = minf(lowest.get(chain, INF), points[i].y)
	var worst := 0.0
	for chain in chains:
		var sector := chain[0].get_slice("_", 2)
		var tip := skeleton.get_bone_global_rest(skeleton.find_bone(chain[chain.size() - 1])).origin
		if lowest.has(sector):
			worst = maxf(worst, absf(tip.y - lowest[sector]))
	if not chains.is_empty():
		print("  MEDIDA %s: punta a %.1f mm de lo más bajo" % [id, worst * 1000.0])
		check("%s: cada punta en lo más bajo de su cadena" % id, worst <= MAX_TIP_M, "%.1f mm" % (worst * 1000.0))


## Dos especies nuevas, el mismo peinado: mismos huesos, mismo reposo y mismos pesos.
func _check_repeat(pack: String, id: String) -> void:
	var results := []
	for run in 2:
		var loaded := _species()
		var skeleton: Skeleton3D = loaded[0].skeleton
		var mesh := _put(loaded[0], pack, id)
		chains_script.build(mesh, skeleton)
		var rests := []
		for bone in skeleton.get_bone_count():
			rests.append([skeleton.get_bone_name(bone), skeleton.get_bone_rest(bone)])
		var arrays := mesh.mesh.surface_get_arrays(0)
		results.append([rests, arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS]])
		loaded[0].scene.free()
	check("%s: dos veces, lo mismo" % id, results[0] == results[1])


func _bone_names(skeleton: Skeleton3D) -> Array:
	var names := []
	for bone in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(bone))
	return names


func _max_distance(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].distance_to(b[i]))
	return worst


## PE.3b: el mismo peinado dos veces, uno con cadenas; tras cada cambio del cuerpo, los dos hornean igual.
func _check_follow_body(pack: String, id: String) -> void:
	var loaded := _species()
	var skeleton: Skeleton3D = loaded[0].skeleton
	var plain := _put(loaded[0], pack, id)
	var chained := _put(loaded[0], pack, id)
	chains_script.build(chained, skeleton)
	loaded[1].pieces.append_array([plain, chained])
	for label: String in BODY_CASES:
		var values := VALUES.duplicate()
		values.merge(BODY_CASES[label], true)
		loaded[1].update(values, false)
		var moved := _max_distance(baker.bake(plain, skeleton)["vertices"], baker.bake(chained, skeleton)["vertices"]) * 1000.0
		print("  MEDIDA %s, %s: con cadenas a %.4f mm de sin ellas" % [id, label, moved])
		check("%s sigue al cuerpo: %s" % [id, label], moved <= MAX_REST_MM, "%.4f mm" % moved)
	_check_big_head(id, loaded[1], skeleton, plain, chained)
	loaded[0].scene.free()


## Cabeza › Tamaño ×2,5: los vértices que pesaban solo en Head, igual que sin cadenas; los que pesan solo en Head y
## en cadenas, la pose de la cabeza grande × la de la normal⁻¹ aplicada a como estaban (crecen con la cabeza).
func _check_big_head(id: String, updater, skeleton: Skeleton3D, plain: MeshInstance3D, chained: MeshInstance3D) -> void:
	var head := skeleton.find_bone("Head")
	updater.update(VALUES, false)
	var small: PackedVector3Array = baker.bake(chained, skeleton)["vertices"]
	var small_head: Transform3D = baker.global_poses(skeleton)[head]
	var values := VALUES.duplicate()
	values.merge(BIG_HEAD, true)
	updater.update(values, false)
	var grow: Transform3D = baker.global_poses(skeleton)[head] * small_head.affine_inverse()
	var with_plain: PackedVector3Array = baker.bake(plain, skeleton)["vertices"]
	var big: PackedVector3Array = baker.bake(chained, skeleton)["vertices"]
	var only_head := _only(plain, func(bone_name: String) -> bool: return bone_name == "Head")
	var on_head := _only(chained, func(bone_name: String) -> bool: return bone_name == "Head" or chains_script.is_chain_bone(bone_name))
	var same := 0.0
	var grown := 0.0
	for i in big.size():
		if only_head[i]:
			same = maxf(same, big[i].distance_to(with_plain[i]))
		if on_head[i]:
			grown = maxf(grown, big[i].distance_to(grow * small[i]))
	print("  MEDIDA %s, cabeza ×2,5: %d solo en Head a %.4f mm de sin cadenas; %d en Head y cadenas a %.4f mm de crecer con ella (de %d)"
		% [id, only_head.count(1), same * 1000.0, on_head.count(1), grown * 1000.0, big.size()])
	check("%s, cabeza ×2,5: lo que pesaba solo en Head, igual" % id, same * 1000.0 <= MAX_REST_MM, "%.4f mm" % (same * 1000.0))
	check("%s, cabeza ×2,5: el pelo de las cadenas crece con la cabeza" % id, on_head.count(1) > 0
		and grown * 1000.0 <= MAX_REST_MM, "%.4f mm" % (grown * 1000.0))


## 1 por vértice si todos sus pesos (> 0) van a huesos que cumplen wanted.
func _only(mesh: MeshInstance3D, wanted: Callable) -> PackedByteArray:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per := bones.size() / count
	var out := PackedByteArray()
	out.resize(count)
	for i in count:
		out[i] = 1
		for k in per:
			if weights[i * per + k] > 0.0 and not wanted.call(String(mesh.skin.get_bind_name(bones[i * per + k]))):
				out[i] = 0
	return out


## PE.3b: poner un peinado con cadenas, cambiar el cuerpo, quitarlo y remove: todo como antes.
func _check_remove(pack: String, id: String) -> void:
	var loaded := _species()
	var species = loaded[0]
	var skeleton: Skeleton3D = species.skeleton
	var holder := BoneAttachment3D.new()
	holder.bone_name = "Head"
	skeleton.add_child(holder)
	var state := _state(skeleton)
	var body: PackedVector3Array = baker.bake(species.mesh, skeleton)["vertices"]
	var mesh := _put(species, pack, id)
	chains_script.build(mesh, skeleton)
	loaded[1].pieces.append(mesh)
	var values := VALUES.duplicate()
	values.merge({"torso_length": 1.0, "head_size": 1.0}, true)
	loaded[1].update(values, false)
	loaded[1].pieces.clear()
	piece_script.detach(mesh)
	chains_script.remove(skeleton)
	loaded[1].update(VALUES, false)
	check("%s: remove deja los mismos huesos, reposo y pose" % id, _same_state(state, _state(skeleton)))
	var moved := _max_distance(body, baker.bake(species.mesh, skeleton)["vertices"]) * 1000.0
	check("%s: tras remove el cuerpo hornea igual" % id, moved <= MAX_REST_MM, "%.4f mm" % moved)
	await process_frame
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
	var gap := holder.global_position.distance_to(head) * 1000.0
	check("%s: tras remove un BoneAttachment3D sigue a su hueso" % id, gap <= MAX_REST_MM, "%.4f mm" % gap)
	species.scene.free()


func _state(skeleton: Skeleton3D) -> Array:
	var state := []
	for bone in skeleton.get_bone_count():
		state.append([skeleton.get_bone_name(bone), skeleton.get_bone_parent(bone), skeleton.get_bone_rest(bone),
			skeleton.get_bone_pose_position(bone), skeleton.get_bone_pose_rotation(bone), skeleton.get_bone_pose_scale(bone)])
	return state


func _same_state(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		for k in a[i].size():
			var x: Variant = a[i][k]
			var y: Variant = b[i][k]
			var same: bool = x == y if typeof(x) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT] else x.is_equal_approx(y)
			if not same:
				return false
	return true
