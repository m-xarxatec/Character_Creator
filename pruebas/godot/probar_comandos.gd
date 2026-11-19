extends SceneTree
# Paso P.8b: botón «Comandos» junto al sol/luna y su lista de atajos (godot/app/commands_dialog.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_comandos.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: no conectar el botón en main.gd -> «el botón abre la lista» falla.

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var bar: Node = main.commands_button.get_parent()
	check("el botón «Comandos» está junto al sol/luna", main.commands_button.text == "Comandos"
		and main.commands_button.get_index() + 1 == main.theme_button.get_index() and bar == main.theme_button.get_parent())
	main.commands_button.pressed.emit()
	check("el botón abre la lista", main.commands.visible)
	var labels: Array[String] = []
	for label: Label in main.commands.grid.get_children():
		labels.append(label.text)
	var rows: int = main.commands.COMMANDS.size()
	check("una fila (teclas + qué hace) por cada comando de la lista", labels.size() == rows * 2, "%d filas" % rows)
	for keys: String in ["Ctrl + S", "Ctrl + arrastrar", "Inicio", "Rueda del ratón"]:
		check("la lista tiene «%s»" % keys, keys in labels)
	main.commands.hide()
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
