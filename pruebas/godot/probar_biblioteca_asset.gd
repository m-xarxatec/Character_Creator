extends SceneTree
# TA.5a: biblioteca local del Taller (AssetStore), sin interfaz. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_biblioteca_asset.gd 2>&1 | grep -E 'FALLO|RESULTADO')
# Trabaja en user://ta5a_biblioteca (carpeta de este proyecto de pruebas) y la borra al terminar.
# Que detecta el fallo: no comprobar el hash de edicion.json -> falla «edicion.json con otra medida válida»;
# no devolver la pieza vieja si mover la nueva falla -> falla «un fallo al mover conserva la pieza».

const SWORD_A := {"longitud_m": 1.2, "ancho_hoja_m": 0.1, "grosor_m": 0.02, "escala_punta": 1.25}
const SWORD_B := {"longitud_m": 0.75, "ancho_hoja_m": 0.06, "grosor_m": 0.012, "escala_pomo": 0.75}
const OPTIONS := {"umbral_alfa": 0.4, "tolerancia": 0.2, "simplificacion": 1.5, "invertir": false}

var store_script: GDScript
var recipe: GDScript
var swords: GDScript
var mask: GDScript
var silhouette: GDScript
var library_script: GDScript
var base: String
var packs: String
var temp: String
var failures := 0


func _initialize() -> void:
	var core := ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador").simplify_path()
	store_script = load(core.path_join("taller_assets/asset_store.gd"))
	recipe = load(core.path_join("taller_assets/asset_recipe.gd"))
	swords = load(core.path_join("taller_assets/sword_generator.gd"))
	mask = load(core.path_join("taller_assets/image_mask.gd"))
	silhouette = load(core.path_join("taller_assets/silhouette_mesh.gd"))
	library_script = load(core.path_join("pack_library.gd"))
	base = ProjectSettings.globalize_path("user://ta5a_biblioteca")
	packs = base.path_join("packs")
	temp = base.path_join("temporal")
	for check_group: Callable in [_check_round_trip, _check_update, _check_names, _check_invalid, _check_damage,
			_check_edition_tamper, _check_source_lost, _check_failed_save, _check_interrupted, _check_foreign]:
		_remove(base)
		DirAccess.make_dir_recursive_absolute(packs)
		check_group.call()
	_remove(base)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


## Guardar, «cerrar» (otro AssetStore), abrir y regenerar dos espadas y una extrusión.
func _check_round_trip() -> void:
	var store = _store()
	var first := _sword_entry("Espada larga", SWORD_A, "#A01020")
	var second := _sword_entry("Daga", SWORD_B, "#20A040")
	var third := _image_entry("Silueta")
	third.miniatura = _thumbnail()
	var original_name: String = first.malla.surface_get_material(0).resource_name
	var ids := []
	for entry: Dictionary in [first, second, third]:
		var saved: Dictionary = store.save(entry)
		_check("guarda " + entry.nombre, saved.error == "", saved.error)
		ids.append(saved.get("id", ""))
	_check("no cambia la malla que recibe", first.malla.surface_get_material(0).resource_name == original_name)
	var reopened = _store()
	var listed: Dictionary = reopened.list()
	var names: Array = listed.piezas.map(func(card: Dictionary) -> String: return card.nombre)
	_check("lista las tres por nombre y sin avisos", names == ["Daga", "Espada larga", "Silueta"] and listed.avisos.is_empty(), str(names))
	for i in 3:
		var entry: Dictionary = [first, second, third][i]
		var opened: Dictionary = reopened.open(ids[i])
		_check("abre " + entry.nombre, opened.error == "" and opened.avisos.is_empty(), opened.error)
		if opened.error == "":
			_check(entry.nombre + ": malla idéntica", _same(opened.malla, entry.malla))
			_check(entry.nombre + ": mismos parámetros y colores", opened.receta.parametros == entry.receta_normal.parametros
				and opened.receta.colores == entry.receta_normal.colores and opened.nombre == entry.nombre)
	var image: Dictionary = reopened.open(ids[2])
	_check("la extrusión conserva contorno y ajustes", image.contorno == third.contorno and image.ajustes == OPTIONS)
	_check("la extrusión conserva su imagen", image.imagen != null and image.imagen.get_data() == _figure().get_data())
	var folder := packs.path_join(ids[2])
	_check("la imagen de origen va en fuentes/", FileAccess.file_exists(folder.path_join("fuentes/figura.png")))
	_check("guarda la miniatura y la lista la ve", FileAccess.file_exists(folder.path_join("pieza.png"))
		and listed.piezas[2].miniatura == folder.path_join("pieza.png"))
	_check("una pieza sin miniatura también vale", listed.piezas[0].miniatura == "")
	_check("no deja nada a medias", _files_in(temp).is_empty(), str(_files_in(temp)))
	_check_as_pack(ids)


func _check_as_pack(ids: Array) -> void:
	var library = library_script.new()
	var warnings: Array = library.scan(PackedStringArray([packs]))
	_check("PackLibrary acepta las tres", warnings.is_empty() and library.packs.size() == 3, str(warnings))
	_check("no salen en Accesorios hasta TA.6", library.pieces("accesorio", "humana").is_empty())
	var scene: Node3D = library.load_piece(ids[0], "pieza")
	var names := []
	if scene != null:
		var loaded: Mesh = scene.find_children("*", "MeshInstance3D", true, false)[0].mesh
		for i in loaded.get_surface_count():
			names.append(loaded.surface_get_material(i).resource_name)
		scene.free()
	_check("el .glb conserva las regiones", names == ["hoja", "guarda", "mango", "pomo"], str(names))


func _check_update() -> void:
	var store = _store()
	var id: String = store.save(_sword_entry("Espada", SWORD_A, "#A01020")).id
	var changed := _sword_entry("Espada", SWORD_B, "#112233")
	changed.reemplaza = id
	var saved: Dictionary = store.save(changed)
	_check("actualizar conserva el id", saved.get("id") == id, saved.error)
	_check("actualizar no crea otra pieza", store.list().piezas.size() == 1)
	_check("abre la versión nueva", _same(store.open(id).malla, changed.malla))
	var renamed := _sword_entry("Espada nueva", SWORD_B, "#112233")
	renamed.reemplaza = id
	_check("una pieza se puede renombrar", store.save(renamed).get("id") == id and store.open(id).nombre == "Espada nueva")
	_check("no quedan piezas apartadas", _files_in(temp).is_empty())


func _check_names() -> void:
	var store = _store()
	var id: String = store.save(_sword_entry("Espada", SWORD_A, "#A01020")).id
	var before := FileAccess.get_sha256(packs.path_join(id).path_join("pack.json"))
	for repeated: String in ["Espada", "ESPADA", "  espada  "]:
		var result: Dictionary = store.save(_sword_entry(repeated, SWORD_B, "#112233"))
		_check("rechaza el nombre repetido «%s»" % repeated, result.error.contains("Ya hay"), result.error)
	_check_pack_fields(store, id)
	_check("el nombre repetido no sobrescribe", FileAccess.get_sha256(packs.path_join(id).path_join("pack.json")) == before)
	var similar: Dictionary = store.save(_sword_entry("Espada!", SWORD_B, "#112233"))
	_check("un nombre parecido recibe otro id", similar.error == "" and similar.id != id, str(similar))
	var exact: Dictionary = store.save(_sword_entry("n".repeat(40), SWORD_A, "#A01020"))
	_check("admite 40 caracteres", exact.error == "", exact.error)
	for bad: Variant in ["", "   ", "n".repeat(41), "a\nb", 7, null]:
		var result: Dictionary = store.save(_sword_entry("x", SWORD_A, "#A01020").merged({"nombre": bad}, true))
		_check("rechaza el nombre %s" % str(bad).c_escape(), result.size() == 1 and result.error != "", result.error)
	var accents: Dictionary = store.save(_sword_entry("Ñandú de fuego", SWORD_A, "#A01020"))
	_check("un nombre con tildes da un id válido", accents.error == "" and store.open(accents.id).nombre == "Ñandú de fuego", str(accents))


## Cambiar a mano cualquier dato de pack.json (la licencia, el autor, el nombre) se detecta.
func _check_pack_fields(store, id: String) -> void:
	var path := packs.path_join(id).path_join("pack.json")
	var original := FileAccess.get_file_as_bytes(path)
	for field: String in ["licencia", "autor", "nombre"]:
		var pack: Dictionary = JSON.parse_string(original.get_string_from_utf8())
		pack[field] = "CC0-1.0" if field == "licencia" else "Otro"
		_write(path, JSON.stringify(pack).to_utf8_buffer())
		_check("pack.json con otro campo «%s» se detecta" % field, store.open(id).error.contains("dañada"), store.open(id).error)
	_write(path, original)
	_check("y restaurado vuelve a abrirse", store.open(id).error == "")


func _check_invalid() -> void:
	var store = _store()
	var good := _sword_entry("Buena", SWORD_A, "#A01020")
	var other := _sword_entry("Otra", SWORD_B, "#112233")
	_check("rechaza una malla que no es la de la receta", store.save(good.merged({"malla": other.malla}, true)).error.contains("no coincide"))
	_check("rechaza una entrada sin malla", store.save(good.merged({"malla": null}, true)).error != "")
	_check("rechaza una receta inválida", store.save(good.merged({"receta": {"modo": "x"}}, true)).error != "")
	_check("rechaza otro modo todavía sin guardar", store.save(good.merged({"receta": _base_recipe("camiseta_basica")}, true)).error.contains("aún no"))
	var image := _image_entry("Imagen")
	_check("rechaza una imagen que no es la de la receta",
		store.save(image.merged({"fuente_bytes": "otra".to_utf8_buffer()}, true)).error.contains("no coincide"))
	_check("rechaza un contorno de dos puntos", store.save(image.merged({"contorno": PackedVector2Array([Vector2.ZERO, Vector2.ONE])}, true)).error != "")
	_check("rechaza ajustes desconocidos", store.save(image.merged({"ajustes": {"nada": 1}}, true)).error.contains("Ajustes"))
	_check("rechaza ajustes fuera de rango", store.save(image.merged({"ajustes": {"tolerancia": 2.0}}, true)).error.contains("Ajustes"))
	for bad_id: String in ["../fuera", "taller_../../fuera", "TALLER_A", "taller_", "taller_a/b", "taller_no_existe", "base"]:
		_check("no abre el id «%s»" % bad_id, store.open(bad_id).error != "")
		var result: Dictionary = store.save(good.merged({"reemplaza": bad_id}))
		_check("no actualiza el id «%s»" % bad_id, result.size() == 1 and result.error != "", result.error)
	_check("nada de esto escribe en la biblioteca", _files_in(packs).is_empty(), str(_files_in(packs)))
	_check("ni fuera de ella", not FileAccess.file_exists(base.path_join("fuera/pack.json")))


## Cada archivo ausente, truncado o alterado da un aviso, sin cerrar el programa ni tocar las otras piezas.
func _check_damage() -> void:
	for file_name: String in ["pack.json", "edicion.json"]:
		for damage: String in ["ausente", "truncado", "alterado"]:
			_remove(base)
			DirAccess.make_dir_recursive_absolute(packs)
			var store = _store()
			var victim: String = store.save(_sword_entry("Dañada", SWORD_A, "#A01020")).id
			var safe: String = store.save(_sword_entry("Sana", SWORD_B, "#112233")).id
			_damage(packs.path_join(victim).path_join(file_name), damage)
			var label := "%s %s" % [file_name, damage]
			var listed: Dictionary = store.list()
			_check(label + ": avisa", listed.avisos.size() == 1 and listed.avisos[0].contains(victim), str(listed.avisos))
			_check(label + ": la otra sigue", listed.piezas.size() == 1 and listed.piezas[0].id == safe)
			_check(label + ": no se abre", store.open(victim).error.contains("dañada"), store.open(victim).error)
			_check(label + ": la otra se abre", store.open(safe).error == "")
	for damage: String in ["ausente", "truncado", "alterado"]:
		_remove(base)
		DirAccess.make_dir_recursive_absolute(packs)
		var store = _store()
		var entry := _sword_entry("Sin glb", SWORD_A, "#A01020")
		var id: String = store.save(entry).id
		_damage(packs.path_join(id).path_join("pieza.glb"), damage)
		var listed: Dictionary = store.list()
		_check("glb %s: sigue en la lista con aviso" % damage, listed.piezas.size() == 1 and listed.avisos.size() == 1, str(listed.avisos))
		var opened: Dictionary = store.open(id)
		_check("glb %s: se rehace desde la receta" % damage, opened.error == "" and _same(opened.malla, entry.malla)
			and opened.avisos.size() == 1, opened.error)
		var fixed := entry.merged({"reemplaza": id})
		_check("glb %s: guardar lo repara" % damage, store.save(fixed).error == "" and store.list().avisos.is_empty())


## Un cambio que sigue siendo JSON y receta válidos solo lo detecta el hash.
func _check_edition_tamper() -> void:
	var store = _store()
	var id: String = store.save(_sword_entry("Espada", SWORD_A, "#A01020")).id
	var path := packs.path_join(id).path_join("edicion.json")
	var edition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	edition.receta.parametros.longitud_m = 1.3
	_write(path, JSON.stringify(edition, "\t", false, true).to_utf8_buffer())
	_check("edicion.json con otra medida válida no se abre", store.open(id).error.contains("dañada"), store.open(id).error)
	var listed: Dictionary = store.list()
	_check("edicion.json con otra medida válida da aviso", listed.piezas.is_empty() and listed.avisos.size() == 1, str(listed.avisos))


## Sin su imagen, la pieza sigue abierta y editable con un aviso.
func _check_source_lost() -> void:
	for damage: String in ["ausente", "alterado"]:
		_remove(base)
		DirAccess.make_dir_recursive_absolute(packs)
		var store = _store()
		var entry := _image_entry("Silueta")
		var id: String = store.save(entry).id
		_damage(packs.path_join(id).path_join("fuentes/figura.png"), damage)
		var opened: Dictionary = store.open(id)
		_check("imagen %s: abre con aviso" % damage, opened.error == "" and opened.imagen == null
			and opened.avisos.size() == 1 and opened.avisos[0].contains("imagen de origen"), str(opened.get("avisos")))
		_check("imagen %s: la pieza es la misma" % damage, opened.error == "" and _same(opened.malla, entry.malla))
		_check("imagen %s: conserva el contorno" % damage, opened.contorno == entry.contorno)


func _check_failed_save() -> void:
	var store = _store()
	var entry := _sword_entry("Espada", SWORD_A, "#A01020")
	var id: String = store.save(entry).id
	var blocker := base.path_join("bloqueo")
	_write(blocker, "no es una carpeta".to_utf8_buffer())
	var broken = store_script.new(packs, blocker.path_join("temporal"))
	var changed := _sword_entry("Espada", SWORD_B, "#112233")
	changed.reemplaza = id
	var failed: Dictionary = broken.save(changed)
	_check("un guardado imposible da error", failed.size() == 1 and failed.error != "", failed.error)
	_check("un guardado imposible conserva la pieza", _same(store.open(id).malla, entry.malla))
	var missing: String = store._swap(temp.path_join("nuevas/no_existe"), id)
	_check("un fallo al mover da error", missing != "", missing)
	_check("un fallo al mover conserva la pieza", DirAccess.dir_exists_absolute(packs.path_join(id))  # antes de que open la recupere
		and store.open(id).error == "" and _same(store.open(id).malla, entry.malla))
	_check("y no la deja apartada", not DirAccess.dir_exists_absolute(temp.path_join("viejas").path_join(id)))


## Un cierre en cada punto de la sustitución.
func _check_interrupted() -> void:
	var store = _store()
	var entry := _sword_entry("Espada", SWORD_A, "#A01020")
	var id: String = store.save(entry).id
	var final := packs.path_join(id)
	var old := temp.path_join("viejas").path_join(id)
	DirAccess.make_dir_recursive_absolute(old.get_base_dir())
	DirAccess.rename_absolute(final, old)
	var listed: Dictionary = _store().list()
	_check("cierre con la vieja apartada: la recupera", listed.piezas.size() == 1 and listed.piezas[0].id == id
		and not DirAccess.dir_exists_absolute(old))
	_check("y se abre igual", _same(store.open(id).malla, entry.malla))
	_copy_tree(final, old)
	var changed := FileAccess.get_sha256(final.path_join("pack.json"))
	_write(old.path_join("pack.json"), "vieja".to_utf8_buffer())
	_store().list()
	_check("cierre con la nueva ya en su sitio: gana la nueva", FileAccess.get_sha256(final.path_join("pack.json")) == changed
		and not DirAccess.dir_exists_absolute(old))
	var leftover := temp.path_join("nuevas/taller_a_medias")
	DirAccess.make_dir_recursive_absolute(leftover)
	_write(leftover.path_join("pack.json"), "{".to_utf8_buffer())
	var again: Dictionary = _store().list()
	_check("lo escrito a medias se limpia y no aparece", not DirAccess.dir_exists_absolute(leftover)
		and again.piezas.size() == 1 and again.avisos.is_empty())


## Los packs que no son del Taller no se listan ni se tocan.
func _check_foreign() -> void:
	var names := ["base", "taller_ajeno"]
	for name: String in names:
		DirAccess.make_dir_recursive_absolute(packs.path_join(name))
		_write(packs.path_join(name).path_join("pack.json"), JSON.stringify({"formato": "gamemolde-pack", "version": 1, "id": name,
			"nombre": "Espada", "autor": "Otro", "licencia": "CC0-1.0", "piezas": [{"id": "x", "tipo": "accesorio",
			"ranura": "accesorio", "archivo": "x.glb"}]}).to_utf8_buffer())
	var before := FileAccess.get_sha256(packs.path_join("taller_ajeno/pack.json"))
	var store = _store()
	var listed: Dictionary = store.list()
	_check("otros packs no se listan ni avisan", listed.piezas.is_empty() and listed.avisos.is_empty(), str(listed))
	_check("un pack ajeno no se abre", store.open("taller_ajeno").error != "")
	var overwrite := _sword_entry("Ajeno", SWORD_A, "#A01020").merged({"reemplaza": "taller_ajeno"})
	_check("un pack ajeno no se actualiza", store.save(overwrite).error != "")
	var same_name: Dictionary = store.save(_sword_entry("Ajeno", SWORD_A, "#A01020"))
	_check("un id ocupado por otro pack recibe otro", same_name.error == "" and same_name.id != "taller_ajeno", str(same_name))
	_check("el pack ajeno sigue igual", FileAccess.get_sha256(packs.path_join("taller_ajeno/pack.json")) == before)


func _store() -> RefCounted:
	return store_script.new(packs, temp)


func _base_recipe(mode: String) -> Dictionary:
	return {"formato": "gamemolde-asset-receta", "version": 1, "id": "pieza", "modo": mode, "autor": "Taller", "licencia": "propia"}


func _sword_entry(title: Variant, params: Dictionary, color: String) -> Dictionary:
	var data := _base_recipe("espada_parametrica")
	data.parametros = params
	data.colores = {"hoja": color}
	var normal: Dictionary = recipe.normalize(data).receta
	return {"nombre": title, "receta": data, "receta_normal": normal, "malla": swords.generate(data).malla, "miniatura": null}


func _image_entry(title: String) -> Dictionary:
	var image := _figure()
	var bytes := image.save_png_to_buffer()
	var analysis: Dictionary = mask.analyze(image, OPTIONS)
	var data := _base_recipe("extrusion_imagen")
	data.fuente = {"archivo": "fuentes/figura.png", "sha256": _sha256(bytes)}
	data.parametros = {"altura_m": 1.5, "grosor_m": 0.04}
	data.colores = {"principal": "#4968AA"}
	var normal: Dictionary = recipe.normalize(data).receta
	return {"nombre": title, "receta": data, "receta_normal": normal, "malla": silhouette.generate(data, analysis.contorno).malla,
		"miniatura": null, "contorno": analysis.contorno, "ajustes": OPTIONS.duplicate(), "fuente_bytes": bytes}


func _figure() -> Image:
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(16, 8, 24, 48), Color.WHITE)
	image.fill_rect(Rect2i(40, 20, 12, 10), Color.WHITE)
	return image


func _thumbnail() -> Image:
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	return image


func _same(a: Mesh, b: Mesh) -> bool:
	if a == null or b == null or a.get_surface_count() != b.get_surface_count():
		return false
	for i in a.get_surface_count():
		if a.surface_get_arrays(i) != b.surface_get_arrays(i) \
				or a.surface_get_material(i).albedo_color != b.surface_get_material(i).albedo_color:
			return false
	return true


func _damage(path: String, damage: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	match damage:
		"ausente":
			DirAccess.remove_absolute(path)
		"truncado":
			_write(path, bytes.slice(0, bytes.size() / 2))
		"alterado":
			bytes[bytes.size() / 2] = bytes[bytes.size() / 2] ^ 1
			_write(path, bytes)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _files_in(folder: String) -> Array:
	var found := []
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file: String in DirAccess.get_files_at(folder):
		found.append(folder.path_join(file))
	for child: String in DirAccess.get_directories_at(folder):
		found.append_array(_files_in(folder.path_join(child)))
	return found


func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for file: String in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
	for child: String in DirAccess.get_directories_at(from):
		_copy_tree(from.path_join(child), to.path_join(child))


func _remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for child: String in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(child))
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


func _check(label: String, ok: bool, detail: Variant = "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
