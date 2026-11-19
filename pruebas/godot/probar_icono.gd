extends SceneTree
# Paso P.7: icono propio (godot/app/icono.svg) en project.godot. Además escribe godot/app/icono.png (256 px) para el
# README y el .ico de Windows (Fase 8). Se lanza con el proyecto principal:
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path godot -s "$PWD/pruebas/godot/probar_icono.gd" 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: borrar la línea config/icon de project.godot -> falla «project.godot usa el icono».

const ICON := "res://app/icono.svg"
const PNG := "res://app/icono.png"
const SIZE := 256

var failures := 0


func _initialize() -> void:
	check("project.godot usa el icono", ProjectSettings.get_setting("application/config/icon", "") == ICON)
	check("el icono existe", FileAccess.file_exists(ICON))
	var text := FileAccess.get_file_as_string(ICON)
	check("todo propio: sin imágenes, textos ni enlaces", not text.contains("<image") and not text.contains("<text")
		and not text.contains("href"))
	var image := Image.new()
	var error := image.load_svg_from_string(text, 1.0)
	check("el SVG se dibuja a %d px" % SIZE, error == OK and image.get_width() == SIZE and image.get_height() == SIZE,
		"%s %dx%d" % [error_string(error), image.get_width(), image.get_height()])
	if error == OK:
		check("se escribe icono.png", image.save_png(ProjectSettings.globalize_path(PNG)) == OK)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
