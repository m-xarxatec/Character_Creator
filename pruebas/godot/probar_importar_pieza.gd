extends SceneTree
# Paso 13.3c: PieceImport lee un .glb ajeno, lo aplana en partes, lo escala y lo guarda como pack propio (D59). Los .glb
# se fabrican aquí (cajas), sin assets; escribe solo en user://importar_pieza, que borra al acabar, y deja la espada de
# prueba en pruebas/capturas/13.3/espada_prueba.glb (para el juicio visual de 13.3f).
# Uso: (prlimit --as=4096000000 timeout 120 godot --headless --path pruebas/godot -s probar_importar_pieza.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en PieceImport._append, no invertir los triángulos con determinante < 0 -> falla «el nodo
# reflejado mira hacia fuera».
# Mide (MEDIDA) cuánto tarda read con 100.000 triángulos.

const PieceImport := preload("res://../../godot/addons/creador/piece_import.gd")
const PackLibrary := preload("res://../../godot/addons/creador/pack_library.gd")
const DIR := "user://importar_pieza"
const PACKS := "user://importar_pieza/packs"
const CAPTURE := "res://../capturas/13.3/espada_prueba.glb"
const COLOR_MAX := 1.0 / 255.0  # aprobado (2026-11-28, 13.3c): diferencia de color tras leer
const BOX_MAX := 1e-5  # aprobado (2026-11-28, 13.3c): metros de diferencia en la caja
const TIME_MAX := 2.0  # aprobado (2026-11-28, 13.3c): segundos para leer 100.000 triángulos
const GRIP := Color(0.35, 0.1, 0.05)
const BLADE := Color(0.7, 0.72, 0.75)
const POMMEL := Color(1.0, 0.9, 0.6)  # con textura
const TEXTURE_SIZE := Vector2i(4, 2)
## Empuñadura en el origen; hoja arriba; guarda de dos mitades (la izquierda, reflejada con escala -1 en X); pomo abajo.
const SWORD_BOX := AABB(Vector3(-0.1, -0.115, -0.02), Vector3(0.2, 0.915, 0.04))
const SWORD_TRIANGLES := 60  # 5 cajas
const META := {"nombre": "Espada de prueba", "autor": "", "origen": "", "especie": "humana", "hueso": "socket_hand_r"}

var failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(PACKS)
	var path := _write("espada.glb", _sword())
	_copy_capture(path)
	var r := PieceImport.read(path)
	check("la espada se lee", r["error"] == "", r["error"])  # avisos: los de GlbInspect por lo que añade el exportador de Godot
	if r["error"] == "":
		_check_parts(r, "leída: ")
		_check_mirror(r["partes"])
		_check_fit(r)
		_check_save(r)
	_check_far_origin()
	_measure_heavy()
	_remove_tree(DIR)
	check("user://importar_pieza borrada", not DirAccess.dir_exists_absolute(DIR))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


# --- Casos ---

func _check_parts(r: Dictionary, label: String, box := SWORD_BOX) -> void:
	var parts: Array = r["partes"]
	check(label + "3 partes (una por material), en orden de aparición", parts.size() == 3, str(parts.size()))
	if parts.size() != 3:
		return
	var colors := [GRIP, BLADE, POMMEL]
	var worst := 0.0
	for k: int in 3:
		var color: Color = parts[k]["color"]
		worst = maxf(worst, maxf(absf(color.r - colors[k].r), maxf(absf(color.g - colors[k].g), absf(color.b - colors[k].b))))
	check(label + "colores a 1/255", worst <= COLOR_MAX, "peor %.5f" % worst)
	var image: Image = parts[2]["textura"]
	check(label + "el pomo trae su textura del mismo tamaño, con UV", image != null and image.get_size() == TEXTURE_SIZE
			and parts[2]["mesh"].surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] != null)
	check(label + "las partes sin textura no llevan UV", parts[0]["textura"] == null and parts[1]["textura"] == null
			and parts[0]["mesh"].surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] == null)
	check(label + "caja a 1e-5 m", _box_error(r["caja"], box) <= BOX_MAX, str(r["caja"]))
	check(label + "%d triángulos" % SWORD_TRIANGLES, r["triangulos"] == SWORD_TRIANGLES, str(r["triangulos"]))


## Todas las caras con el sentido de sus normales (en Godot, delantera en horario) y las normales de la mitad reflejada
## de la guarda hacia fuera de su caja.
func _check_mirror(parts: Array) -> void:
	var wrong := 0
	var inward := 0
	var seen := 0
	for part: Dictionary in parts:
		var arrays: Array = part["mesh"].surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for k: int in range(0, indices.size(), 3):
			var a := points[indices[k]]
			var face := (points[indices[k + 2]] - a).cross(points[indices[k + 1]] - a)
			if face.dot(normals[indices[k]]) <= 0.0:
				wrong += 1
		for k: int in points.size():
			if points[k].x < -0.05:  # mitad izquierda de la guarda (la hoja llega a -0,025; el pomo, a -0,02)
				seen += 1
				if normals[k].dot(points[k] - Vector3(-0.05, 0.0875, 0.0)) <= 0.0:
					inward += 1
	check("el nodo reflejado mira hacia fuera", wrong == 0 and inward == 0 and seen > 0,
		"%d caras al revés, %d de %d normales hacia dentro" % [wrong, inward, seen])


func _check_fit(r: Dictionary) -> void:
	check("scale_for: tamaño 0 o negativo, tal cual", PieceImport.scale_for(r["caja"], 0.0) == 1.0
			and PieceImport.scale_for(r["caja"], -1.0) == 1.0)
	var factor := PieceImport.scale_for(r["caja"], 0.9)
	var fitted := PieceImport.fit(r["partes"], factor)
	var box := PieceImport.box_of(fitted)
	check("fit a 0,90 m, con el origen en la empuñadura", absf(box.get_longest_axis_size() - 0.9) <= BOX_MAX
			and _box_error(box, AABB(SWORD_BOX.position * factor, SWORD_BOX.size * factor)) <= BOX_MAX, str(box))
	for bad: float in [0.0, NAN, INF, -1.0]:
		check("fit con factor %s: error" % bad, PieceImport.fit(r["partes"], bad).is_empty())


func _check_save(r: Dictionary) -> void:
	var parts := PieceImport.fit(r["partes"], PieceImport.scale_for(r["caja"], 0.9))
	var saved := PieceImport.save(parts, META, PACKS)
	var id: String = saved["pack"]
	check("save: sin error, id propia_<12 hex>", saved["error"] == "" and id == saved["pieza"] and id.begins_with("propia_")
			and id.length() == 19 and id.substr(7).is_valid_hex_number(), str(saved))
	if saved["error"] != "":
		return
	var library := PackLibrary.new()
	var warnings := library.scan(PackedStringArray([PACKS]))
	check("save + scan sin avisos", warnings.is_empty(), str(warnings))
	var cards := library.pieces("accesorio", "humana")
	check("la pieza sale en la biblioteca, en socket_hand_r", cards.size() == 1 and cards[0]["id"] == id
			and cards[0]["anclaje"]["hueso"] == "socket_hand_r" and cards[0]["sigue_al_cuerpo"] == false)
	if cards.size() == 1:
		check("licencia «propia» y autor «Sin indicar»", cards[0]["licencia"] == "propia"
				and cards[0]["autor"] == "Sin indicar", str(cards[0]["licencia"], " ", cards[0]["autor"]))
	var again := PieceImport.read(PACKS.path_join(id).path_join("pieza.glb"))
	check("read de lo guardado", again["error"] == "", again["error"])
	if again["error"] == "":
		_check_parts(again, "guardada: ", PieceImport.box_of(parts))
	var twice := PieceImport.save(parts, META, PACKS)
	check("guardar dos veces: mismo id, una carpeta", twice["pack"] == id and DirAccess.get_directories_at(PACKS).size() == 1)
	for name: Variant in ["", "   ", "x".repeat(61), "dos\nlíneas", null]:
		var meta := META.duplicate()
		meta["nombre"] = name
		var other := PieceImport.save(PieceImport.fit(parts, 0.5), meta, PACKS)
		check("nombre %s: error y nada escrito" % JSON.stringify(name), other["error"] != ""
				and DirAccess.get_directories_at(PACKS).size() == 1, other["error"])


func _check_far_origin() -> void:
	var root := Node3D.new()
	_add_box(root, Vector3(0.2, 0.2, 0.2), Vector3(5, 5, 5), _material(BLADE))
	var r := PieceImport.read(_write("lejos.glb", root))
	var box := PieceImport.box_of(PieceImport.fit(r["partes"], 1.0)) if r["error"] == "" else AABB()
	check("origen lejano: se centra", r["error"] == "" and box.get_center().length() <= BOX_MAX
			and absf(box.size.x - 0.2) <= BOX_MAX, str(box))


func _measure_heavy() -> void:
	var side := 224  # 224 × 224 cuadrados × 2 = 100.352 triángulos
	var points := PackedVector3Array()
	var indices := PackedInt32Array()
	for y: int in side + 1:
		for x: int in side + 1:
			points.append(Vector3(x, y, 0) * 0.001)
	for y: int in side:
		for x: int in side:
			var k := y * (side + 1) + x
			indices.append_array(PackedInt32Array([k, k + 1, k + side + 1, k + 1, k + side + 2, k + side + 1]))
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material(GRIP))
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	var path := _write("pesada.glb", root)
	var start := Time.get_ticks_usec()
	var r := PieceImport.read(path)
	var seconds := (Time.get_ticks_usec() - start) / 1e6
	print("MEDIDA read 100.000 triángulos: %.2f s" % seconds)
	check("100.000 triángulos: se leen en <= %.1f s" % TIME_MAX, r["error"] == "" and r["triangulos"] == side * side * 2
			and seconds <= TIME_MAX, str(r["error"], " ", r["triangulos"]))


# --- Fabricar .glb ---

func _sword() -> Node3D:
	var root := Node3D.new()
	var blade := _material(BLADE)
	_add_box(root, Vector3(0.03, 0.15, 0.03), Vector3.ZERO, _material(GRIP))
	_add_box(root, Vector3(0.05, 0.7, 0.01), Vector3(0, 0.45, 0), blade)
	_add_box(root, Vector3(0.1, 0.025, 0.03), Vector3(0.05, 0.0875, 0), blade)
	var mirrored := _add_box(root, Vector3(0.1, 0.025, 0.03), Vector3(0.05, 0.0875, 0), blade)
	mirrored.scale = Vector3(-1, 1, 1)
	var image := Image.create(TEXTURE_SIZE.x, TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.5, 0.2))
	var pommel := _material(POMMEL)
	pommel.albedo_texture = ImageTexture.create_from_image(image)
	_add_box(root, Vector3(0.04, 0.04, 0.04), Vector3(0, -0.095, 0), pommel)
	return root


## Caja con la geometría desplazada a center (el nodo queda en el origen).
func _add_box(root: Node3D, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k: int in points.size():
		points[k] += center
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


## Exporta la escena (y la libera) a DIR/file_name.
func _write(file_name: String, root: Node3D) -> String:
	for child: Node in root.get_children():
		child.owner = root
	var path := DIR.path_join(file_name)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_scene(root, state) != OK or document.write_to_filesystem(state, path) != OK:
		print("ERROR: no se puede escribir ", path)
	root.free()
	return path


func _copy_capture(path: String) -> void:
	var target := ProjectSettings.globalize_path(CAPTURE)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	DirAccess.copy_absolute(path, target)


func _box_error(a: AABB, b: AABB) -> float:
	var d := ((a.position - b.position).abs()).max((a.size - b.size).abs())
	return maxf(d.x, maxf(d.y, d.z))


func _remove_tree(folder: String) -> void:
	for name: String in DirAccess.get_directories_at(folder):
		_remove_tree(folder.path_join(name))
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
