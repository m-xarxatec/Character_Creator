extends AcceptDialog
# Paso 7.3b: diálogo «Licencias»: el programa (MIT), el material de terceros (CREDITOS.md) y los avisos de Godot y de
# sus bibliotecas, que su licencia pide reproducir en el programa que se reparte.
# LICENSE y CREDITOS.md están fuera de godot/: viajan como copias (LICENCIA_PROGRAMA.txt y CREDITOS.txt);
# probar_licencias.gd comprueba que son iguales a los originales.
# Uso: var dialog := LicensesDialog.new(); add_child(dialog); dialog.popup_centered_ratio(0.7)

const PROGRAM_LICENSE := "res://LICENCIA_PROGRAMA.txt"
const CREDITS := "res://CREDITOS.txt"


func _init() -> void:
	title = "Licencias"
	var text := TextEdit.new()
	text.editable = false
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size = Vector2(700, 450)
	text.text = build_text(FileAccess.get_file_as_string(PROGRAM_LICENSE), FileAccess.get_file_as_string(CREDITS))
	add_child(text)


## Texto completo, en bloques con título. Función pura: se prueba sin ventana.
static func build_text(program: String, credits: String) -> String:
	var lines := PackedStringArray()
	lines.append("== GameMolde %s ==\n" % ProjectSettings.get_setting("application/config/version", ""))
	lines.append(program)
	lines.append("\n== Material de terceros ==\n")
	lines.append(credits)
	lines.append("\n== Godot Engine ==\n")
	lines.append(Engine.get_license_text())
	lines.append("\n== Bibliotecas incluidas en Godot ==\n")
	for item: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in item["parts"]:
			lines.append("%s — %s — %s" % [item["name"], ", ".join(part["copyright"]), part["license"]])
	var texts: Dictionary = Engine.get_license_info()
	for name: String in texts:
		lines.append("\n-- %s --\n%s" % [name, texts[name]])
	return "\n".join(lines)
