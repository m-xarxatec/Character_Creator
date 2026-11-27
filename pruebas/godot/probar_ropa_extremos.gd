extends SceneTree
# Paso 12.1a: cuánta piel asoma por la ropa con el cuerpo en los extremos de los deslizadores (godot/app/main.gd).
# Por prenda, caso y zona: «asoma» (piel por fuera de la primera tela; en el .glb se ve hasta 12.5), «visible» (asoma más
# que el adelanto de AB.6, PIECE_PULL × capa: se ve en el editor) y «destapada» (la tela se va de la piel; aparte).
# Sin ventana.
# Uso: (ulimit -v 4000000; timeout 600 godot --headless --path pruebas/godot -s probar_ropa_extremos.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en BodyPiece.follow, quitar ShapeWeights.apply -> falla «… no deja ver piel» en weight 1 o gender 1.

const MeshBaker := preload("res://../../godot/addons/creador/mesh_baker.gd")
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
const VISIBLE_MAX := 0  # PROVISIONAL (2026-11-27): vértices visibles en el editor; el objetivo de la fase
const ASOMA_MAX := 30.0  # aprobado (2026-11-27): % de la piel tapada que asoma; medido 28,3 % (traje: 23,9 % ya en neutro), 19,1 % sin él
const WORST := 5

var failures := 0


func _initialize() -> void:
	var begin := Time.get_ticks_msec()
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
	main.free()
	print("  MEDIDA tiempo: %d s" % ((Time.get_ticks_msec() - begin) / 1000))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


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
		garments.append({"id": key.get_file(), "mesh": mesh, "tris": tris, "covered": covered, "zones": zones, "pull": pull,
			"results": [], "spots": {}})
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


## Un caso: cuenta la piel tapada que asoma, la visible en el editor y la destapada, y el pico de lo que asoma.
func _measure(garment: Dictionary, label: String, body: Dictionary, skeleton: Skeleton3D, bones: PackedStringArray) -> void:
	var covered: PackedInt32Array = garment["covered"]
	var cloth: PackedVector3Array = MeshBaker.bake(garment["mesh"], skeleton)["vertices"]
	var heights := Cloth.cloth_heights(body["vertices"], body["normals"], covered, cloth, garment["tris"], BELOW, ABOVE, CELL)
	var result := {"case": label, "over": 0, "visible": 0, "bare": 0, "peak": 0.0}
	for k in covered.size():
		var h := heights[k]
		if not is_finite(h):
			result["bare"] += 1
		elif h < 0.0:
			result["over"] += 1
			result["peak"] = maxf(result["peak"], -h)
			var spot := "%s/%s" % [label, bones[covered[k]]]
			garment["spots"][spot] = garment["spots"].get(spot, 0) + 1
			if h < -garment["pull"]:
				result["visible"] += 1
	garment["results"].append(result)
	if label == "neutro":
		print("  MEDIDA %s en neutro: asoma %d, visible %d, destapada %d" % [garment["id"], result["over"], result["visible"], result["bare"]])


func _report(garment: Dictionary) -> void:
	var id: String = garment["id"]
	var total: int = maxi(garment["covered"].size(), 1)
	var worst: Dictionary = {}
	var too_visible := []
	var too_over := []
	var top_share := 0.0
	for result: Dictionary in garment["results"]:
		top_share = maxf(top_share, 100.0 * result["over"] / total)
		if worst.is_empty() or result["visible"] > worst["visible"] or (result["visible"] == worst["visible"]
				and result["over"] > worst["over"]):
			worst = result
		if result["visible"] > VISIBLE_MAX:
			too_visible.append(result["case"])
		if 100.0 * result["over"] / total > ASOMA_MAX:
			too_over.append(result["case"])
	if worst.is_empty():
		return
	print("  MEDIDA %s: peor caso %s: asoma %d (%.2f %%), visible %d, destapada %d, pico %.1f mm; asoma hasta %.2f %% (%d vértices tapados, %d casos)" % [
		id, worst["case"], worst["over"], 100.0 * worst["over"] / total, worst["visible"], worst["bare"], worst["peak"] * 1000,
		top_share, total, garment["results"].size()])
	var spots: Array = garment["spots"].keys()
	spots.sort_custom(func(a: String, b: String) -> bool: return garment["spots"][a] > garment["spots"][b])
	print("  MEDIDA %s: peores (caso/zona) %s" % [id, ", ".join(PackedStringArray(spots.slice(0, WORST).map(
		func(spot: String) -> String: return "%s %d" % [spot, garment["spots"][spot]])))])
	check("12.1a: %s no deja ver piel en el editor (visible ≤ %d)" % [id, VISIBLE_MAX], too_visible.is_empty(),
		"%d casos: %s" % [too_visible.size(), ", ".join(PackedStringArray(too_visible))])
	check("12.1a: %s deja asomar ≤ %.2f %% de la piel tapada" % [id, ASOMA_MAX], too_over.is_empty(),
		"%d casos: %s" % [too_over.size(), ", ".join(PackedStringArray(too_over))])


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
