extends AcceptDialog
# Paso 7.3b: diálogo «Licencias»: el programa (MIT), el material de terceros (CREDITOS.md) y los avisos de Godot y de
# sus bibliotecas, que su licencia pide reproducir en el programa que se reparte.
# LICENSE y CREDITOS.md están fuera de godot/: viajan como copias (LICENCIA_PROGRAMA.txt y CREDITOS.txt);
# probar_licencias.gd comprueba que son iguales a los originales.
# Paso AB.13b (D45): también los packs de piezas (los de serie y los de user://packs) con su autor y licencia: es el único
# sitio donde se ven (set_packs).
# Uso: var dialog := LicensesDialog.new(); add_child(dialog); dialog.popup_centered_ratio(0.7)

const PROGRAM_LICENSE := "res://LICENCIA_PROGRAMA.txt"
const CREDITS := "res://CREDITOS.txt"

var text_edit := TextEdit.new()


func _init() -> void:
	title = "Licencias"
	text_edit.editable = false
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.custom_minimum_size = Vector2(700, 450)
	text_edit.text = _text("")
	add_child(text_edit)


## Añade el bloque «Packs de piezas» (library: PackLibrary de la vista) y rehace el texto.
func set_packs(library) -> void:
	text_edit.text = _text(packs_text(library.packs))


func _text(packs: String) -> String:
	return build_text(FileAccess.get_file_as_string(PROGRAM_LICENSE), FileAccess.get_file_as_string(CREDITS), packs)


## Una línea por pack (ordenados por id): nombre, autor, licencia, origen y número de piezas. Función pura.
static func packs_text(packs: Dictionary) -> String:
	var lines := PackedStringArray(["== Packs de piezas ==\n"])
	var ids := packs.keys()
	ids.sort()
	for id: String in ids:
		var data: Dictionary = packs[id]["datos"]
		lines.append("%s (%s) — %s — %s — %s — %d piezas" % [data["nombre"], id, data["autor"], data["licencia"],
			data.get("origen", ""), data["piezas"].size()])
	if ids.is_empty():
		lines.append("Ninguno.")
	return "\n".join(lines)


## Texto completo, en bloques con título. Función pura: se prueba sin ventana.
static func build_text(program: String, credits: String, packs := "") -> String:
	var lines := PackedStringArray()
	lines.append("== GameMolde %s ==\n" % ProjectSettings.get_setting("application/config/version", ""))
	lines.append(program)
	lines.append("\n== Material de terceros ==\n")
	lines.append(credits)
	if packs != "":
		lines.append("\n" + packs)
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
