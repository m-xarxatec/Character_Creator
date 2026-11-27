extends SceneTree
# Pasos AB.4–AB.13: piezas sobre el personaje del editor (godot/app/body_view.gd con BodyPiece, BodyDerived y
# RigidPiece): poner y quitar, una por ranura, seguir al cuerpo, exportarlas en el .glb y guardarlas en el .gmolde.
# Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_piezas.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en BodyPiece.follow, quitar ShapeWeights.apply -> falla «las mallas siguen a weight».
# Paso PE.4b: un peinado que cuelga lleva cadenas y simulador; poner y quitar con un clip y en ROM sin errores.
# Paso PE.5: el .glb lleva los mismos x_pelo_* que el editor y la piel del peinado apunta a ellos; en pose A, igual que
# sin cadenas; pasa CharacterChecks. Que detecta el fallo: volver al CharacterBaker de PE.4b (sin cadenas y sus binds a
# la cabeza) -> falla «PE.5: el .glb lleva los huesos de pelo del editor» (solo el `break`: la exportación se rompe).
# Exportar con bob02 deja también la .tscn (HairScene); con el rapado, no. Que detecta el fallo: en
# BodyView.finish_export, no llamar a HairScene.save -> falla «PE.5: exportar con bob02 deja .glb, .tres y .tscn».

## Paso RE.1b: peinados de Quaternius.
const MeshBaker := preload("res://../../godot/addons/creador/mesh_baker.gd")
const BodyPiece := preload("res://../../godot/addons/creador/body_piece.gd")  # paso PE.4b
const Cloth := preload("medidas_tela.gd")  # paso 12.1a: medidas de tela sobre piel
## Paso AC.6b: el .glb lleva también los ojos (EyeMesh); no son piezas y no se cuentan (los mira probar_glb.gd --ojos).
const EYE_MESHES := ["ojo_l", "ojo_r", "linea_l", "linea_r", "linea_inferior_l", "linea_inferior_r", "pliegue_l", "pliegue_r",
	"ceja_l", "ceja_r"]  # AC.6c: las cejas
const QU_HAIR := ["hair_buns", "hair_long", "hair_buzzed_female", "hair_buzzed", "hair_simple_parted"]
const QU_SHAPES := ["head_width_incr", "head_height_incr", "gender_incr", "torso_length_incr", "neck_length_incr"]
## Cambio de la distancia con signo a la piel al deformar, en el pelo pegado al cuero cabelludo. Mide si se despega.
const QU_GAP_RMS_MAX := 0.003  # PROVISIONAL (2026-11-21): fijado antes de medir; el centro de la caja no valía con Complexión
const QU_GAP_PEAK_MAX := 0.01  # PROVISIONAL (2026-11-21): fijado antes de medir, por el mismo motivo
const QU_SCALP := 0.015  # metros: en neutro, más cerca de la piel de la cabeza que esto cuenta como cuero cabelludo
const QU_GAP_CELL := 0.03  # metros: celda de la rejilla de triángulos (se busca en la celda y sus vecinas)
const QU_CASES := {"torso": {"torso_length": 1.0}, "complexión": {"gender": 1.0}, "ambos": {"torso_length": 1.0, "gender": 1.0}}
const QU_NECK_DEPTH_MAX := 0.02  # PROVISIONAL: metros bajo la piel de cuello y hombros con la cabeza a ×2,5; medido 14,4 mm
const QU_NECK_DEPTH_CHAINS_MAX := 0.045  # PROVISIONAL (2026-11-26, aprobado): con cadenas el pelo crece con la cabeza (PE.3b, opción A); medido 41,6 mm con hair_long
const QU_CELL := 0.04  # metros: celda de la rejilla que busca el vértice de piel más cercano

## Paso RE.1c: ropa de OverScore. Distancia tela-piel al deformar y piel que asoma por la tela en «Atacar».
const OS_GAP_RMS_MAX := 0.003  # PROVISIONAL (2026-11-21): metros; medido 1,62 mm como máximo en las 5 prendas
const OS_GAP_PEAK_MAX := 0.006  # PROVISIONAL (2026-11-21): metros; medido 5,65 mm como máximo en las 5 prendas
const OS_ATTACK_SKIN_MAX := 5.0  # PROVISIONAL (2026-11-21): % de piel sobre la cara interior; medido 2,58 % como máximo
const OS_ATTACK_PEAK_MAX := 0.01  # PROVISIONAL (2026-11-21): metros; medido 9,2 mm como máximo
const OS_NEAR := 0.025  # metros: en neutro, la tela más cerca de la piel que esto es la que se mide al deformar
const OS_RAY_BELOW := 0.02  # metros: el rayo sale de esto por debajo de la piel
const OS_RAY_ABOVE := 0.09  # metros: tela más lejos que esto no cuenta como encima
const OS_HEM := 0.025  # metros: se mide la piel cubierta a más de esto de piel sin cubrir (lejos del borde)
const OS_CELL := 0.05  # metros: celda de la rejilla de triángulos de la tela
const OS_INSTANTS := 12
const OS_HAND_BONES := ["Hand", "Thumb", "Index", "Middle", "Ring", "Little"]
const OS_CASES := {"complexión 0": {"gender": 0.0}, "complexión 1": {"gender": 1.0}, "torso 0": {"torso_length": 0.0},
	"torso 1": {"torso_length": 1.0}, "altura mínima": {"height": 0.0}, "altura máxima": {"height": 1.0},
	"los tres": {"gender": 1.0, "torso_length": 1.0, "height": 1.0}}

var failures := 0


func _initialize() -> void:
	var main: Control = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/main.gd").simplify_path()).new()
	root.add_child(main)
	await process_frame
	var view = main.body_view
	_check_hairs(main, view, "quaternius", QU_HAIR, "Quaternius")
	_check_overscore(main, view)
	_check_makehuman(main, view)
	_check_wear(main, view)
	_check_export(view)
	_check_project(main, view)
	await _check_hair_physics(main, view)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Paso RE.1b: cada peinado del pack se pone, sigue a la cabeza, no se hunde en cuello y hombros y se exporta.
func _check_hairs(main: Control, view, pack: String, ids: Array, label: String) -> void:
	var start: Dictionary = main.editor.values.duplicate()
	var head_weight := _bone_weight(view.species.mesh, view.species.skeleton, "Head")
	var previous := ""
	for id: String in ids:
		check("%s: poner %s" % [label, id], view.set_piece(pack, id, true))
		var mesh: MeshInstance3D = view.pieces.get(pack + "/" + id)
		if mesh == null:
			continue
		check("%s: %s cuelga del esqueleto y trae las formas" % [label, id], mesh.get_parent() == view.species.skeleton
			and QU_SHAPES.all(func(shape: String) -> bool: return mesh.find_blend_shape_by_name(shape) >= 0))
		if previous != "":
			check("%s: %s quita el anterior (misma ranura)" % [label, id], not view.is_on(pack + "/" + previous))
		previous = id
		_check_follows(main, view, mesh, id, start, head_weight)
		_check_big_head(main, view, mesh, id, start, head_weight)
		_check_exports(view, id, label)
	view.set_piece(pack, previous, false)
	main.editor.load_values(start)


## Al deformar, el pelo pegado al cuero cabelludo mantiene su distancia con signo a la superficie de la piel.
func _check_follows(main: Control, view, mesh: MeshInstance3D, id: String, start: Dictionary, head_weight: PackedFloat32Array) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	var indices: PackedInt32Array = view.species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	main.editor.load_values(start)
	var points: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
	var all := _unique_points(points)
	var neutral := _surface_gaps(points, all, MeshBaker.bake(view.species.mesh, skeleton), indices, head_weight)
	var measured := PackedInt32Array()
	var before := PackedFloat64Array()
	for k in all.size():
		if neutral["scalp"][k] == 1 and absf(neutral["gaps"][k]) < QU_SCALP:
			measured.append(all[k])
			before.append(neutral["gaps"][k])
	print("  MEDIDA %s: %d de %d vértices medidos (%.1f %%)" % [id, measured.size(), all.size(), 100.0 * measured.size() / all.size()])
	check("%s tiene vértices sobre el cuero cabelludo" % id, measured.size() > 0)
	if measured.is_empty():
		return
	for label: String in QU_CASES:
		var values := start.duplicate()
		values.merge(QU_CASES[label], true)
		main.editor.load_values(values)
		var moved: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
		var after: PackedFloat64Array = _surface_gaps(moved, measured, MeshBaker.bake(view.species.mesh, skeleton), indices, head_weight)["gaps"]
		var sum := 0.0
		var peak := 0.0
		for k in measured.size():
			var change := absf(after[k] - before[k])
			sum += change * change
			peak = maxf(peak, change)
		var rms := sqrt(sum / measured.size())
		print("  MEDIDA %s (%s): cambio de distancia a la piel RMS %.2f mm, pico %.2f mm" % [id, label, rms * 1000, peak * 1000])
		check("%s no se despega de la piel (%s)" % [id, label], rms <= QU_GAP_RMS_MAX and peak <= QU_GAP_PEAK_MAX,
			"RMS %.2f, pico %.2f mm" % [rms * 1000, peak * 1000])
	main.editor.load_values(start)


## Con Cabeza › Tamaño ×2,5, ningún vértice queda hundido más de QU_NECK_DEPTH_MAX en la piel de cuello y hombros.
func _check_big_head(main: Control, view, mesh: MeshInstance3D, id: String, start: Dictionary, head_weight: PackedFloat32Array) -> void:
	var values := start.duplicate()
	values["head_size"] = 1.0
	main.editor.load_values(values)
	var body: Dictionary = MeshBaker.bake(view.species.mesh, view.species.skeleton)
	var depth := _neck_depth(MeshBaker.bake(mesh, view.species.skeleton)["vertices"], body, head_weight)
	var chains: bool = view.hair_physics.keys().any(func(key: String) -> bool: return key.get_file() == id)
	var limit := QU_NECK_DEPTH_CHAINS_MAX if chains else QU_NECK_DEPTH_MAX
	print("  MEDIDA %s con cabeza ×2,5: %.1f mm bajo la piel de cuello y hombros%s" % [id, depth * 1000, " (con cadenas)" if chains else ""])
	check("%s no se hunde en cuello y hombros a ×2,5" % id, depth <= limit, "%.1f mm" % (depth * 1000))
	main.editor.load_values(start)


func _check_exports(view, id: String, label := "Quaternius") -> void:
	var path := OS.get_user_data_dir().path_join("piezas_qu_prueba.glb")
	var ok: bool = view.export_glb(path) == OK
	var count := 0
	if ok:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		ok = document.append_from_file(path, state) == OK
		if ok:
			var scene := document.generate_scene(state)
			var meshes := scene.find_children("*", "MeshInstance3D", true, false)
			count = _without_eyes(meshes).size()
			ok = meshes.all(func(m: MeshInstance3D) -> bool: return m.skin != null)
			scene.free()
	check("%s: %s se exporta con el cuerpo" % [label, id], ok and count == 2, str(count))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_basename() + ".tres")


## Paso RE.1c: cada prenda sigue a los deslizadores, no deja asomar la piel en «Atacar» y se exporta.
func _check_overscore(main: Control, view) -> void:
	var cards: Array = view.library.pieces("ropa", "humana").filter(func(card: Dictionary) -> bool: return card["pack"] == "overscore")
	check("OverScore: el pack tiene prendas", not cards.is_empty())
	var start: Dictionary = main.editor.values.duplicate()
	var bodies := _os_bodies(main, view, start)
	var hands := Cloth.hand_mask(view.species.mesh, view.species.skeleton, OS_HAND_BONES)
	for card: Dictionary in cards:
		var id: String = card["id"]
		check("OverScore: poner %s" % id, view.set_piece("overscore", id, true))
		var mesh: MeshInstance3D = view.pieces.get("overscore/" + id)
		if mesh == null:
			continue
		check("OverScore: %s cuelga del esqueleto y trae las formas" % id, mesh.get_parent() == view.species.skeleton
			and mesh.find_blend_shape_by_name("gender_incr") >= 0 and mesh.find_blend_shape_by_name("torso_length_incr") >= 0)
		_check_os_follows(main, view, mesh, id, start, bodies)
		_check_os_attack(view, mesh, id, bodies, hands)
		_check_exports(view, id, "OverScore")
		view.set_piece("overscore", id, false)
	main.editor.load_values(start)
	_check_os_layers(view, cards)


## El cuerpo horneado en neutro, en cada caso y en cada instante de «Atacar» (es el mismo para todas las prendas).
func _os_bodies(main: Control, view, start: Dictionary) -> Dictionary:
	var found := {"neutro": MeshBaker.bake(view.species.mesh, view.species.skeleton)}
	for label: String in OS_CASES:
		var values := start.duplicate()
		values.merge(OS_CASES[label], true)
		main.editor.load_values(values)
		found[label] = MeshBaker.bake(view.species.mesh, view.species.skeleton)
	main.editor.load_values(start)
	view.set_animation("atacar")
	for i in OS_INSTANTS:
		view.animations.seek(view.animations.length() * i / OS_INSTANTS)
		view.retarget.apply()
		found["atacar %d" % i] = MeshBaker.bake(view.species.mesh, view.species.skeleton)
	view.set_animation("")
	return found


func _body_height(points: PackedVector3Array) -> float:
	var low := INF
	var high := -INF
	for point in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	return high - low


## Al deformar, la tela cercana a la piel mantiene su distancia a ella (dividida por la escala de Altura).
func _check_os_follows(main: Control, view, mesh: MeshInstance3D, id: String, start: Dictionary, bodies: Dictionary) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	var indices: PackedInt32Array = view.species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var no_head := PackedFloat32Array()
	no_head.resize(bodies["neutro"]["vertices"].size())
	main.editor.load_values(start)
	var points: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
	var all := _unique_points(points)
	var gaps: PackedFloat64Array = _surface_gaps(points, all, bodies["neutro"], indices, no_head)["gaps"]
	var measured := PackedInt32Array()
	var before := PackedFloat64Array()
	for k in all.size():
		if absf(gaps[k]) < OS_NEAR:
			measured.append(all[k])
			before.append(gaps[k])
	check("OverScore: %s tiene tela cerca de la piel" % id, measured.size() > 0)
	var height := _body_height(bodies["neutro"]["vertices"])
	var worst_rms := 0.0
	var worst_peak := 0.0
	for label: String in OS_CASES:
		var values := start.duplicate()
		values.merge(OS_CASES[label], true)
		main.editor.load_values(values)
		var moved: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
		var scale := _body_height(bodies[label]["vertices"]) / height
		var after: PackedFloat64Array = _surface_gaps(moved, measured, bodies[label], indices, no_head)["gaps"]
		var sum := 0.0
		var peak := 0.0
		var count := 0
		for k in measured.size():
			if is_finite(after[k]):
				var change := absf(after[k] / scale - before[k])
				sum += change * change
				peak = maxf(peak, change)
				count += 1
		worst_rms = maxf(worst_rms, sqrt(sum / maxi(count, 1)))
		worst_peak = maxf(worst_peak, peak)
	main.editor.load_values(start)
	print("  MEDIDA %s: cambio de distancia tela-piel, peor caso RMS %.2f mm, pico %.2f mm (%d vértices)" % [id, worst_rms * 1000, worst_peak * 1000, measured.size()])
	check("OverScore: %s sigue a Complexión, Torso y Altura" % id, worst_rms <= OS_GAP_RMS_MAX and worst_peak <= OS_GAP_PEAK_MAX,
		"RMS %.2f, pico %.2f mm" % [worst_rms * 1000, worst_peak * 1000])


## En «Atacar», la piel lejos del borde no pasa de la cara interior de la tela.
func _check_os_attack(view, mesh: MeshInstance3D, id: String, bodies: Dictionary, hands: PackedByteArray) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	var tris: PackedInt32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var cloth: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
	var inner := Cloth.covered_skin(bodies["neutro"], cloth, tris, hands, OS_RAY_BELOW, OS_RAY_ABOVE, OS_CELL, OS_HEM)
	check("OverScore: %s cubre piel" % id, inner.size() > 0)
	var worst_share := 0.0
	var worst_peak := 0.0
	view.set_animation("atacar")
	for i in OS_INSTANTS:
		view.animations.seek(view.animations.length() * i / OS_INSTANTS)
		view.retarget.apply()
		var body: Dictionary = bodies["atacar %d" % i]
		var moved: PackedVector3Array = MeshBaker.bake(mesh, skeleton)["vertices"]
		var heights := Cloth.cloth_heights(body["vertices"], body["normals"], inner, moved, tris, OS_RAY_BELOW, OS_RAY_ABOVE, OS_CELL)
		var over := 0
		var hit := 0
		for value in heights:
			if is_finite(value):
				hit += 1
				if value < 0.0:
					over += 1
					worst_peak = maxf(worst_peak, -value)
		worst_share = maxf(worst_share, 100.0 * over / maxi(hit, 1))
	view.set_animation("")
	print("  MEDIDA %s en Atacar: piel sobre la cara interior hasta %.2f %%, pico %.1f mm (%d vértices de piel)" % [id, worst_share, worst_peak * 1000, inner.size()])
	check("OverScore: %s no deja asomar la piel en Atacar" % id, worst_share <= OS_ATTACK_SKIN_MAX and worst_peak <= OS_ATTACK_PEAK_MAX,
		"%.2f %%, %.1f mm" % [worst_share, worst_peak * 1000])


## Criterio de RE.1c: cada prenda de torso con cada short da 0 pares de triángulos cruzados en neutro. En «Atacar» se mide.
func _check_os_layers(view, cards: Array) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	for top: Dictionary in cards.filter(func(card: Dictionary) -> bool: return card["ranura"] == "ropa_torso"):
		for low: Dictionary in cards.filter(func(card: Dictionary) -> bool: return card["ranura"] == "ropa_piernas"):
			var label: String = "%s + %s" % [top["id"], low["id"]]
			check("OverScore: %s se llevan a la vez" % label, view.set_piece("overscore", top["id"], true)
				and view.set_piece("overscore", low["id"], true) and view.is_on("overscore/" + top["id"]))
			var a: MeshInstance3D = view.pieces["overscore/" + top["id"]]
			var b: MeshInstance3D = view.pieces["overscore/" + low["id"]]
			var ta: PackedInt32Array = a.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
			var tb: PackedInt32Array = b.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
			var neutral := _cross_pairs(MeshBaker.bake(a, skeleton)["vertices"], ta, MeshBaker.bake(b, skeleton)["vertices"], tb)
			var attack := 0
			view.set_animation("atacar")
			for i in OS_INSTANTS:
				view.animations.seek(view.animations.length() * i / OS_INSTANTS)
				view.retarget.apply()
				attack = maxi(attack, _cross_pairs(MeshBaker.bake(a, skeleton)["vertices"], ta, MeshBaker.bake(b, skeleton)["vertices"], tb))
			view.set_animation("")
			print("  MEDIDA %s: %d pares cruzados en neutro; en Atacar, hasta %d (solo se mide)" % [label, neutral, attack])
			check("OverScore: %s no se cruzan en neutro" % label, neutral == 0, str(neutral))
			check("OverScore: un traje quita %s" % label, view.set_piece("makehuman", "female_casualsuit01", true)
				and not view.is_on("overscore/" + top["id"]) and not view.is_on("overscore/" + low["id"]))
			view.set_piece("makehuman", "female_casualsuit01", false)


## Pares (triángulo de a, triángulo de b) que se cortan: una arista de uno atraviesa al otro.
func _cross_pairs(a: PackedVector3Array, ta: PackedInt32Array, b: PackedVector3Array, tb: PackedInt32Array) -> int:
	var grid := Cloth.cloth_grid(b, tb, OS_CELL)
	var count := 0
	for s in ta.size() / 3:
		var p := a[ta[3 * s]]
		var q := a[ta[3 * s + 1]]
		var r := a[ta[3 * s + 2]]
		var from := Vector3i((p.min(q).min(r) / OS_CELL).floor())
		var to := Vector3i((p.max(q).max(r) / OS_CELL).floor())
		var seen := {}
		for x in range(from.x, to.x + 1):
			for y in range(from.y, to.y + 1):
				for z in range(from.z, to.z + 1):
					for t: int in grid.get(Vector3i(x, y, z), PackedInt32Array()):
						if seen.has(t):
							continue
						seen[t] = true
						var u := b[tb[3 * t]]
						var v := b[tb[3 * t + 1]]
						var w := b[tb[3 * t + 2]]
						if _edges_hit(p, q, r, u, v, w) or _edges_hit(u, v, w, p, q, r):
							count += 1
	return count


func _edges_hit(p: Vector3, q: Vector3, r: Vector3, u: Vector3, v: Vector3, w: Vector3) -> bool:
	return Cloth.segment_hit(p, q, u, v, w) != null \
		or Cloth.segment_hit(q, r, u, v, w) != null \
		or Cloth.segment_hit(r, p, u, v, w) != null


## Peso de un hueso en cada vértice de la malla.
func _bone_weight(mesh: MeshInstance3D, skeleton: Skeleton3D, bone: String) -> PackedFloat32Array:
	var bind := -1
	for i in mesh.skin.get_bind_count():
		var bind_name := String(mesh.skin.get_bind_name(i))
		if (bind_name if bind_name != "" else skeleton.get_bone_name(mesh.skin.get_bind_bone(i))) == bone:
			bind = i
	var arrays := mesh.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var found := PackedFloat32Array()
	found.resize(bones.size() / 4)
	for k in bones.size():
		if bones[k] == bind:
			found[k / 4] += weights[k]
	return found


## Índice del primer vértice de cada posición (las costuras de UV repiten posiciones).
func _unique_points(points: PackedVector3Array) -> PackedInt32Array:
	var seen := {}
	var found := PackedInt32Array()
	for i in points.size():
		var key := Vector3i((points[i] * 100000.0).round())
		if not seen.has(key):
			seen[key] = true
			found.append(i)
	return found


## Para los puntos which: distancia con signo a la piel (fuera +, dentro −, INF si no hay piel cerca) y si la cara
## más cercana es de la cabeza (peso medio a Head ≥ 0,5). El signo sale de la normal suave en el punto más cercano.
func _surface_gaps(points: PackedVector3Array, which: PackedInt32Array, body: Dictionary, indices: PackedInt32Array,
		head_weight: PackedFloat32Array) -> Dictionary:
	var skin: PackedVector3Array = body["vertices"]
	var normals: PackedVector3Array = body["normals"]
	var grid := _triangle_grid(points, which, skin, indices)
	var stamp := PackedInt32Array()
	stamp.resize(indices.size() / 3)
	stamp.fill(-1)
	var gaps := PackedFloat64Array()
	var scalp := PackedByteArray()
	gaps.resize(which.size())
	scalp.resize(which.size())
	for k in which.size():
		var point := points[which[k]]
		var center := Vector3i((point / QU_GAP_CELL).floor())
		var best := INF
		var gap := INF
		var on_head := 0
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var cell := center + Vector3i(x, y, z)
					if not grid.has(cell):
						continue
					for t: int in grid[cell]:
						if stamp[t] == k:
							continue
						stamp[t] = k
						var ia := indices[3 * t]
						var ib := indices[3 * t + 1]
						var ic := indices[3 * t + 2]
						var bary := _closest_bary(point, skin[ia], skin[ib], skin[ic])
						var near: Vector3 = bary.x * skin[ia] + bary.y * skin[ib] + bary.z * skin[ic]
						var distance := point.distance_squared_to(near)
						if distance < best:
							best = distance
							var normal: Vector3 = bary.x * normals[ia] + bary.y * normals[ib] + bary.z * normals[ic]
							gap = sqrt(distance) * (1.0 if (point - near).dot(normal) >= 0.0 else -1.0)
							on_head = 1 if (head_weight[ia] + head_weight[ib] + head_weight[ic]) / 3.0 >= 0.5 else 0
		gaps[k] = gap
		scalp[k] = on_head
	return {"gaps": gaps, "scalp": scalp}


## {celda: triángulos cuya caja la toca}, solo los que están cerca de los puntos.
func _triangle_grid(points: PackedVector3Array, which: PackedInt32Array, skin: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in which:
		low = low.min(points[i])
		high = high.max(points[i])
	var region := AABB(low, high - low).grow(2.0 * QU_GAP_CELL)
	var grid := {}
	for t in indices.size() / 3:
		var a := skin[indices[3 * t]]
		var b := skin[indices[3 * t + 1]]
		var c := skin[indices[3 * t + 2]]
		var box_low := a.min(b).min(c)
		var box_high := a.max(b).max(c)
		if not region.intersects(AABB(box_low, box_high - box_low).grow(0.0001)):
			continue
		var from := Vector3i((box_low / QU_GAP_CELL).floor())
		var to := Vector3i((box_high / QU_GAP_CELL).floor())
		for x in range(from.x, to.x + 1):
			for y in range(from.y, to.y + 1):
				for z in range(from.z, to.z + 1):
					var cell := Vector3i(x, y, z)
					if not grid.has(cell):
						grid[cell] = PackedInt32Array()
					grid[cell].append(t)
	return grid


## Baricéntricas del punto del triángulo más cercano a p (Ericson, «Real-Time Collision Detection», §5.1.5).
func _closest_bary(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return Vector3(1, 0, 0)
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return Vector3(0, 1, 0)
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v := d1 / (d1 - d3)
		return Vector3(1.0 - v, v, 0)
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return Vector3(0, 0, 1)
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w := d2 / (d2 - d6)
		return Vector3(1.0 - w, 0, w)
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and d4 - d3 >= 0.0 and d5 - d6 >= 0.0:
		var w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return Vector3(0, 1.0 - w, w)
	var scale := 1.0 / (va + vb + vc)
	return Vector3(1.0 - vb * scale - vc * scale, vb * scale, vc * scale)


## Mayor profundidad bajo la piel de los puntos cuyo vértice de piel más cercano es de cuello u hombros (no de la cabeza).
func _neck_depth(points: PackedVector3Array, body: Dictionary, head_weight: PackedFloat32Array) -> float:
	var skin: PackedVector3Array = body["vertices"]
	var normals: PackedVector3Array = body["normals"]
	var grid := {}
	for v in skin.size():
		var cell := Vector3i((skin[v] / QU_CELL).floor())
		if not grid.has(cell):
			grid[cell] = PackedInt32Array()
		grid[cell].append(v)
	var worst := 0.0
	for point in points:
		var nearest := _nearest_skin(point, skin, grid)
		if nearest >= 0 and head_weight[nearest] < 0.5:
			worst = maxf(worst, -(point - skin[nearest]).dot(normals[nearest]))
	return worst


func _nearest_skin(point: Vector3, skin: PackedVector3Array, grid: Dictionary) -> int:
	var center := Vector3i((point / QU_CELL).floor())
	var best := INF
	var nearest := -1
	for x in range(-2, 3):
		for y in range(-2, 3):
			for z in range(-2, 3):
				var cell := center + Vector3i(x, y, z)
				if grid.has(cell):
					for v: int in grid[cell]:
						var distance := point.distance_squared_to(skin[v])
						if distance < best:
							best = distance
							nearest = v
	return nearest


## Paso RE.1a: assets de MakeHuman de cada ranura (pelo, camiseta, shorts): se ponen, siguen al cuerpo y se exportan.
## Un traje completo y unos shorts no van juntos; una camiseta y unos shorts sí.
func _check_makehuman(main: Control, view) -> void:
	var worn := {"short02": "pelo", "toigo_basic_tucked_t-shirt": "ropa_torso", "cortu_jeans_shorts": "ropa_piernas"}
	for id: String in worn:
		check("MakeHuman: poner %s (%s)" % [id, worn[id]], view.set_piece("makehuman", id, true))
	check("MakeHuman: camiseta y shorts a la vez (otra ranura)", view.is_on("makehuman/toigo_basic_tucked_t-shirt")
		and view.is_on("makehuman/cortu_jeans_shorts") and view.is_on("makehuman/short02"))
	var values: Dictionary = main.editor.values.duplicate()
	values["weight"] = 1.0
	values["head_width"] = 1.0
	main.editor.load_values(values)
	for id: String in worn:  # el pelo no cambia con weight_incr (menos de 0,1 mm): sigue a head_width
		var mesh: MeshInstance3D = view.pieces["makehuman/" + id]
		var name := "head_width_incr" if worn[id] == "pelo" else "weight_incr"
		var shape := mesh.find_blend_shape_by_name(name)
		check("MakeHuman: %s cuelga del esqueleto y sigue al cuerpo (%s)" % [id, name], mesh.get_parent() == view.species.skeleton
			and shape >= 0 and mesh.get_blend_shape_value(shape) == 1.0)
	var path := OS.get_user_data_dir().path_join("piezas_mh_prueba.glb")
	check("MakeHuman: exportar con las 3 piezas", view.export_glb(path) == OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		check("MakeHuman: el .glb se vuelve a leer", false)
	else:
		var scene := document.generate_scene(state)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		check("MakeHuman: el .glb trae cuerpo + 3 mallas, todas con piel", _without_eyes(meshes).size() == 4
			and meshes.all(func(m: MeshInstance3D) -> bool: return m.skin != null), str(_without_eyes(meshes).size()))
		scene.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_basename() + ".tres")
	check("MakeHuman: otra camiseta quita la anterior (misma ranura) y deja los shorts", view.set_piece("makehuman", "elvs_crude_t-shirt_male", true)
		and not view.is_on("makehuman/toigo_basic_tucked_t-shirt") and view.is_on("makehuman/cortu_jeans_shorts"))
	check("MakeHuman: un traje completo quita camiseta y shorts", view.set_piece("makehuman", "female_casualsuit01", true)
		and view.is_on("makehuman/female_casualsuit01") and not view.is_on("makehuman/elvs_crude_t-shirt_male")
		and not view.is_on("makehuman/cortu_jeans_shorts") and view.is_on("makehuman/short02"))
	check("MakeHuman: unos shorts quitan el traje completo", view.set_piece("makehuman", "cortu_jeans_shorts", true)
		and view.is_on("makehuman/cortu_jeans_shorts") and not view.is_on("makehuman/female_casualsuit01"))
	check("MakeHuman: una camiseta con los shorts puestos no los quita", view.set_piece("makehuman", "toigo_camisole_top", true)
		and view.is_on("makehuman/cortu_jeans_shorts"))
	for id: String in view.pieces.keys():
		if id.begins_with("makehuman/"):
			view.set_piece("makehuman", id.get_file(), false)
	check("MakeHuman: todo quitado", view.pieces.keys().all(func(k: String) -> bool: return not k.begins_with("makehuman/")))


func _check_wear(main: Control, view) -> void:
	for id in ["tights", "casquete", "cuernos", "halo"]:
		check("poner %s" % id, view.set_piece("base", id, true))
	check("la melena quita el casquete (misma ranura) y al revés", view.set_piece("base", "melena", true)
		and not view.is_on("base/casquete") and view.set_piece("base", "casquete", true) and not view.is_on("base/melena"))
	var tights: MeshInstance3D = view.pieces["base/tights"]
	check("la malla cuelga del esqueleto del cuerpo", tights.get_parent() == view.species.skeleton)
	var values: Dictionary = main.editor.values.duplicate()
	values["weight"] = 1.0
	main.editor.load_values(values)
	var shape := tights.find_blend_shape_by_name("weight_incr")
	check("las mallas siguen a weight (forma weight_incr a 1)", shape >= 0 and tights.get_blend_shape_value(shape) == 1.0)
	var cap: MeshInstance3D = view.pieces["base/casquete"]
	print("  MEDIDA casquete: %d triángulos, %d formas" % [cap.mesh.get_faces().size() / 3, cap.mesh.get_blend_shape_count()])
	check("el casquete tiene caras y formas", cap.mesh.get_faces().size() > 0 and cap.mesh.get_blend_shape_count() > 0)
	check("los cuernos son dos mallas en un BoneAttachment3D de Head", view.meshes_of("base/cuernos").size() == 2
		and view.accessories["base/cuernos"].bone_name == "Head")
	view.set_piece_color("base/tights", Color(0.1, 0.6, 0.3))
	check("el color elegido se queda", view.piece_color("base/tights").is_equal_approx(Color(0.1, 0.6, 0.3)))
	check("is_on y meshes_of de algo no puesto", not view.is_on("base/no") and view.meshes_of("base/no").is_empty())
	check("quitar el halo", view.set_piece("base", "halo", false) and not view.is_on("base/halo"))


func _check_export(view) -> void:
	var path := OS.get_user_data_dir().path_join("piezas_prueba.glb")
	check("exportar con piezas", view.export_glb(path) == OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		check("el .glb se vuelve a leer", false)
		return
	var scene := document.generate_scene(state)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var names: Array = _without_eyes(meshes).map(func(m: MeshInstance3D) -> String: return m.name)
	# cuerpo + malla + casquete + 2 cuernos
	check("el .glb trae el cuerpo primero y 4 mallas de piezas, todas con piel", names.size() == 5 and names[0] == "Body"
		and meshes.all(func(m: MeshInstance3D) -> bool: return m.skin != null), str(names))
	var lowest := INF
	for m: MeshInstance3D in meshes:
		lowest = minf(lowest, m.get_aabb().position.y)
	check("nada por debajo del suelo más de 1 cm", lowest > -0.01, "%.4f" % lowest)  # PROVISIONAL
	scene.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_basename() + ".tres")


func _check_project(main: Control, view) -> void:
	var path := OS.get_user_data_dir().path_join("piezas_prueba.gmolde")
	var worn: Array = view.pieces.keys() + view.accessories.keys()
	worn.sort()
	check("guardar el proyecto", main.body_actions.save_preset(path) == OK)
	view.set_piece("base", "tights", false)
	view.set_piece("base", "cuernos", false)
	check("abrirlo sin error", main.body_actions.open_preset(path) == "")
	var back: Array = view.pieces.keys() + view.accessories.keys()
	back.sort()
	check("vuelven las mismas piezas", back == worn, str(back))
	check("la pestaña Ropa marca las mallas", main.piece_panels["Ropa"].buttons["base/tights"].button_pressed)
	DirAccess.remove_absolute(path)


## Paso AC.6b: las mallas del .glb sin las de los ojos.
func _without_eyes(meshes: Array) -> Array:
	return meshes.filter(func(m: MeshInstance3D) -> bool: return not m.name in EYE_MESHES)


## Paso PE.4b: el pelo con movimiento en el editor.
func _check_hair_physics(main: Control, view) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	var base := skeleton.get_bone_count()
	check("PE.4b: poner bob02", view.set_piece("makehuman", "bob02", true))
	var key := "makehuman/bob02"
	var simulator: SpringBoneSimulator3D = view.hair_physics.get(key)
	check("PE.4b: bob02 lleva simulador y cadenas", simulator != null and simulator.get_parent() == skeleton
		and skeleton.get_bone_count() > base, "%d huesos" % skeleton.get_bone_count())
	_check_hair_export(view, skeleton, key, base)
	check("PE.5: exportar con bob02 deja .glb, .tres y .tscn", _exported_files(view) == [true, true, true])
	var reports: Array[Dictionary] = view.check_report()
	var errors := reports.filter(func(r: Dictionary) -> bool: return r["nivel"] == "error")
	check("PE.4b: con cadenas, el informe no tiene errores", errors.is_empty(), str(errors.map(func(r: Dictionary) -> String: return r["id"])))
	for clip: String in ["atacar", view.ROM_ID]:
		view.set_animation(clip)
		for f in 20:
			await process_frame
		view.set_piece("makehuman", "bob02", false)
		for f in 5:
			await process_frame
		check("PE.4b: quitar bob02 con «%s» deja los huesos del cuerpo" % clip, skeleton.get_bone_count() == base
			and view.hair_physics.is_empty() and skeleton.find_children("*", "SpringBoneSimulator3D", false, false).is_empty())
		view.set_piece("makehuman", "bob02", true)
		for f in 5:
			await process_frame
	view.set_animation("")
	view.set_piece("makehuman", "bob02", false)
	check("PE.4b: al final, los huesos del cuerpo", skeleton.get_bone_count() == base)
	view.set_piece("quaternius", "hair_buzzed", true)
	check("PE.4b: el rapado no lleva cadenas", view.hair_physics.is_empty() and skeleton.get_bone_count() == base,
		"%d huesos" % skeleton.get_bone_count())
	check("PE.5: exportar con el rapado no deja .tscn", _exported_files(view) == [true, true, false])
	view.set_piece("quaternius", "hair_buzzed", false)


## Paso PE.5: exporta con el editor y dice qué hay: [.glb, .tres, .tscn]; luego los borra.
func _exported_files(view) -> Array:
	var path := OS.get_user_data_dir().path_join("pe5_prueba.glb")
	view.export_glb(path)
	var found := []
	for file: String in [path, path.get_basename() + ".tres", path.get_basename() + ".tscn"]:
		found.append(FileAccess.file_exists(file))
		DirAccess.remove_absolute(file)
	return found


## Paso PE.5: el .glb con los huesos de pelo del editor (nombre y padre) y la piel del peinado en ellos; en pose A, el
## peinado como el mismo sin cadenas. En pose T solo se mide la distancia.
func _check_hair_export(view, skeleton: Skeleton3D, key: String, base: int) -> void:
	var baker: GDScript = load(ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador/character_baker.gd").simplify_path())
	var plain: MeshInstance3D = BodyPiece.attach(view.library.load_piece("makehuman", "bob02"), skeleton)
	BodyPiece.follow(plain, view.species.mesh)
	for t_pose: bool in [false, true]:
		var with_chains: Node3D = baker.bake(view.species.mesh, skeleton, t_pose, false, [view.pieces[key]])
		var without: Node3D = baker.bake(view.species.mesh, skeleton, t_pose, false, [plain])
		var a_skeleton: Skeleton3D = with_chains.find_children("*", "Skeleton3D", true, false)[0]
		var b_skeleton: Skeleton3D = without.find_children("*", "Skeleton3D", true, false)[0]
		var a: PackedVector3Array = MeshBaker.bake(a_skeleton.get_child(1), a_skeleton)["vertices"]
		var b: PackedVector3Array = MeshBaker.bake(b_skeleton.get_child(1), b_skeleton)["vertices"]
		var worst := 0.0
		for i in mini(a.size(), b.size()):
			worst = maxf(worst, a[i].distance_to(b[i]))
		var pose := "T" if t_pose else "A"
		print("  MEDIDA PE.4b: en pose %s, el peinado exportado con cadenas a %.4f mm de sin ellas" % [pose, worst * 1000.0])
		if t_pose:
			var family := func(s: Skeleton3D) -> Array:  # [hueso, padre] de cada x_pelo_*
				return range(s.get_bone_count()).filter(func(b: int) -> bool: return s.get_bone_name(b).begins_with("x_pelo_")).map(
					func(b: int) -> Array: return [s.get_bone_name(b), s.get_bone_name(s.get_bone_parent(b))])
			check("PE.5: el .glb lleva los huesos de pelo del editor", a_skeleton.get_bone_count() > base
				and family.call(a_skeleton) == family.call(skeleton), "%d" % a_skeleton.get_bone_count())
			var hair_skin: Skin = (a_skeleton.get_child(1) as MeshInstance3D).skin
			var valid: bool = hair_skin != null and hair_skin.get_bind_count() == (view.pieces[key] as MeshInstance3D).skin.get_bind_count()
			var on_chain := 0
			for i in hair_skin.get_bind_count() if hair_skin != null else 0:
				var bone := hair_skin.get_bind_bone(i)
				valid = valid and bone >= 0 and bone < a_skeleton.get_bone_count()
				on_chain += int(valid and a_skeleton.get_bone_name(bone).begins_with("x_pelo_"))
			check("PE.5: la piel del peinado exportado apunta a huesos que existen, también x_pelo_*", valid and on_chain > 0, "%d" % on_chain)
		else:
			check("PE.5: exportar con cadenas da lo mismo que sin ellas (pose A)", a.size() == b.size()
				and worst * 1000.0 <= 0.1, "%.4f mm" % (worst * 1000.0))
		with_chains.free()
		without.free()
	BodyPiece.detach(plain)
