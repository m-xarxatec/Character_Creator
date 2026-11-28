extends SceneTree
# Paso 13.3g (sin interfaz): quitar piezas de la biblioteca (D59 P4). Las propias (user://packs/propia_*) se borran de
# verdad; las demás se ocultan (lista en user://ajustes.cfg) y se restauran. Un proyecto que lleve una oculta o borrada
# avisa al abrir y la conserva. Sin ventana. Escribe en user://quitar_piezas, user://packs/propia_* y ajustes.cfg, y al
# acabar lo borra o lo deja como estaba. Los borrados que podrían salir mal se prueban con packs hechos aquí.
# Uso: (prlimit --as=4096000000 timeout 120 godot --headless --path pruebas/godot -s probar_quitar_piezas.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en PackLibrary.pieces, no mirar is_hidden -> falla «la oculta no sale en la lista». En
# BodyView.set_piece, no mirar is_hidden -> falla «oculta: no se pone». En ProjectIO.build, no mirar is_hidden -> falla
# «quitada con el proyecto abierto: se conserva». En PackLibrary._remove_tree, no mirar is_link -> falla «lo de detrás
# del enlace sigue». En PackLibrary.delete_own, no mirar is_own -> falla «una de serie no se borra».

const PackLibrary := preload("res://../../godot/addons/creador/pack_library.gd")
const PieceImport := preload("res://../../godot/addons/creador/piece_import.gd")
const SettingsFile := preload("res://../../godot/app/settings_file.gd")
const DIR := "user://quitar_piezas"
const SERIES := "user://quitar_piezas/serie"  # hace de res://packs
const OUTSIDE := "user://quitar_piezas/fuera"
const USER_PACKS := "user://packs"
const FAKE_OWN := "propia_prueba000001"  # pack propio hecho a mano, con cosas raras dentro
const HAND_MADE := "prueba_133g_mano"  # del usuario, pero no «propia_»: se oculta, no se borra
const META := {"nombre": "Pieza que se borra", "autor": "", "origen": "", "especie": "humana", "hueso": "socket_hand_r"}
const SERIES_KEYS := ["base/halo", "base/hair"]  # accesorio y pieza que sigue al cuerpo (origen del corte «melena»)

var failures := 0
var made: Array[String] = []  # carpetas creadas en user://packs


func _initialize() -> void:
	var had_settings := FileAccess.file_exists(SettingsFile.PATH)
	var settings := FileAccess.get_file_as_bytes(SettingsFile.PATH) if had_settings else PackedByteArray()
	var had_packs := DirAccess.dir_exists_absolute(USER_PACKS)
	DirAccess.make_dir_recursive_absolute(DIR)
	SettingsFile.restore_pieces()
	_check_settings()
	_check_library()
	await _check_view()
	for folder: String in made:
		_remove_tree(folder)
	if not had_packs:
		DirAccess.remove_absolute(USER_PACKS)
	_remove_tree(DIR)
	if had_settings:
		var file := FileAccess.open(SettingsFile.PATH, FileAccess.WRITE)
		file.store_buffer(settings)
		file.close()
	else:
		DirAccess.remove_absolute(SettingsFile.PATH)
	check("lo de la prueba, borrado", not DirAccess.dir_exists_absolute(DIR)
			and made.all(func(folder: String) -> bool: return not DirAccess.dir_exists_absolute(folder)))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


# --- La lista en los ajustes ---

func _check_settings() -> void:
	check("sin nada oculto: lista vacía", SettingsFile.get_hidden_pieces().is_empty())
	SettingsFile.set_grid(true)
	SettingsFile.hide_piece("base/halo")
	SettingsFile.hide_piece("base/halo")
	SettingsFile.hide_piece("no_hay/tal_pieza")
	check("ocultar dos veces no repite", SettingsFile.get_hidden_pieces()
			== PackedStringArray(["base/halo", "no_hay/tal_pieza"]), str(SettingsFile.get_hidden_pieces()))
	SettingsFile.restore_pieces()
	check("restaurar vacía la lista y deja los demás ajustes", SettingsFile.get_hidden_pieces().is_empty()
			and SettingsFile.get_grid())
	for bad: Variant in ["base/halo", 7, {"base/halo": true}, [3, null, ["x"]]]:
		_write_hidden(bad)
		check("lista rota %s: se ignora" % str(bad), SettingsFile.get_hidden_pieces().is_empty())
	_write_hidden([3, "base/halo"])
	check("de una lista a medias vale lo que es texto", SettingsFile.get_hidden_pieces() == PackedStringArray(["base/halo"]))
	SettingsFile.restore_pieces()


func _write_hidden(value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SettingsFile.PATH)
	config.set_value("piezas", "ocultas", value)
	config.save(SettingsFile.PATH)


# --- La biblioteca (solo packs hechos aquí) ---

func _check_library() -> void:
	_make_pack(SERIES.path_join("serie_prueba"), "serie_prueba", ["uno", "dos"])
	_make_pack(SERIES.path_join("propia_deserie0001"), "propia_deserie0001", ["x"])  # nombre de propia, pero de serie
	_make_user_pack(HAND_MADE)
	var own := _make_user_pack(FAKE_OWN)
	_write_text(own.path_join(".oculto"), "x")
	DirAccess.make_dir_recursive_absolute(own.path_join("sub/.mas"))
	_write_text(own.path_join("sub/.mas/algo"), "x")
	DirAccess.make_dir_recursive_absolute(OUTSIDE)
	_write_text(OUTSIDE.path_join("importante"), "x")
	var linker := DirAccess.open(own)
	var linked: Error = linker.create_link(ProjectSettings.globalize_path(OUTSIDE), own.path_join("enlace"))
	check("enlace de prueba creado", linked == OK and FileAccess.file_exists(own.path_join("enlace/importante")))
	var library := PackLibrary.new()
	var folders := PackedStringArray([SERIES, USER_PACKS])
	library.hidden = {"serie_prueba/uno": true, "no_hay/tal_pieza": true, "serie_prueba/ya_no_esta": true}
	var warnings := library.scan(folders)
	var ids := library.pieces().filter(func(c: Dictionary) -> bool: return c["pack"] == "serie_prueba") \
			.map(func(c: Dictionary) -> String: return c["id"])
	check("ids que no existen: sin avisos", warnings.is_empty(), str(warnings))
	check("la oculta no sale en la lista y la otra (nueva) sí", ids == ["dos"], str(ids))
	check("piece y piece_file sí dan la oculta", not library.piece("serie_prueba", "uno").is_empty()
			and library.piece_file("serie_prueba", "uno") != "" and library.is_hidden("serie_prueba", "uno"))
	check("is_own: solo la de user://packs/propia_*", library.is_own(FAKE_OWN) and not library.is_own("serie_prueba")
			and not library.is_own("propia_deserie0001") and not library.is_own(HAND_MADE) and not library.is_own("no_hay"))
	for id: String in ["serie_prueba", "propia_deserie0001", HAND_MADE]:
		var folder: String = library.packs[id]["carpeta"]
		check("una de serie no se borra (%s)" % id, library.delete_own(id) == ERR_UNAUTHORIZED
				and FileAccess.file_exists(folder.path_join("pack.json")) and library.packs.has(id))
	check("borrar un pack que no está: error", library.delete_own("no_hay") == ERR_UNAUTHORIZED)
	var deleted := library.delete_own(FAKE_OWN)
	check("la propia se borra con su carpeta entera", deleted == OK and not DirAccess.dir_exists_absolute(own)
			and not library.packs.has(FAKE_OWN), error_string(deleted))
	check("lo de detrás del enlace sigue", FileAccess.file_exists(OUTSIDE.path_join("importante")))
	library.scan(folders)
	check("al volver a leer ya no está", not library.packs.has(FAKE_OWN))


# --- La vista y el proyecto ---

func _check_view() -> void:
	var view = _new_view()
	await process_frame
	check("la vista carga", view.error == "", view.error)
	if view.error != "":
		view.free()
		return
	if view.library.is_own("base"):  # con esto mal, quitar una de serie borraría el pack del repositorio
		check("base no es propia", false)
		view.free()
		return
	var id := _save_own()
	if id == "":
		view.free()
		return
	view.rescan_packs()
	var io: GDScript = load(_repo("godot/app/project_io.gd"))
	var path := DIR.path_join("con_piezas.gmolde")
	var keys := SERIES_KEYS + [id.path_join(id)]
	var worn := keys.all(func(key: String) -> bool: return view.set_piece(key.get_base_dir(), key.get_file(), true))
	check("las tres puestas", worn)
	var project: Dictionary = io.build(path, view, view.values, {})
	check("proyecto guardado", io.write(path, project) == OK)
	var entries: Array = io.read(path, view)["proyecto"]["personajes"][0]["piezas"]
	_check_removing(view, id)
	var after: Dictionary = io.build(path, view, view.values, io.read(path, view)["proyecto"])
	check("quitada con el proyecto abierto: se conserva", _same(after["personajes"][0]["piezas"], entries),
			str(after["personajes"][0]["piezas"].size()))
	view.free()
	view = _new_view()  # como al volver a abrir el programa
	await process_frame
	_check_reopened(view, io, path, id, entries)
	view.free()


func _check_removing(view, id: String) -> void:
	var heard := []
	view.packs_changed.connect(func() -> void: heard.append(true))
	var folder := USER_PACKS.path_join(id)
	check("quitar una que no existe: error y nada", view.remove_piece("base", "no_esta") != "" and heard.is_empty()
			and SettingsFile.get_hidden_pieces().is_empty())
	for key: String in SERIES_KEYS:
		var error: String = view.remove_piece(key.get_base_dir(), key.get_file())
		check("quitar %s: se oculta y se desviste" % key, error == "" and not view.is_on(key)
				and key in SettingsFile.get_hidden_pieces(), error)
		check("oculta: no se pone (%s)" % key, not view.set_piece(key.get_base_dir(), key.get_file(), true)
				and not view.is_on(key))
		check("oculta: no sale en la lista (%s)" % key, not _listed(view, key))
	check("los archivos de serie siguen", view.library.piece_file("base", "hair") != "")
	check("el recorte de una oculta sí se pone (melena, de hair)", view.set_piece("base", "melena", true))
	view.set_piece("base", "melena", false)
	var error: String = view.remove_piece(id, id)
	check("quitar la propia: se borra y se desviste", error == "" and not view.is_on(id.path_join(id))
			and not DirAccess.dir_exists_absolute(folder) and view.library.piece(id, id).is_empty(), error)
	check("la borrada no va a la lista de ocultas", not id.path_join(id) in SettingsFile.get_hidden_pieces())
	check("cada cambio avisa (packs_changed)", heard.size() == 3, str(heard.size()))


func _check_reopened(view, io: GDScript, path: String, id: String, entries: Array) -> void:
	check("tras reiniciar sigue oculta", view.library.is_hidden("base", "halo") and not _listed(view, "base/halo")
			and _listed(view, "base/cuernos"))
	var loaded: Dictionary = io.read(path, view)
	var warnings: Array[String] = io.wear_pieces(view, loaded["proyecto"]["personajes"][0]["piezas"])
	var hidden := warnings.filter(func(w: String) -> bool: return "está oculta" in w)
	var missing := warnings.filter(func(w: String) -> bool: return w.begins_with("falta la pieza " + id))
	check("al abrir avisa: 2 ocultas y 1 que falta", warnings.size() == 3 and hidden.size() == 2 and missing.size() == 1,
			str(warnings))
	check("y no pone ninguna", view.pieces.is_empty() and view.accessories.is_empty())
	var saved: Dictionary = io.build(path, view, view.values, loaded["proyecto"])
	check("al volver a guardar, las tres siguen igual", _same(saved["personajes"][0]["piezas"], entries),
			str(saved["personajes"][0]["piezas"]))
	view.restore_pieces()
	check("restaurar: vuelven a la lista", SettingsFile.get_hidden_pieces().is_empty() and _listed(view, "base/halo")
			and _listed(view, "base/hair") and view.library.piece(id, id).is_empty())
	warnings = io.wear_pieces(view, io.read(path, view)["proyecto"]["personajes"][0]["piezas"])
	check("restauradas: se ponen y solo falta la borrada", warnings.size() == 1 and view.is_on("base/halo")
			and view.is_on("base/hair"), str(warnings))


## Las mismas entradas, en cualquier orden.
func _same(a: Array, b: Array) -> bool:
	return a.size() == b.size() and b.all(func(entry: Dictionary) -> bool: return entry in a)


func _listed(view, key: String) -> bool:
	return view.library.pieces().any(func(c: Dictionary) -> bool: return String(c["pack"]).path_join(c["id"]) == key)


func _new_view():
	var view = load(_repo("godot/app/body_view.gd")).new()
	root.add_child(view)
	return view


func _repo(path: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("../..").path_join(path).simplify_path()


# --- Fabricar packs ---

## Una pieza propia de verdad (PieceImport.save) en user://packs: su id, o "" si falla.
func _save_own() -> String:
	var arrays := BoxMesh.new().get_mesh_arrays()
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var color := Color(0.123, 0.456, 0.789)
	var saved := PieceImport.save([{"mesh": mesh, "color": color, "textura": null}], META, USER_PACKS)
	check("pieza propia guardada", saved["error"] == "", saved["error"])
	if saved["pack"] != "":
		made.append(USER_PACKS.path_join(saved["pack"]))
	return saved["pack"]


func _make_user_pack(id: String) -> String:
	var folder := USER_PACKS.path_join(id)
	made.append(folder)
	_make_pack(folder, id, ["p"])
	return folder


func _make_pack(folder: String, id: String, pieces: Array) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	_write_text(folder.path_join("pieza.glb"), "x")
	var cards := pieces.map(func(piece: String) -> Dictionary:
		return {"id": piece, "tipo": "accesorio", "ranura": "accesorio", "archivo": "pieza.glb"})
	_write_text(folder.path_join("pack.json"), JSON.stringify({"formato": PackLibrary.FORMAT, "version": 1, "id": id,
		"nombre": id, "autor": "prueba", "licencia": "propia", "piezas": cards}))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Limpieza de la prueba; de un enlace, solo el enlace.
func _remove_tree(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.include_hidden = true
	for name: String in dir.get_directories():
		if not dir.is_link(folder.path_join(name)):
			_remove_tree(folder.path_join(name))
		else:
			DirAccess.remove_absolute(folder.path_join(name))
	for name: String in dir.get_files():
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
