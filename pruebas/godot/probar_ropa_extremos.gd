extends SceneTree
# Pasos 12.1a y 12.1b: cuánta piel asoma por la ropa con el cuerpo en los extremos de los deslizadores (godot/app/main.gd).
# Por prenda, caso y zona: «asoma» (piel por fuera de la primera tela, oculta o no; en el .glb se ve hasta 12.5), «oculta»
# (la máscara puesta en el editor no la dibuja), «hueco» (la oculta la máscara de la prenda, no tiene su tela por la normal
# y se ve a través desde fuera: algún rayo de la sonda, PROBE_TILTS × PROBE_TURNS + la normal, no cruza su prenda) y,
# solo en la no oculta, «visible» (asoma más que el adelanto de AB.6, PIECE_PULL × capa) y «destapada» (la tela se va de
# la piel; aparte). «Banda»: la piel tapada que queda sin ocultar, o sea la que «visible» sigue midiendo. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 600 godot --headless --path pruebas/godot -s probar_ropa_extremos.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en BodyPiece.follow, quitar ShapeWeights.apply -> falla «… no deja ver piel» en weight 1 o gender 1;
# sin _update_hide en BodyView.set_piece -> vuelve «visible» y «oculta» da 0; en SkinHide.union, todo oculto -> «hueco»;
# en Cloth.cloth_heights, Geometry3D.segment_intersects_triangle en vez de segment_hit -> falla «triángulos pequeños»; con Cloth.EDGE 0 -> «justo por una arista»;
# en Cloth.cloth_heights, mirar solo las celdas de puntos a media celda del rayo -> falla «esquina de celda»;
# sin el campo «oculta» de tights en godot/packs/base/pack.json -> falla «… corvas y codos»;
# _seen_through que siempre ve -> falla «la sonda del hueco».

const MeshBaker := preload("res://../../godot/addons/creador/mesh_baker.gd")
const BodyMaterial := preload("res://../../godot/addons/creador/body_material.gd")
const SkinHide := preload("res://../../godot/addons/creador/skin_hide.gd")
const Cloth := preload("medidas_tela.gd")
## Se ponen juntas (ranuras distintas): 2 camisetas y unos shorts de cada pipeline (MPFB y propio) y un traje entero.
const SETS := [["makehuman/elvs_crude_t-shirt_male", "makehuman/cortu_jeans_shorts"],
	["makehuman/joepal_crude_t-shirt_female", "overscore/os_short_shorts"],
	["overscore/os_tank_top", "overscore/os_golf_shorts"], ["makehuman/female_casualsuit01"]]
## Zonas de deslizadores que mueven la piel tapada por cada ranura (la cara y las manos no: triplicarían el tiempo).
const ZONES := {"ropa_torso": ["Global", "Cuello", "Hombros", "Torso", "Pecho", "Cintura", "Brazos", "Base"],
	"ropa_piernas": ["Global", "Cintura", "Caderas", "Glúteos", "Piernas", "Base"]}
const CORNERS := ["gender", "muscle", "weight"]
const RANDOM_BODIES := 10
const SEED := 12
const BELOW := 0.04  # metros: mayor que en RE.1c (0,02) para no contar como «destapada» la piel que asoma más de 2 cm
const ABOVE := 0.09
const CELL := 0.05
const HEM := 0.025
const HAND_BONES := ["Hand", "Thumb", "Index", "Middle", "Ring", "Little"]
const VISIBLE_MAX := 0  # aprobado (2026-11-28): vértices visibles en el editor; el objetivo de la fase
const ASOMA_MAX := 30.0  # aprobado (2026-11-27): % de la piel tapada que asoma; medido 28,3 % (traje: 23,9 % ya en neutro), 19,1 % sin él
const HUECO_MAX := 0  # aprobado (2026-11-27, ficha 12.1b): vértices ocultos por la prenda que se ven a través desde fuera
## Sonda del hueco (2026-11-28): rayos de PROBE_LENGTH desde BELOW por debajo de la piel, la normal y PROBE_TURNS más por
## cada inclinación (17); solo cuenta la tela de su prenda (la otra piel no tapa: el hueco deja ver el interior).
const PROBE_TILTS := [30.0, 60.0]  # grados desde la normal
const PROBE_TURNS := 8
const PROBE_LENGTH := 0.30  # metros
const WORST := 5
const SMALL_LEGS := [0.007, 0.005, 0.003, 0.001]  # metros: catetos del caso de la medida (los de Godot los perdía)
const HEIGHT_TOL := 0.00001  # PROVISIONAL: metros de error de la altura en ese caso
## La malla de cuerpo completo en poses dobladas: piel visible en corvas y codos (juicio visual de 12.1b-b4).
const FOLD_PIECE := "base/tights"
const FOLD_POSES := ["sentadilla", "sentarse"]
const FOLD_BONES := ["UpperLeg", "LowerLeg", "UpperArm", "LowerArm"]
const FOLD_VISIBLE_MAX := 8  # aprobado (2026-11-28): vértices; medido 8 (sentadilla) con su máscara, 169 sin ella

var failures := 0


func _initialize() -> void:
	var begin := Time.get_ticks_msec()
	_check_ray()
	_check_cell_corner()
	_check_probe()
	var main: Control = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/main.gd").simplify_path()).new()
	root.add_child(main)
	await process_frame
	var view = main.body_view
	var start: Dictionary = main.editor.values.duplicate()
	var hands := Cloth.hand_mask(view.species.mesh, view.species.skeleton, HAND_BONES)
	var bones := Cloth.main_bones(view.species.mesh, view.species.skeleton)
	for keys: Array in SETS:
		_check_set(main, view, keys, start, hands, bones)
	main.editor.load_values(start)
	_check_folds(view, hands, bones)
	main.free()
	print("  MEDIDA tiempo: %d s" % ((Time.get_ticks_msec() - begin) / 1000))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## La medida acierta triángulos pequeños: altura de un triángulo 10 mm sobre un vértice de piel (y 10 mm bajo otro), y
## nada si el rayo pasa por fuera. Y un rayo a 5 µm por fuera de la arista de un triángulo de 10 cm cuenta (holgura de
## segment_hit: sin ella se pierden los que pasan justo por una arista). Lejos del origen, como la ropa.
func _check_ray() -> void:
	var at := Vector3(0.123, 1.234, 0.087)
	var up := Vector3(0.2, 0.3, 1.0).normalized()
	var x := up.cross(Vector3.UP).normalized()
	var y := up.cross(x)
	var bad := []
	for leg: float in SMALL_LEGS:
		var inside := at + (x + y) * leg / 4.0
		var skin := PackedVector3Array([inside - up * 0.01, inside + up * 0.01, inside + x * leg * 2.0 - up * 0.01])
		var heights := Cloth.cloth_heights(skin, PackedVector3Array([up, up, up]), PackedInt32Array([0, 1, 2]),
			PackedVector3Array([at, at + x * leg, at + y * leg]), PackedInt32Array([0, 1, 2]), BELOW, ABOVE, CELL)
		if not (absf(heights[0] - 0.01) <= HEIGHT_TOL and absf(heights[1] + 0.01) <= HEIGHT_TOL and heights[2] == INF):
			bad.append("%d mm %s" % [roundi(leg * 1000), str(heights)])
	check("12.1b: la medida acierta triángulos pequeños (catetos de 1 a 7 mm)", bad.is_empty(), str(bad))
	var from := at + x * 0.05 - y * 0.000005 - up * 0.01
	var edge: Variant = Cloth.segment_hit(from, from + up * 0.02, at, at + x * 0.1, at + y * 0.1)
	check("12.1b: la medida cuenta un rayo justo por una arista", edge != null)


## La medida mira todas las celdas que cruza el rayo: un triángulo de 1 mm solo en una celda que el rayo corta por la
## esquina (entre 49 y 59 mm de su salida, con BELOW 0,04 y CELL 0,05: 14 mm sobre la piel).
func _check_cell_corner() -> void:
	var up := Vector3(1.0, 1.0, 0.0).normalized()
	var side := Vector3(-1.0, 1.0, 0.0).normalized()
	var from := Vector3(3.0 * CELL - up.x * 0.049, 25.0 * CELL - up.y * 0.059, 1.5 * CELL)
	var center := from + up * 0.054
	var tri := PackedVector3Array([center - (side + Vector3.BACK) * 0.001 / 3.0, center + (side * 2.0 - Vector3.BACK) * 0.001 / 3.0,
		center + (Vector3.BACK * 2.0 - side) * 0.001 / 3.0])
	var heights := Cloth.cloth_heights(PackedVector3Array([from + up * BELOW]), PackedVector3Array([up]), PackedInt32Array([0]),
		tri, PackedInt32Array([0, 1, 2]), BELOW, ABOVE, CELL)
	check("12.1b: la medida encuentra tela en una esquina de celda", absf(heights[0] - 0.014) <= HEIGHT_TOL, str(heights))


## La sonda: un punto 10 mm bajo un cuadrado de tela de 1 m no se ve; bajo uno de 2 cm (el rayo a 60° lo esquiva), sí;
## 10 mm por encima del de 1 m (la tela, dentro de BELOW), no; sin tela, sí.
func _check_probe() -> void:
	var at := Vector3(0.1, 1.2, 0.05)
	var up := Vector3.BACK
	var results := []
	for case: Array in [[0.5, -0.01, false], [0.01, -0.01, true], [0.5, 0.01, false], [0.0, -0.01, true]]:
		var half: float = case[0]
		var cloth := PackedVector3Array()
		var tris := PackedInt32Array()
		if half > 0.0:
			var c: Vector3 = at - up * case[1]
			cloth = PackedVector3Array([c + Vector3(-half, -half, 0), c + Vector3(half, -half, 0), c + Vector3(half, half, 0),
				c + Vector3(-half, half, 0)])
			tris = PackedInt32Array([0, 1, 2, 0, 2, 3])
		results.append(_seen_through(at, up, cloth, tris, Cloth.cloth_grid(cloth, tris, CELL)) == case[2])
	check("12.1b: la sonda del hueco ve lo destapado y no lo tapado", not results.has(false), str(results))


## Pone el conjunto, mide cada prenda en cada caso de sus zonas y la quita.
func _check_set(main: Control, view, keys: Array, start: Dictionary, hands: PackedByteArray, bones: PackedStringArray) -> void:
	main.editor.load_values(start)
	var skeleton: Skeleton3D = view.species.skeleton
	var body: Dictionary = MeshBaker.bake(view.species.mesh, skeleton)
	var garments: Array[Dictionary] = []
	var all_zones := {}
	for key: String in keys:
		check("12.1a: poner %s" % key, view.set_piece(key.get_base_dir(), key.get_file(), true))
		var mesh: MeshInstance3D = view.pieces.get(key)
		if mesh == null:
			continue
		var card: Dictionary = view.library.piece(key.get_base_dir(), key.get_file())
		var zones := {}
		for slot: String in [card["ranura"]] + Array(card.get("cubre", [])):  # un traje: la unión de sus ranuras
			for zone: String in ZONES.get(slot, []):
				zones[zone] = true
				all_zones[zone] = true
		var tris: PackedInt32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var covered := Cloth.covered_skin(body, MeshBaker.bake(mesh, skeleton)["vertices"], tris, hands, BELOW, ABOVE, CELL, HEM)
		check("12.1a: %s tapa piel" % key.get_file(), covered.size() > 0, str(covered.size()))
		var pull: float = (mesh.material_override as ShaderMaterial).get_shader_parameter("depth_pull")
		var image: Image = view.library.hide_image(key.get_base_dir(), key.get_file())
		var own := SkinHide.hidden_vertices(view.species.mesh, SkinHide.union([image] as Array[Image]))
		garments.append({"id": key.get_file(), "mesh": mesh, "tris": tris, "covered": covered, "zones": zones, "pull": pull,
			"own": own, "measured": _with_own(covered, own), "results": [], "spots": {}, "visible_spots": {}, "hole_spots": {},
			"by_bone": {"visible": {}, "hueco": {}}})
	# La máscara que tiene puesta el editor con el conjunto entero (la unión de sus prendas).
	var all_hidden := SkinHide.hidden_vertices(view.species.mesh, BodyMaterial.get_hide_mask(view.species.mesh))
	for garment: Dictionary in garments:
		garment["hidden"] = all_hidden
		garment["band"] = Array(garment["covered"]).filter(func(v: int) -> bool: return all_hidden[v] == 0).size()
	for case: Dictionary in _cases(main.editor.rows, start, all_zones):
		main.editor.load_values(case["values"])
		body = MeshBaker.bake(view.species.mesh, skeleton)
		for garment: Dictionary in garments:
			if case["zone"] == "" or garment["zones"].has(case["zone"]):
				_measure(garment, case["label"], body, skeleton, bones)
	main.editor.load_values(start)
	for garment: Dictionary in garments:
		_report(garment)
	for key: String in keys:
		view.set_piece(key.get_base_dir(), key.get_file(), false)


## Corvas y codos con FOLD_PIECE en FOLD_POSES: piel tapada (en neutro), no oculta y por fuera de la tela más que su
## adelanto. Solo los huesos de FOLD_BONES (en los pies la medida da piel por fuera que en pantalla no se ve).
func _check_folds(view, hands: PackedByteArray, bones: PackedStringArray) -> void:
	check("12.1b: poner %s" % FOLD_PIECE, view.set_piece(FOLD_PIECE.get_base_dir(), FOLD_PIECE.get_file(), true))
	var mesh: MeshInstance3D = view.pieces.get(FOLD_PIECE)
	if mesh == null:
		return
	var skeleton: Skeleton3D = view.species.skeleton
	var tris: PackedInt32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var covered := Cloth.covered_skin(MeshBaker.bake(view.species.mesh, skeleton), MeshBaker.bake(mesh, skeleton)["vertices"],
		tris, hands, BELOW, ABOVE, CELL, HEM)
	var hidden := SkinHide.hidden_vertices(view.species.mesh, BodyMaterial.get_hide_mask(view.species.mesh))
	var pull: float = (mesh.material_override as ShaderMaterial).get_shader_parameter("depth_pull")
	var worst := 0
	var found := []
	for pose: String in FOLD_POSES:
		view.set_animation(pose)
		var body: Dictionary = MeshBaker.bake(view.species.mesh, skeleton)
		var heights := Cloth.cloth_heights(body["vertices"], body["normals"], covered, MeshBaker.bake(mesh, skeleton)["vertices"],
			tris, BELOW, ABOVE, CELL)
		var visible := 0
		for k in covered.size():
			var v := covered[k]
			if hidden[v] == 0 and heights[k] < -pull and FOLD_BONES.any(func(part: String) -> bool: return part in bones[v]):
				visible += 1
		worst = maxi(worst, visible)
		found.append("%s %d" % [pose, visible])
	view.set_animation("")
	view.set_piece(FOLD_PIECE.get_base_dir(), FOLD_PIECE.get_file(), false)
	print("  MEDIDA %s en pliegues: piel visible %s" % [FOLD_PIECE, ", ".join(PackedStringArray(found))])
	check("12.1b: %s no deja ver piel en corvas y codos (≤ %d)" % [FOLD_PIECE, FOLD_VISIBLE_MAX], worst <= FOLD_VISIBLE_MAX,
		", ".join(PackedStringArray(found)))


## La piel tapada (primero: es el total de «asoma») y detrás la que oculta la máscara de la prenda fuera de ella.
func _with_own(covered: PackedInt32Array, own: PackedByteArray) -> PackedInt32Array:
	var extra := own.duplicate()
	for v in covered:
		extra[v] = 0
	var found := covered.duplicate()
	for v in extra.size():
		if extra[v] == 1:
			found.append(v)
	return found


## Un caso: la piel tapada que asoma (y su pico); de la oculta, los huecos; de la no oculta, la visible y la destapada.
func _measure(garment: Dictionary, label: String, body: Dictionary, skeleton: Skeleton3D, bones: PackedStringArray) -> void:
	var measured: PackedInt32Array = garment["measured"]
	var covered: int = garment["covered"].size()
	var cloth: PackedVector3Array = MeshBaker.bake(garment["mesh"], skeleton)["vertices"]
	var heights := Cloth.cloth_heights(body["vertices"], body["normals"], measured, cloth, garment["tris"], BELOW, ABOVE, CELL)
	var result := {"case": label, "over": 0, "visible": 0, "bare": 0, "peak": 0.0, "hidden": 0, "hole": 0}
	var grid := {}  # la de la sonda: solo se hace si algún oculto no tiene tela por la normal
	for k in measured.size():
		var v := measured[k]
		var h := heights[k]
		var spot := "%s/%s" % [label, bones[v]]
		if k < covered and h < 0.0:  # también la oculta: es lo que verá el .glb hasta 12.5
			result["over"] += 1
			result["peak"] = maxf(result["peak"], -h)
			_count(garment["spots"], spot)
		if garment["hidden"][v] == 1:
			result["hidden"] += 1
			if garment["own"][v] == 1 and not is_finite(h):
				if grid.is_empty():
					grid = Cloth.cloth_grid(cloth, garment["tris"], CELL)
				if _seen_through(body["vertices"][v], body["normals"][v].normalized(), cloth, garment["tris"], grid):
					result["hole"] += 1
					_count(garment["hole_spots"], spot)
					garment["by_bone"]["hueco"].get_or_add(bones[v], {})[v] = true
		elif not is_finite(h):
			result["bare"] += 1
		elif h < -garment["pull"]:
			result["visible"] += 1
			_count(garment["visible_spots"], spot)
			garment["by_bone"]["visible"].get_or_add(bones[v], {})[v] = true
	garment["results"].append(result)
	if label == "neutro":
		print("  MEDIDA %s en neutro: asoma %d, visible %d, destapada %d, oculta %d, hueco %d, banda %d" % [garment["id"],
			result["over"], result["visible"], result["bare"], result["hidden"], result["hole"], garment["band"]])


## La sonda: ¿algún rayo (la normal y PROBE_TURNS por cada PROBE_TILTS) sale sin cruzar la tela de su prenda?
func _seen_through(point: Vector3, normal: Vector3, cloth: PackedVector3Array, tris: PackedInt32Array, grid: Dictionary) -> bool:
	var side := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var directions: Array[Vector3] = [normal]
	for tilt: float in PROBE_TILTS:
		for turn in PROBE_TURNS:
			var across := side.rotated(normal, TAU * turn / PROBE_TURNS)
			directions.append(normal.rotated(across, deg_to_rad(tilt)))
	for direction: Vector3 in directions:
		var from := point - direction * BELOW
		var to := point + direction * PROBE_LENGTH
		var blocked := false
		var seen := {}
		for key: Vector3i in Cloth._box_cells(from, to, CELL):
			for t: int in grid.get(key, PackedInt32Array()):
				if blocked or seen.has(t):
					continue
				seen[t] = true
				blocked = Cloth.segment_hit(from, to, cloth[tris[3 * t]], cloth[tris[3 * t + 1]], cloth[tris[3 * t + 2]]) != null
			if blocked:
				break
		if not blocked:
			return true
	return false


func _count(spots: Dictionary, spot: String) -> void:
	spots[spot] = spots.get(spot, 0) + 1


## Los WORST (caso/zona) con más vértices, con su número.
func _worst_spots(spots: Dictionary) -> String:
	var keys: Array = spots.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return spots[a] > spots[b])
	return ", ".join(PackedStringArray(keys.slice(0, WORST).map(
		func(spot: String) -> String: return "%s %d" % [spot, spots[spot]])))


func _report(garment: Dictionary) -> void:
	var id: String = garment["id"]
	var total: int = maxi(garment["covered"].size(), 1)
	var worst: Dictionary = {}
	var too_visible := []
	var too_over := []
	var holed := []
	var top_share := 0.0
	var top_visible := 0
	var top_hole := 0
	for result: Dictionary in garment["results"]:
		top_share = maxf(top_share, 100.0 * result["over"] / total)
		top_visible = maxi(top_visible, result["visible"])
		top_hole = maxi(top_hole, result["hole"])
		if worst.is_empty() or [result["visible"], result["hole"], result["over"]] > [worst["visible"], worst["hole"], worst["over"]]:
			worst = result
		if result["visible"] > VISIBLE_MAX:
			too_visible.append(result["case"])
		if 100.0 * result["over"] / total > ASOMA_MAX:
			too_over.append(result["case"])
		if result["hole"] > HUECO_MAX:
			holed.append(result["case"])
	if worst.is_empty():
		return
	print("  MEDIDA %s: peor caso %s: asoma %d (%.2f %%), visible %d, destapada %d, pico %.1f mm; asoma hasta %.2f %% (%d vértices tapados, %d casos), oculta %d, hueco %d, banda %d" % [
		id, worst["case"], worst["over"], 100.0 * worst["over"] / total, worst["visible"], worst["bare"], worst["peak"] * 1000,
		top_share, total, garment["results"].size(), worst["hidden"], worst["hole"], garment["band"]])
	print("  MEDIDA %s: máximos en un caso: visible %d, hueco %d" % [id, top_visible, top_hole])
	for kind: String in ["visible", "hueco"]:  # vértices distintos en algún caso, por hueso: la lista para rehacer la prenda
		var found: Dictionary = garment["by_bone"][kind]
		if not found.is_empty():
			print("  MEDIDA %s: %s por hueso (vértices distintos) %s" % [id, kind, ", ".join(PackedStringArray(
				found.keys().map(func(bone: String) -> String: return "%s %d" % [bone, found[bone].size()])))])
	for kind: Array in [["asoma", "spots"], ["visible", "visible_spots"], ["hueco", "hole_spots"]]:
		if not garment[kind[1]].is_empty():
			print("  MEDIDA %s: peores %s (caso/zona) %s" % [id, kind[0], _worst_spots(garment[kind[1]])])
	check("12.1a: %s no deja ver piel en el editor (visible ≤ %d)" % [id, VISIBLE_MAX], too_visible.is_empty(),
		"%d casos: %s" % [too_visible.size(), ", ".join(PackedStringArray(too_visible))])
	check("12.1a: %s deja asomar ≤ %.2f %% de la piel tapada" % [id, ASOMA_MAX], too_over.is_empty(),
		"%d casos: %s" % [too_over.size(), ", ".join(PackedStringArray(too_over))])
	check("12.1b: %s sin huecos (piel oculta que se ve a través ≤ %d)" % [id, HUECO_MAX], holed.is_empty(),
		"%d casos: %s" % [holed.size(), ", ".join(PackedStringArray(holed))])
	check("12.1b: %s deja piel tapada sin ocultar que medir (banda > 0)" % id, garment["band"] > 0, str(garment["band"]))


## Casos: neutro (referencia: lo que ya asoma sin deformar), cada deslizador de las zonas en 1 (y en 0 si tiene decr), las 8 esquinas de CORNERS y RANDOM_BODIES al azar.
## «zone» vacía: el caso vale para todas las prendas del conjunto.
func _cases(rows: Array, start: Dictionary, zones: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = [{"label": "neutro", "zone": "", "values": start}]
	var chosen := rows.filter(func(row: Dictionary) -> bool: return zones.has(row["zona"]))
	for row: Dictionary in chosen:
		for value: float in ([1.0, 0.0] if row["decr"] != "" else [1.0]):
			found.append({"label": "%s %d" % [row["id"], value], "zone": row["zona"], "values": _with(start, row, value)})
	for corner in 8:
		var values := start.duplicate()
		var label := "esquina"
		for i in CORNERS.size():
			values[CORNERS[i]] = float((corner >> i) & 1)
			label += " %s %d" % [CORNERS[i], (corner >> i) & 1]
		found.append({"label": label, "zone": "", "values": values})
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in RANDOM_BODIES:
		var values := start.duplicate()
		for row: Dictionary in chosen:
			values = _with(values, row, rng.randf())
		found.append({"label": "azar %d" % i, "zone": "", "values": values})
	return found


## Copia de `values` con el deslizador de `row` (y sus dos lados) en `value`.
func _with(values: Dictionary, row: Dictionary, value: float) -> Dictionary:
	var edited := values.duplicate()
	for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
		if edited.has(row["id"] + side):
			edited[row["id"] + side] = value
	return edited
