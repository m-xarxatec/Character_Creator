extends SceneTree
# Paso 7.3b: diálogo «Licencias» (godot/app/licenses_dialog.gd) y sus copias de LICENSE y CREDITOS.md. Sin ventana.
# Se lanza con --path godot (usa res://, como probar_datos.gd):
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path godot -s "$PWD/pruebas/godot/probar_licencias.gd" 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: cambiar una letra de CREDITOS.md sin copiarlo a godot/CREDITOS.txt -> falla la fila de las copias.
# Paso AB.13b (D45): Créditos es el único sitio con autor y licencia de las piezas. Quitar de CREDITOS.md la fila propia de un pack
# (p. ej. quaternius o base) -> «falta la fila del pack …»; quitar el autor de packs_text -> falla «Packs de piezas».

const PackLibrary := preload("res://addons/creador/pack_library.gd")

const ALLOWED := ["CC0", "MIT", "Apache-2.0", "Apache 2.0", "GPL"]
const FONT_LICENSE := "SIL OFL 1.1"  # regla 5: solo para fuentes (D30)
const WORDS := ["MIT", "MakeHuman", "Quaternius", "Godot Engine", "FreeType"]
const MIN_LENGTH := 10000
const PACK_NAMES := ["Pack MakeHuman", "Pack Quaternius", "Pack OverScore", "Pack base"]
const FAKE_PACKS := "user://prueba_licencias_packs"

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var dialog_script: GDScript = load("res://app/licenses_dialog.gd")
	var text: String = dialog_script.build_text(FileAccess.get_file_as_string(dialog_script.PROGRAM_LICENSE),
		FileAccess.get_file_as_string(dialog_script.CREDITS))
	var missing := WORDS.filter(func(word: String) -> bool: return not text.contains(word))
	check("el texto nombra %s" % ", ".join(WORDS), missing.is_empty(), str(missing))
	check("el texto es largo (> %d caracteres: avisos de Godot)" % MIN_LENGTH, text.length() > MIN_LENGTH, str(text.length()))
	for pair: Array in [["LICENSE", "godot/LICENCIA_PROGRAMA.txt"], ["CREDITOS.md", "godot/CREDITOS.txt"]]:
		var original := FileAccess.get_sha256(root_dir.path_join(pair[0]))
		check("%s es copia exacta de %s" % [pair[1], pair[0]], original != "" and original == FileAccess.get_sha256(
			root_dir.path_join(pair[1])))
	_check_credits(FileAccess.get_file_as_string(root_dir.path_join("CREDITOS.md")))
	_check_pack_rows(FileAccess.get_file_as_string(root_dir.path_join("CREDITOS.md")), root_dir)
	var library := PackLibrary.new()
	library.scan(PackedStringArray(["res://packs"]))
	_check_packs_text(dialog_script, library)
	_check_user_pack(dialog_script)
	var dialog: AcceptDialog = dialog_script.new()
	root.add_child(dialog)
	dialog.set_packs(library)
	await process_frame
	var shown: String = (dialog.get_child(0) as TextEdit).text
	check("el diálogo se abre con el texto y el bloque de packs", shown.contains(text.substr(0, 200))
		and shown.contains("== Packs de piezas ==") and shown.contains(library.packs["base"]["datos"]["autor"]))
	dialog.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Cada fila de la tabla de CREDITOS.md: 5 columnas y una licencia admitida (regla 5).
func _check_credits(credits: String) -> void:
	var bad := []
	var rows := 0
	for line: String in credits.split("\n"):
		if not line.begins_with("|") or line.begins_with("| Qué es") or line.begins_with("| ---"):
			continue
		rows += 1
		var cells := line.trim_prefix("|").trim_suffix("|").split("|")
		var license := cells[2].strip_edges() if cells.size() == 5 else ""
		var font_ok := license.begins_with(FONT_LICENSE) and cells[0].contains("fuente")
		if cells.size() != 5 or not (font_ok or ALLOWED.any(func(name: String) -> bool: return license.begins_with(name))):
			bad.append(cells[0].strip_edges())
	check("CREDITOS.md: %d filas con 5 columnas y licencia admitida" % rows, rows > 0 and bad.is_empty(), str(bad))


## Cada carpeta de godot/packs/ con pack.json tiene en CREDITOS.md una fila propia (que no nombra otro pack) con licencia admitida.
## Devuelve los problemas (vacío = bien). Recibe el texto para poder probarla con una copia rota.
func missing_pack_rows(credits: String, ids: Array) -> Array:
	var problems := []
	for id: String in ids:
		var own := false
		for line: String in credits.split("\n"):
			var cells := line.trim_prefix("|").trim_suffix("|").split("|")
			if not line.begins_with("|") or cells.size() != 5 or not line.contains("godot/packs/%s/" % id):
				continue
			var others := ids.any(func(other: String) -> bool: return other != id and line.contains("godot/packs/%s/" % other))
			var license := cells[2].strip_edges()
			if not others and ALLOWED.any(func(name: String) -> bool: return license.begins_with(name)):
				own = true
		if not own:
			problems.append("falta la fila del pack %s" % id)
	return problems


func _pack_ids(root_dir: String) -> Array:
	var ids := []
	for name: String in DirAccess.get_directories_at(root_dir.path_join("godot/packs")):
		if FileAccess.file_exists(root_dir.path_join("godot/packs").path_join(name).path_join("pack.json")):
			ids.append(name)
	return ids


func _check_pack_rows(credits: String, root_dir: String) -> void:
	var ids := _pack_ids(root_dir)
	check("CREDITOS.md: una fila propia por cada pack de godot/packs/ (%s)" % ", ".join(ids), ids.size() >= 4
		and missing_pack_rows(credits, ids).is_empty(), str(missing_pack_rows(credits, ids)))
	var broken := credits.split("\n")
	broken = PackedStringArray(Array(broken).filter(func(line: String) -> bool: return not line.contains("godot/packs/quaternius/")))
	check("la comprobación salta si falta la fila de quaternius", missing_pack_rows("\n".join(broken), ids).has(
		"falta la fila del pack quaternius"))


## «Packs de piezas»: cada pack de serie con su id, autor y licencia.
func _check_packs_text(dialog_script: GDScript, library) -> void:
	var packs_text: String = dialog_script.packs_text(library.packs)
	var text: String = dialog_script.build_text("", "", packs_text)
	var missing := []
	for id: String in library.packs:
		var data: Dictionary = library.packs[id]["datos"]
		for part: String in [id, data["autor"], data["licencia"], data["nombre"]]:
			if not text.contains(part):
				missing.append("%s: %s" % [id, part])
	for name: String in PACK_NAMES:
		if not text.contains(name):
			missing.append(name)
	check("«Packs de piezas» nombra cada pack con su id, autor y licencia (%d packs)" % library.packs.size(),
		library.packs.size() >= 4 and text.contains("== Packs de piezas ==") and missing.is_empty(), str(missing))
	check("sin packs, «Ninguno.»", dialog_script.packs_text({}).contains("Ninguno."))


## Un pack del usuario (user://packs) sin fila en CREDITOS.md aparece en Créditos con su autor.
func _check_user_pack(dialog_script: GDScript) -> void:
	var folder := FAKE_PACKS.path_join("pack_de_prueba")
	DirAccess.make_dir_recursive_absolute(folder)
	var data := {"formato": "gamemolde-pack", "version": 1, "id": "pack_de_prueba", "nombre": "Pack de prueba",
		"autor": "Autora Inventada", "licencia": "CC0-1.0", "origen": "https://ejemplo.invalid/",
		"piezas": [{"id": "cosa", "tipo": "accesorio", "ranura": "accesorio", "generador": {"tipo": "aro"}}]}
	var file := FileAccess.open(folder.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var library := PackLibrary.new()
	var warnings := library.scan(PackedStringArray([FAKE_PACKS]))
	var text: String = dialog_script.packs_text(library.packs)
	check("un pack de user://packs aparece con su autor", warnings.is_empty() and text.contains("Autora Inventada")
		and text.contains("pack_de_prueba"), str(warnings))
	DirAccess.remove_absolute(folder.path_join("pack.json"))
	DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(FAKE_PACKS)
