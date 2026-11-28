extends SceneTree
# Paso 13.3c: PieceImport lee un .glb ajeno, lo aplana en partes, lo escala y lo guarda como pack propio (D59). Los .glb
# se fabrican aquí (cajas), sin assets; escribe solo en user://importar_pieza, que borra al acabar, y deja la espada de
# prueba en pruebas/capturas/13.3/espada_prueba.glb (para el juicio visual de 13.3f).
# Paso 13.3d: BodyView pone una pieza importada (aquí también escribe en user://packs una carpeta propia_*, que borra).
# Paso 13.3e: guardada y abierta como proyecto .gmolde (ProjectIO) y exportada en el .glb desde socket_hand_r.
# Uso: (prlimit --as=4096000000 timeout 120 godot --headless --path pruebas/godot -s probar_importar_pieza.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en PieceImport._append, no invertir los triángulos con determinante < 0 -> falla «el nodo
# reflejado mira hacia fuera». En BodyView._set_accessory, pintar siempre con library.color_of(card) -> falla «13.3d:
# cada malla con su color». En PackLibrary.piece_file, no mirar el sha256 -> falla «13.3d: archivo cambiado: no se pone».
# En ProjectIO.worn_pieces, guardar siempre «principal» -> falla «13.3e: al abrir, vuelven los dos colores».
# En ProjectIO.build, no mirar unbuilt_pieces -> falla «13.3e: archivo cambiado, la conserva al volver a guardar».
# Mide (MEDIDA) cuánto tarda read con 100.000 triángulos.

const PieceImport := preload("res://../../godot/addons/creador/piece_import.gd")
const PackLibrary := preload("res://../../godot/addons/creador/pack_library.gd")
const RigidPiece := preload("res://../../godot/addons/creador/rigid_piece.gd")
const USER_PACKS := "user://packs"  # donde la vista lee los del usuario (13.3d)
const CHOSEN := Color(0.1, 0.6, 0.3)  # un color elegido a mano (13.3d)
const DIR := "user://importar_pieza"
const PACKS := "user://importar_pieza/packs"
const CAPTURE := "res://../capturas/13.3/espada_prueba.glb"
const COLOR_MAX := 1.0 / 255.0  # aprobado (2026-11-28, 13.3c): diferencia de color tras leer
const BOX_MAX := 1e-5  # aprobado (2026-11-28, 13.3c): metros de diferencia en la caja
const TIME_MAX := 2.0  # aprobado (2026-11-28, 13.3c): segundos para leer 100.000 triángulos
const PLACE_MAX := 1e-6  # PROVISIONAL (13.3e): cada uno de los 8 números de la colocación al abrir
const HAND_WEIGHT_MAX := 0.001  # PROVISIONAL (13.3e): lo que le falta a un vértice exportado para pesar 1 en RightHand
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
	await _check_wear()
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
		worst = maxf(worst, _color_gap(parts[k]["color"], colors[k]))
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


# --- 13.3d: poner la pieza ---

func _check_wear() -> void:
	var view = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/body_view.gd").simplify_path()).new()
	root.add_child(view)
	await process_frame
	check("13.3d: la vista carga", view.error == "", view.error)
	if view.error == "":
		_check_imported(view)
	view.free()


func _check_imported(view) -> void:
	var had_packs := DirAccess.dir_exists_absolute(USER_PACKS)
	var id := _save_dagger()
	if id == "":
		return
	var heard := []
	view.packs_changed.connect(func() -> void: heard.append(true))
	view.rescan_packs()
	var card: Dictionary = view.library.piece(id, id)
	check("13.3d: rescan_packs la encuentra y avisa (packs_changed)", not card.is_empty() and heard.size() == 1)
	check("13.3d: is_rigid: la importada y el halo sí; las mallas y {} no", RigidPiece.is_rigid(card)
			and RigidPiece.is_rigid(view.library.piece("base", "halo"))
			and not RigidPiece.is_rigid(view.library.piece("base", "tights")) and not RigidPiece.is_rigid({}))
	_check_worn(view, id)
	_check_generated_color(view)
	_check_project(view, id)
	_check_bad_file(view, id)
	_remove_tree(USER_PACKS.path_join(id))
	if not had_packs:
		DirAccess.remove_absolute(USER_PACKS)
	check("13.3d: la pieza de prueba borrada de user://packs", not DirAccess.dir_exists_absolute(USER_PACKS.path_join(id)))


## Una pieza de dos partes (mango y hoja) guardada en user://packs: su id, o "" si falla.
func _save_dagger() -> String:
	var dagger := Node3D.new()
	_add_box(dagger, Vector3(0.03, 0.15, 0.03), Vector3.ZERO, _material(GRIP))
	_add_box(dagger, Vector3(0.05, 0.3, 0.01), Vector3(0, 0.25, 0), _material(BLADE))
	var r := PieceImport.read(_write("daga.glb", dagger))
	var saved := PieceImport.save(r["partes"], META, USER_PACKS)
	check("13.3d: pieza de dos colores guardada en user://packs", r["error"] == "" and saved["error"] == "",
			str(r["error"], " ", saved["error"]))
	return saved["pack"]


func _check_worn(view, id: String) -> void:
	var key := id.path_join(id)
	check("13.3d: se pone", view.set_piece(id, id, true) and view.is_on(key))
	var holder: BoneAttachment3D = view.accessories.get(key)
	var meshes: Array = view.meshes_of(key)
	check("13.3d: 2 mallas en el hueso del anclaje", meshes.size() == 2 and holder.bone_name == "socket_hand_r"
			and holder.get_parent() == view.species.skeleton and meshes[0].name == id + "_m0" and meshes[1].name == id + "_m1",
			str(meshes.size()))
	if meshes.size() != 2:
		return
	check("13.3d: cada malla con su color", _painted(meshes[0], GRIP) and _painted(meshes[1], BLADE)
			and holder.has_meta("own_colors"))
	var place := RigidPiece.to_place([0.02, -0.01, 0.05, 0.36, 0.48, 0.64, 0.48, 1.3])
	check("13.3d: set_place la mueve", RigidPiece.set_place(holder, "RightHand", place) and holder.bone_name == "RightHand"
			and meshes.all(func(m: MeshInstance3D) -> bool: return m.transform.is_equal_approx(place)))
	view.set_piece_color(key, CHOSEN)
	check("13.3d: un color elegido pinta las dos y quita own_colors", _painted(meshes[0], CHOSEN)
			and _painted(meshes[1], CHOSEN) and not holder.has_meta("own_colors"))
	check("13.3d: se quita", view.set_piece(id, id, false) and not view.is_on(key) and view.meshes_of(key).is_empty())
	var again: bool = view.set_piece(id, id, true)
	meshes = view.meshes_of(key)
	check("13.3d: otra vez puesta, con sus colores y en su anclaje", again and meshes.size() == 2 and _painted(meshes[0], GRIP)
			and _painted(meshes[1], BLADE) and view.accessories[key].bone_name == "socket_hand_r")
	view.set_piece(id, id, false)


## El accesorio de generador sigue igual: sin own_colors, y elegir su color no da errores.
func _check_generated_color(view) -> void:
	var on: bool = view.set_piece("base", "halo", true)
	view.set_piece_color("base/halo", CHOSEN)
	check("13.3d: el halo se pone sin own_colors y se pinta", on and not view.accessories["base/halo"].has_meta("own_colors")
			and view.piece_color("base/halo").is_equal_approx(CHOSEN))
	view.set_piece("base", "halo", false)


## Con el archivo cambiado (otro .glb válido), roto (sin sha256 en la ficha) o borrado, no se pone ni queda nada colgado.
func _check_bad_file(view, id: String) -> void:
	var folder := USER_PACKS.path_join(id)
	var path := folder.path_join("pieza.glb")
	var children: int = view.species.skeleton.get_child_count()
	DirAccess.copy_absolute(DIR.path_join("espada.glb"), path)
	check("13.3d: archivo cambiado: no se pone", not view.set_piece(id, id, true) and not view.is_on(id.path_join(id))
			and view.library.piece_file(id, id) == "")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("pack.json")))
	data["piezas"][0]["sha256"] = ""
	_write_text(folder.path_join("pack.json"), JSON.stringify(data))
	_write_text(path, "esto no es un glb")
	view.rescan_packs()
	check("13.3d: archivo roto sin sha256: no se pone", view.library.piece_file(id, id) != ""
			and not view.set_piece(id, id, true))
	DirAccess.remove_absolute(path)
	check("13.3d: sin archivo: no se pone", view.library.piece_file(id, id) == "" and not view.set_piece(id, id, true))
	check("13.3d: nada colgado de más en el esqueleto", view.species.skeleton.get_child_count() == children)


## Los dos colores del material de la malla son color.
func _painted(mesh: MeshInstance3D, color: Color) -> bool:
	var material := mesh.material_override as ShaderMaterial
	return ["skin_color", "garment_color"].all(func(part: String) -> bool:
		return _color_gap(material.get_shader_parameter(part), color) <= COLOR_MAX)


# --- 13.3e: proyecto y exportación ---

## Con sus colores en socket_hand_r y con un color elegido en socket_back; el .glb, desde el proyecto abierto; al final,
## sin la carpeta de la pieza (se aparta y se devuelve).
func _check_project(view, id: String) -> void:
	var io: GDScript = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/project_io.gd").simplify_path())
	var key := id.path_join(id)
	var path := DIR.path_join("daga.gmolde")
	if not view.set_piece(id, id, true):
		check("13.3e: se pone", false)
		return
	var own := _round_trip(view, io, path, key, "socket_hand_r", [0.02, -0.01, 0.05, 0.36, 0.48, 0.64, 0.48, 1.3])
	if own.is_empty():
		return
	var meshes: Array = view.meshes_of(key)
	check("13.3e: el proyecto no guarda color de una pieza con sus colores", own["entrada"]["colores"] == {},
			str(own["entrada"]["colores"]))
	check("13.3e: al abrir, vuelven los dos colores", meshes.size() == 2 and _painted(meshes[0], GRIP)
			and _painted(meshes[1], BLADE) and view.accessories[key].has_meta("own_colors"))
	_check_export(view, id)
	view.set_piece_color(key, CHOSEN)
	var chosen := _round_trip(view, io, path, key, "socket_back", [-0.03, 0.04, -0.02, 0.5, 0.5, 0.5, 0.5, 0.8])
	if chosen.is_empty():
		return
	meshes = view.meshes_of(key)
	check("13.3e: el color elegido se guarda y vuelve", chosen["entrada"]["colores"].has("principal") and meshes.size() == 2
			and _painted(meshes[0], CHOSEN) and _painted(meshes[1], CHOSEN) and not view.accessories[key].has_meta("own_colors"),
			str(chosen["entrada"]["colores"]))
	_check_missing(view, io, path, id, chosen["entrada"])
	_check_changed(view, io, path, id, chosen["entrada"])


## Coloca la pieza, guarda, la quita y abre: mismo hueso y 8 números. {entrada: la del archivo}, o {} si falla.
func _round_trip(view, io: GDScript, path: String, key: String, bone: String, numbers: Array) -> Dictionary:
	var placed := RigidPiece.set_place(view.accessories[key], bone, RigidPiece.to_place(numbers))
	var wanted := RigidPiece.to_array(RigidPiece.get_place(view.accessories[key]))
	var written: Error = io.write(path, io.build(path, view, view.values, {}))
	view.set_piece(key.get_base_dir(), key.get_file(), false)
	var loaded: Dictionary = io.read(path, view)
	check("13.3e: %s: guardar y leer el proyecto" % bone, placed and written == OK and loaded["error"] == "", loaded["error"])
	if not placed or written != OK or loaded["error"] != "":
		return {}
	var entries: Array = loaded["proyecto"]["personajes"][0]["piezas"]
	var warnings: Array[String] = io.wear_pieces(view, entries)
	var on: bool = view.accessories.has(key)
	check("13.3e: %s: se abre sin avisos, con la pieza puesta" % bone, warnings.is_empty() and entries.size() == 1 and on,
			str(warnings))
	if entries.size() != 1 or not on:
		return {}
	var found := RigidPiece.to_array(RigidPiece.get_place(view.accessories[key]))
	var gap := 0.0
	for k: int in 8:
		gap = maxf(gap, absf(found[k] - wanted[k]))
	print("  MEDIDA 13.3e: %s, diferencia de colocación %.9f" % [bone, gap])
	check("13.3e: %s: mismo hueso y 8 números" % bone, view.accessories[key].bone_name == bone and gap <= PLACE_MAX,
			str(view.accessories[key].bone_name, " ", found))
	return {"entrada": entries[0]}


## El .glb de la pieza en socket_hand_r: sus 2 mallas al 100 % de RightHand, cada una con su color.
func _check_export(view, id: String) -> void:
	var path := DIR.path_join("daga_puesta.glb")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if view.export_glb(path) != OK or document.append_from_file(path, state) != OK:
		check("13.3e: exportar y volver a leer el .glb", false)
		return
	var scene := document.generate_scene(state)
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var colors := [GRIP, BLADE]
	for k: int in 2:
		var part := scene.find_child("%s_m%d" % [id, k], true, false) as MeshInstance3D
		var skinned := part != null and part.skin != null and part.skin.get_bind_count() > 0
		check("13.3e: el .glb trae la malla %d con piel" % k, skinned)
		if not skinned:
			continue
		var missing := _missing_weight(part, skeleton, skeleton.find_bone("RightHand"))
		print("  MEDIDA 13.3e: malla %d, peso que falta en RightHand %.6f" % [k, missing])
		check("13.3e: la malla %d va al 100 %% en RightHand" % k, missing <= HAND_WEIGHT_MAX, "%.6f" % missing)
		var color: Color = (part.mesh.surface_get_material(0) as BaseMaterial3D).albedo_color
		check("13.3e: la malla %d sale con su color" % k, _color_gap(color, colors[k]) <= COLOR_MAX, str(color))
	scene.free()


## Lo que le falta a algún vértice para pesar 1 en bone (el peor).
func _missing_weight(instance: MeshInstance3D, skeleton: Skeleton3D, bone: int) -> float:
	var arrays := instance.mesh.surface_get_arrays(0)
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / count
	var worst := 0.0
	for v: int in count:
		var on := 0.0
		for k: int in range(v * per, (v + 1) * per):
			if weights[k] <= 0.0:
				continue
			var named := instance.skin.get_bind_name(bones[k])
			var bound := instance.skin.get_bind_bone(bones[k]) if named == &"" else skeleton.find_bone(named)
			on += weights[k] if bound == bone else 0.0
		worst = maxf(worst, absf(1.0 - on))
	return worst


## Como en otro equipo: sin la carpeta, abrir avisa y al volver a guardar la entrada sigue igual.
func _check_missing(view, io: GDScript, path: String, id: String, entry: Dictionary) -> void:
	var folder := USER_PACKS.path_join(id)
	var aside := DIR.path_join("apartada")
	view.set_piece(id, id, false)
	DirAccess.rename_absolute(folder, aside)
	view.rescan_packs()
	var loaded: Dictionary = io.read(path, view)
	var warnings: Array[String] = io.wear_pieces(view, loaded["proyecto"]["personajes"][0]["piezas"])
	check("13.3e: sin la carpeta, avisa y no la pone", view.library.piece(id, id).is_empty() and warnings.size() == 1
			and id in warnings[0] and not view.is_on(id.path_join(id)), str(warnings))
	var written: Error = io.write(path, io.build(path, view, view.values, loaded["proyecto"]))
	var again: Dictionary = io.read(path, view)
	var kept: Array = again["proyecto"]["personajes"][0]["piezas"] if again["error"] == "" else []
	check("13.3e: sin la carpeta, la conserva al volver a guardar", written == OK and kept == [entry], str(kept))
	DirAccess.rename_absolute(aside, folder)
	view.rescan_packs()


## Con la pieza en la biblioteca pero su archivo cambiado: abrir avisa y al volver a guardar la entrada sigue igual.
func _check_changed(view, io: GDScript, path: String, id: String, entry: Dictionary) -> void:
	var file := USER_PACKS.path_join(id).path_join("pieza.glb")
	var original := FileAccess.get_file_as_bytes(file)
	_write_text(file, "esto no es un glb")
	var loaded: Dictionary = io.read(path, view)
	var warnings: Array[String] = io.wear_pieces(view, loaded["proyecto"]["personajes"][0]["piezas"])
	check("13.3e: archivo cambiado, avisa y no la pone", not view.library.piece(id, id).is_empty() and warnings.size() == 1
			and not view.is_on(id.path_join(id)), str(warnings))
	var written: Error = io.write(path, io.build(path, view, view.values, loaded["proyecto"]))
	var again: Dictionary = io.read(path, view)
	var kept: Array = again["proyecto"]["personajes"][0]["piezas"] if again["error"] == "" else []
	check("13.3e: archivo cambiado, la conserva al volver a guardar", written == OK and kept == [entry], str(kept))
	var restored := FileAccess.open(file, FileAccess.WRITE)
	restored.store_buffer(original)
	restored.close()


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


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _color_gap(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _box_error(a: AABB, b: AABB) -> float:
	var d := ((a.position - b.position).abs()).max((a.size - b.size).abs())
	return maxf(d.x, maxf(d.y, d.z))


func _remove_tree(folder: String) -> void:
	for name: String in DirAccess.get_directories_at(folder):
		_remove_tree(folder.path_join(name))
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
