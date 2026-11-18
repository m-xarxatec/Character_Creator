extends SceneTree
# Paso 7.3b: diálogo «Licencias» (godot/app/licenses_dialog.gd) y sus copias de LICENSE y CREDITOS.md. Sin ventana.
# Se lanza con --path godot (usa res://, como probar_datos.gd):
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path godot -s "$PWD/pruebas/godot/probar_licencias.gd" 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: cambiar una letra de CREDITOS.md sin copiarlo a godot/CREDITOS.txt -> falla la fila de las copias.

const ALLOWED := ["CC0", "MIT", "Apache-2.0", "Apache 2.0", "GPL"]
const WORDS := ["MIT", "MakeHuman", "Quaternius", "Godot Engine", "FreeType"]
const MIN_LENGTH := 10000

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
	var dialog: AcceptDialog = dialog_script.new()
	root.add_child(dialog)
	await process_frame
	check("el diálogo se abre con el texto", (dialog.get_child(0) as TextEdit).text == text)
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
		if cells.size() != 5 or not ALLOWED.any(func(name: String) -> bool: return license.begins_with(name)):
			bad.append(cells[0].strip_edges())
	check("CREDITOS.md: %d filas con 5 columnas y licencia admitida" % rows, rows > 0 and bad.is_empty(), str(bad))
