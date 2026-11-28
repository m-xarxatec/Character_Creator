extends SceneTree
# Paso PE.4c-a (ficha `ruta/pasos/PE.4c_traspaso_pelo.md`): el pelo largo no se mete en la piel al correr.
# Ligera a propósito: solo long01, solo «correr», 1 s y 10 muestras. Cuenta los vértices de las cadenas de pelo que
# entran en la piel más de 6 mm de lo que ya entran en reposo (piel por CPU, como `pruebas/capturas/pe4c/hombros/medir.gd`).
# Uso: godot --headless --path pruebas/godot -s probar_traspaso_pelo.gd
# Que detecta el fallo: en hair_physics.gd, HOLGURA «tope» y «tope_cabeza» a 0 -> falla «long01 al correr» (1446).
# Medido (2026-11-27): 1035; antes de PE.4c, 1818; con el pelo largo más rígido (×3), 1416.

const DT := 1.0 / 60.0
const WARM := 20
const FRAMES := 60
const EVERY := 6
const DEEP := 0.006  # metros de más que en reposo
const MAX_INSIDE := 1150  # PROVISIONAL: medido 1035 + 10 %
const CELL := 0.05
var skeleton: Skeleton3D
var baker: GDScript
var samples: Array = []


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	baker = load(addon.path_join("mesh_baker.gd"))
	var library = load(addon.path_join("pack_library.gd")).new()
	library.scan(PackedStringArray([root_dir.path_join("godot/packs")]))
	await process_frame
	var species = load(addon.path_join("species_data.gd")).new()
	species.load_folder(root_dir.path_join("godot/datos/humana"))
	root.add_child(species.scene)
	skeleton = species.skeleton
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var animations = load(addon.path_join("animation_set.gd")).new()
	animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	root.add_child(animations.scene)
	var retarget = load(addon.path_join("pose_retarget.gd")).new(animations.skeleton, skeleton, animations.bones, animations.hips)
	load(addon.path_join("character_updater.gd")).new(species).update({}, true)
	var pieces: GDScript = load(addon.path_join("body_piece.gd"))
	var mesh: MeshInstance3D = pieces.attach(library.load_piece("makehuman", "long01"), skeleton)
	pieces.follow(mesh, species.mesh)
	var simulator: SpringBoneSimulator3D = load(addon.path_join("hair_physics.gd")).attach(
			skeleton, load(addon.path_join("hair_chains.gd")).build(mesh, skeleton), species.mesh)
	retarget.capture()
	var hair := _pre_skin(mesh)
	var body := _pre_skin(species.mesh)
	skeleton.skeleton_updated.connect(func(): samples.append(_globals()))
	await _step()  # reposo
	animations.play("correr")
	simulator.reset()
	for f in WARM + FRAMES:
		animations.advance(DT)
		retarget.apply()
		await _step()
	var inside := _count(hair, body)
	print("  MEDIDA long01 al correr: %d vértices entran más de %.0f mm" % [inside, DEEP * 1000])
	var ok := inside <= MAX_INSIDE
	if not ok:
		print("  FALLO long01 al correr: %d > %d" % [inside, MAX_INSIDE])
	print("RESULTADO: ", "TODO BIEN" if ok else "1 FALLOS")
	quit(0 if ok else 1)


func _step() -> void:
	skeleton.advance(DT)
	await process_frame


func _globals() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for b in skeleton.get_bone_count():
		out.append(skeleton.get_bone_global_pose(b))
	return out


## Vértices de cadena (peso de huesos x_ ≥ 0,5) que, en alguna muestra, entran DEEP más que en reposo.
func _count(hair: Dictionary, body: Dictionary) -> int:
	var rest: PackedFloat32Array = _depths(_skin(hair, samples[0]), _skin(body, samples[0]))
	var seen := {}
	for s in range(1 + WARM, samples.size(), EVERY):
		var depth := _depths(_skin(hair, samples[s]), _skin(body, samples[s]))
		for h in depth.size():
			if hair["chain"][h] and maxf(depth[h], 0.0) - maxf(rest[h], 0.0) > DEEP:
				seen[h] = true
	return seen.size()


func _pre_skin(mesh: MeshInstance3D) -> Dictionary:
	var arrays := mesh.mesh.surface_get_arrays(0)
	baker._add_shapes(mesh, arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], {})  # formas puestas
	var binds := PackedInt32Array()
	for i in mesh.skin.get_bind_count():
		binds.append(skeleton.find_bone(mesh.skin.get_bind_name(i)) if mesh.skin.get_bind_bone(i) < 0 else mesh.skin.get_bind_bone(i))
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var chain := PackedByteArray()
	for v in bones.size() / per:
		var w := 0.0
		for k in range(per * v, per * v + per):
			w += weights[k] if skeleton.get_bone_name(binds[bones[k]]).begins_with("x_") else 0.0
		chain.append(int(w >= 0.5))
	return {"v": arrays[Mesh.ARRAY_VERTEX], "n": arrays[Mesh.ARRAY_NORMAL], "bones": bones, "weights": weights,
			"binds": binds, "skin": mesh.skin, "per": per, "chain": chain}


## Posiciones y normales con la piel puesta.
func _skin(data: Dictionary, globals: Array[Transform3D]) -> Array:
	var mats: Array[Transform3D] = []
	for i in data["skin"].get_bind_count():
		mats.append(globals[data["binds"][i]] * data["skin"].get_bind_pose(i))
	var v: PackedVector3Array = data["v"]
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	for i in v.size():
		var p := Vector3.ZERO
		var q := Vector3.ZERO
		for k in range(data["per"] * i, data["per"] * i + data["per"]):
			p += data["weights"][k] * (mats[data["bones"][k]] * v[i])
			q += data["weights"][k] * (mats[data["bones"][k]].basis * data["n"][i])
		out_v.append(p)
		out_n.append(q.normalized())
	return [out_v, out_n]


## Por vértice de pelo, cuánto entra en la piel (por la normal del vértice del cuerpo más cercano; -1 si lejos).
func _depths(hair: Array, body: Array) -> PackedFloat32Array:
	var grid := {}
	for i in body[0].size():
		var key := Vector3i((body[0][i] / CELL).floor())
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		grid[key].append(i)
	var depth := PackedFloat32Array()
	for p: Vector3 in hair[0]:
		var c := Vector3i((p / CELL).floor())
		var best := CELL * CELL
		var near := -1
		for d in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
				Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			for i in grid.get(c + d, PackedInt32Array()):
				if p.distance_squared_to(body[0][i]) < best:
					best = p.distance_squared_to(body[0][i])
					near = i
		var inside: float = (body[0][near] - p).dot(body[1][near]) if near >= 0 else -1.0
		depth.append(inside if near >= 0 and inside > 0.7 * sqrt(best) else -1.0)
	return depth
