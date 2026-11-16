extends SceneTree
# Paso 12.1: transferir formas y pesos del cuerpo a una prenda (shape_transfer.gd). Sin ventana y sin datos/.
# Uso: godot --headless --path pruebas/godot -s <ruta a este archivo> 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
# Busca shape_transfer.gd en godot/addons/creador/ y, si no está, en ruta/codigo/nucleo/ (borrador).
# Cuerpo de juguete: un tubo ancho (torso, radio 0,15) y, a 3 cm, un tubo fino (brazo). Prenda: un tubo de radio 0,17
# alrededor del torso. Los vértices de la prenda que miran al brazo están a 2 cm del torso y a 1 cm del brazo:
# es la trampa de la axila.
# Que detecta el fallo: (1) en shape_transfer.gd, poner MIN_FACING := -2.0 -> falla «ningún vértice se ata al brazo»;
# (2) en follow, quitar el término `frame.z * offsets[g].z` -> fallan «gordo» y «piel que asoma».

const MAX_MM := 1.0  # PROVISIONAL (D26). El tubo tiene caras planas: su superficie se aparta hasta 0,3 mm del cilindro ideal
const EXACT_MM := 0.01  # PROVISIONAL (D26)
const TORSO_RADIUS := 0.15
const GARMENT_RADIUS := 0.17
const ARM_X := 0.23
const ARM_RADIUS := 0.05
const REACH := 0.05

var failures := 0
var transfer: GDScript
var body: Dictionary
var garment: Dictionary
var torso_vertices := 0
var torso_triangles := 0
var body_bones := PackedInt32Array()
var body_weights := PackedFloat32Array()
var shapes := {}
var bound: Dictionary


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	for folder: String in ["godot/addons/creador", "ruta/codigo/nucleo"]:
		var path := root_dir.path_join(folder).path_join("shape_transfer.gd")
		if transfer == null and FileAccess.file_exists(path):
			transfer = load(path)
	if transfer == null:
		print("ERROR: no se encuentra shape_transfer.gd")
		quit(1)
		return
	_make_scene()
	_check_closest()
	var start := Time.get_ticks_msec()
	bound = transfer.bind(body["vertices"], body["normals"], body["indices"], garment["vertices"], garment["normals"], REACH)
	print("  MEDIDA bind: %d vértices de prenda contra %d triángulos de cuerpo en %d ms"
		% [garment["vertices"].size(), body["indices"].size() / 3, Time.get_ticks_msec() - start])
	_check_bind()
	_check_shapes()
	_check_weights()
	_check_covered()
	_check_unbound()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Tubo abierto a lo largo de Y. phase gira los vértices para que no coincidan con los de otro tubo.
func _tube(center_x: float, radius: float, low: float, high: float, sides: int, rings: int, phase := 0.0) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in rings + 1:
		for j in sides:
			var angle := TAU * j / sides + phase
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			vertices.append(Vector3(center_x, lerpf(low, high, float(r) / rings), 0.0) + radial * radius)
			normals.append(radial)
	for r in rings:
		for j in sides:
			var a := r * sides + j
			var b := r * sides + (j + 1) % sides
			indices.append_array(PackedInt32Array([a, b, a + sides, b, b + sides, a + sides]))
	return {"vertices": vertices, "normals": normals, "indices": indices}


func _make_scene() -> void:
	var torso := _tube(0.0, TORSO_RADIUS, 0.0, 1.0, 48, 20)
	var arm := _tube(ARM_X, ARM_RADIUS, 0.3, 0.9, 16, 12)
	torso_vertices = torso["vertices"].size()
	torso_triangles = torso["indices"].size() / 3
	var vertices: PackedVector3Array = torso["vertices"]
	var normals: PackedVector3Array = torso["normals"]
	var indices: PackedInt32Array = torso["indices"]
	vertices.append_array(arm["vertices"])
	normals.append_array(arm["normals"])
	for index: int in arm["indices"]:
		indices.append(index + torso_vertices)
	body = {"vertices": vertices, "normals": normals, "indices": indices}
	garment = _tube(0.0, GARMENT_RADIUS, 0.2, 0.8, 40, 15, 0.03)

	# Pesos: el torso pasa del hueso 0 (abajo) al hueso 1 (arriba) entre y = 0,4 y 0,6. El brazo es del hueso 2.
	var fat := PackedVector3Array()
	var tall := PackedVector3Array()
	var arm_only := PackedVector3Array()
	for i in vertices.size():
		var v := vertices[i]
		var is_torso := i < torso_vertices
		var upper := clampf((v.y - 0.4) / 0.2, 0.0, 1.0)
		body_bones.append_array(PackedInt32Array([0, 1, 0, 0] if is_torso else [2, 0, 0, 0]))
		body_weights.append_array(PackedFloat32Array([1.0 - upper, upper, 0.0, 0.0] if is_torso else [1.0, 0.0, 0.0, 0.0]))
		fat.append(Vector3(v.x * 0.3, 0.0, v.z * 0.3) if is_torso else Vector3(0.045, 0.0, 0.0))
		tall.append(Vector3(0.0, v.y * 0.2, 0.0))
		arm_only.append(Vector3.ZERO if is_torso else Vector3(0.1, 0.0, 0.0))
	shapes = {"gordo": fat, "alto": tall, "brazo": arm_only}


func _moved_body(shape: String) -> PackedVector3Array:
	var moved: PackedVector3Array = (body["vertices"] as PackedVector3Array).duplicate()
	var deltas: PackedVector3Array = shapes[shape]
	for i in moved.size():
		moved[i] += deltas[i]
	return moved


func _radius(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _check_closest() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(1, 0, 0)
	var c := Vector3(0, 1, 0)
	var cases := [
		[Vector3(0.25, 0.25, 3.0), Vector3(0.5, 0.25, 0.25), "encima del interior"],
		[Vector3(-1, -1, 0.5), Vector3(1, 0, 0), "más allá del vértice a"],
		[Vector3(2, -1, 0), Vector3(0, 1, 0), "más allá del vértice b"],
		[Vector3(-0.5, 3, 0), Vector3(0, 0, 1), "más allá del vértice c"],
		[Vector3(0.5, -2, 0), Vector3(0.5, 0.5, 0), "frente al lado a-b"],
		[Vector3(-2, 0.25, 0), Vector3(0.75, 0, 0.25), "frente al lado a-c"],
		[Vector3(1, 1, 0), Vector3(0, 0.5, 0.5), "frente al lado b-c"],
	]
	var ok := true
	var detail := ""
	for row: Array in cases:
		var got: Vector3 = transfer.closest_weights(row[0], a, b, c)
		if not got.is_equal_approx(row[1]):
			ok = false
			detail += "%s: %s; " % [row[2], got]
	check("closest_weights: interior, los tres vértices y los tres lados", ok, detail)
	var flat: Vector3 = transfer.closest_weights(Vector3(1, 1, 1), a, a, a)
	check("closest_weights: un triángulo sin área no da números raros", is_finite(flat.x) and is_equal_approx(flat.x + flat.y + flat.z, 1.0))


func _check_bind() -> void:
	var triangles: PackedInt32Array = bound["triangles"]
	var offsets: PackedVector3Array = bound["offsets"]
	check("bind: todos los vértices atados y ninguno dudoso", bound["unbound"].is_empty() and bound["doubtful"].is_empty(),
		"%d sin atar, %d dudosos" % [bound["unbound"].size(), bound["doubtful"].size()])
	var on_arm := 0
	var worst := 0.0
	var sideways := 0.0
	for g in triangles.size():
		if triangles[g] >= torso_triangles:
			on_arm += 1
		worst = maxf(worst, 1000.0 * absf(offsets[g].z - (GARMENT_RADIUS - TORSO_RADIUS)))
		sideways = maxf(sideways, 1000.0 * Vector2(offsets[g].x, offsets[g].y).length())
	check("bind (axila): ningún vértice se ata al brazo, aunque esté más cerca", on_arm == 0, "%d atados al brazo" % on_arm)
	check("bind: cada vértice queda 2 cm por encima de la piel (± %s mm)" % MAX_MM, worst < MAX_MM, "%.4f mm" % worst)
	check("bind: sin desplazamiento de lado (el punto más cercano está justo debajo) (± %s mm)" % MAX_MM, sideways < MAX_MM,
		"%.4f mm" % sideways)
	var rest: PackedVector3Array = transfer.follow(bound, garment["vertices"], body["vertices"], body["indices"])
	var error := 0.0
	for g in rest.size():
		error = maxf(error, 1000.0 * rest[g].distance_to(garment["vertices"][g]))
	check("follow con el cuerpo sin mover devuelve la prenda tal cual (< %s mm)" % EXACT_MM, error < EXACT_MM, "%.6f mm" % error)


func _check_shapes() -> void:
	var start := Time.get_ticks_msec()
	var deltas: Dictionary = transfer.transfer_shapes(bound, garment["vertices"], body["vertices"], body["indices"], shapes)
	print("  MEDIDA transfer_shapes: %d formas en %d ms" % [shapes.size(), Time.get_ticks_msec() - start])
	check("la forma que solo mueve el brazo no se guarda; las otras dos sí", deltas.size() == 2 and deltas.has("gordo")
		and deltas.has("alto") and not deltas.has("brazo"), str(deltas.keys()))
	if not deltas.has("gordo") or not deltas.has("alto"):
		return
	var rest: PackedVector3Array = garment["vertices"]
	var fat: PackedVector3Array = deltas["gordo"]
	var tall: PackedVector3Array = deltas["alto"]
	var radius_error := 0.0
	var height_error := 0.0
	var tall_error := 0.0
	var tall_radius := 0.0
	var inside := 0
	for g in rest.size():
		var fat_point := rest[g] + fat[g]
		radius_error = maxf(radius_error, 1000.0 * absf(_radius(fat_point) - (TORSO_RADIUS * 1.3 + 0.02)))
		height_error = maxf(height_error, 1000.0 * absf(fat_point.y - rest[g].y))
		if _radius(fat_point) <= TORSO_RADIUS * 1.3:
			inside += 1
		var tall_point := rest[g] + tall[g]
		tall_error = maxf(tall_error, 1000.0 * absf(tall_point.y - rest[g].y * 1.2))
		tall_radius = maxf(tall_radius, 1000.0 * absf(_radius(tall_point) - GARMENT_RADIUS))
	check("gordo: la prenda queda 2 cm por encima del torso ensanchado (± %s mm)" % MAX_MM, radius_error < MAX_MM, "%.4f mm" % radius_error)
	check("gordo: ningún vértice de la prenda queda dentro de la piel", inside == 0, "%d dentro" % inside)
	check("gordo: la prenda no sube ni baja (< %s mm)" % MAX_MM, height_error < MAX_MM, "%.4f mm" % height_error)
	check("alto: la prenda se estira 1,2 en altura (± %s mm) y no cambia de radio" % MAX_MM, tall_error < MAX_MM and tall_radius < MAX_MM,
		"%.4f mm, %.4f mm" % [tall_error, tall_radius])
	var half: PackedVector3Array = (garment["vertices"] as PackedVector3Array).duplicate()
	for g in half.size():
		half[g] += fat[g] * 0.5
	var half_error := 0.0
	for g in half.size():
		half_error = maxf(half_error, 1000.0 * absf(_radius(half[g]) - (TORSO_RADIUS * 1.15 + 0.02)))
	check("gordo al 50 % (como lo mezcla la tarjeta): sigue 2 cm por encima (± %s mm)" % MAX_MM, half_error < MAX_MM, "%.4f mm" % half_error)


func _check_weights() -> void:
	var skin: Dictionary = transfer.transfer_weights(bound, body["indices"], body_bones, body_weights)
	var bones: PackedInt32Array = skin["bones"]
	var weights: PackedFloat32Array = skin["weights"]
	var rest: PackedVector3Array = garment["vertices"]
	check("pesos: 4 por vértice de la prenda", bones.size() == 4 * rest.size() and weights.size() == 4 * rest.size())
	var sum_error := 0.0
	var blend_error := 0.0
	var arm_weight := 0.0
	var ordered := true
	for g in rest.size():
		var total := 0.0
		var upper := 0.0
		for k in range(4 * g, 4 * g + 4):
			total += weights[k]
			if bones[k] == 1:
				upper += weights[k]
			if bones[k] == 2:
				arm_weight = maxf(arm_weight, weights[k])
			if k > 4 * g:
				ordered = ordered and weights[k] <= weights[k - 1]
		sum_error = maxf(sum_error, absf(total - 1.0))
		blend_error = maxf(blend_error, absf(upper - clampf((rest[g].y - 0.4) / 0.2, 0.0, 1.0)))
	check("pesos: suman 1 y van de mayor a menor", sum_error < 0.00001 and ordered, "%.7f" % sum_error)
	check("pesos: la mezcla entre los dos huesos del torso sigue la altura (± 0,01)", blend_error < 0.01, "%.5f" % blend_error)
	check("pesos: nada del hueso del brazo", arm_weight == 0.0)

	# Un triángulo cuyos vértices suman 6 huesos distintos: se quedan los 4 mayores y vuelven a sumar 1.
	var one := {"triangles": PackedInt32Array([0]), "weights": PackedVector3Array([Vector3(0.5, 0.3, 0.2)])}
	var six_bones := PackedInt32Array([10, 11, 0, 0, 12, 13, 0, 0, 14, 15, 0, 0])
	var six_weights := PackedFloat32Array([0.9, 0.1, 0, 0, 0.6, 0.4, 0, 0, 0.5, 0.5, 0, 0])
	var mixed: Dictionary = transfer.transfer_weights(one, PackedInt32Array([0, 1, 2]), six_bones, six_weights)
	# pesos mezclados: 10 = 0,45; 12 = 0,18; 13 = 0,12; 14 = 0,10; 15 = 0,10; 11 = 0,05 -> quedan 10, 12, 13 y 14 (suma 0,85)
	var kept: PackedInt32Array = mixed["bones"]
	var kept_weights: PackedFloat32Array = mixed["weights"]
	check("pesos: de 6 huesos se quedan los 4 mayores (10, 12, 13, 14)", kept == PackedInt32Array([10, 12, 13, 14]), str(kept))
	check("pesos: y se dividen por su suma", absf(kept_weights[0] - 0.45 / 0.85) < 0.0001
		and absf(kept_weights[0] + kept_weights[1] + kept_weights[2] + kept_weights[3] - 1.0) < 0.00001)


func _check_covered() -> void:
	var vertices: PackedVector3Array = body["vertices"]
	var start := Time.get_ticks_msec()
	var mask: PackedByteArray = transfer.covered(vertices, body["normals"], garment["vertices"], garment["normals"], garment["indices"], 0.03)
	print("  MEDIDA covered: %d vértices de cuerpo en %d ms" % [vertices.size(), Time.get_ticks_msec() - start])
	var wrong := 0
	var covered_count := 0
	for i in vertices.size():
		covered_count += mask[i]
		var is_torso := i < torso_vertices
		if is_torso and vertices[i].y > 0.21 and vertices[i].y < 0.79 and mask[i] == 0:
			wrong += 1  # debajo de la prenda y sin tapar
		if is_torso and (vertices[i].y < 0.19 or vertices[i].y > 0.81) and mask[i] == 1:
			wrong += 1  # fuera de la prenda y tapado
		if not is_torso and mask[i] == 1:
			wrong += 1  # el brazo nunca está tapado por la camiseta del torso
	check("covered: tapa el torso bajo la prenda, y nada del resto ni del brazo", wrong == 0 and covered_count > 100,
		"%d mal, %d tapados" % [wrong, covered_count])

	var fat_body := _moved_body("gordo")
	var deltas: Dictionary = transfer.transfer_shapes(bound, garment["vertices"], vertices, body["indices"], {"gordo": shapes["gordo"]})
	var fat_garment: PackedVector3Array = (garment["vertices"] as PackedVector3Array).duplicate()
	if deltas.has("gordo"):
		for g in fat_garment.size():
			fat_garment[g] += (deltas["gordo"] as PackedVector3Array)[g]
	var with_transfer: int = transfer.poking(mask, fat_body, body["normals"], fat_garment, garment["normals"], garment["indices"], 0.03)
	check("piel que asoma con la forma transferida: 0 vértices", with_transfer == 0, "%d" % with_transfer)
	var without: int = transfer.poking(mask, fat_body, body["normals"], garment["vertices"], garment["normals"], garment["indices"], 0.03)
	check("piel que asoma si la prenda NO sigue al cuerpo: todos los tapados (la medida detecta el fallo)", without == covered_count,
		"%d de %d" % [without, covered_count])


## Un vértice lejos de todo queda sin atar, se avisa y no se mueve.
func _check_unbound() -> void:
	var vertices: PackedVector3Array = (garment["vertices"] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (garment["normals"] as PackedVector3Array).duplicate()
	vertices.append(Vector3(3, 3, 3))
	normals.append(Vector3.UP)
	var last := vertices.size() - 1
	var loose: Dictionary = transfer.bind(body["vertices"], body["normals"], body["indices"], vertices, normals, REACH)
	check("vértice lejano: sale en «unbound» con triángulo −1", loose["unbound"] == PackedInt32Array([last])
		and loose["triangles"][last] == -1, str(loose["unbound"]))
	var moved: PackedVector3Array = transfer.follow(loose, vertices, _moved_body("gordo"), body["indices"])
	check("vértice lejano: follow lo deja donde estaba", moved[last] == Vector3(3, 3, 3))
	var skin: Dictionary = transfer.transfer_weights(loose, body["indices"], body_bones, body_weights)
	check("vértice lejano: peso 1 en el hueso 0 (para que la malla sea válida)", skin["bones"][4 * last] == 0
		and skin["weights"][4 * last] == 1.0 and skin["weights"][4 * last + 1] == 0.0)
