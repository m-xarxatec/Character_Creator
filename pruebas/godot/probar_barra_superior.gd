extends SceneTree
# Paso IU.4: barra superior (godot/app/top_bar.gd y main.gd): botones arriba, Exportar principal, nombre del archivo con
# • si hay cambios, Deshacer de la barra. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_barra_superior.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en main.gd, no llamar a top_bar.set_file -> fallan las comprobaciones del •.

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var actions = main.body_actions
	var top: HBoxContainer = main.top_bar.actions
	var up := [actions.open_button, actions.save_button, actions.export_button, main.undo_button, main.redo_button]
	check("Abrir, Guardar, Exportar, Deshacer y Rehacer están arriba", up.all(func(b: Button) -> bool:
		return b.get_parent() == top))
	check("Exportar es el botón principal y es el último", actions.export_button.theme_type_variation == "BotonPrincipal"
		and actions.export_button.get_index() == top.get_child_count() - 1)
	var label: Label = main.top_bar.file_label
	check("al empezar: «Personaje nuevo» sin •", label.text == "Personaje nuevo", label.text)
	main.editor.set_value("height", 0.8)
	main.refresh_top_bar()
	check("mover un deslizador pone el •", label.text.ends_with("•"), label.text)
	check("y Deshacer se activa", not main.undo_button.disabled)
	var folder := OS.get_user_data_dir().path_join("probar_barra_superior")
	DirAccess.make_dir_recursive_absolute(folder)
	actions.save_preset(folder.path_join("heroina.json"))
	actions.message.hide()
	main.refresh_top_bar()
	check("guardar pone el nombre del archivo y quita el •", label.text == "heroina.json", label.text)
	main.undo_button.pressed.emit()
	main.refresh_top_bar()
	check("Deshacer de la barra deshace (y vuelve el •)", is_equal_approx(main.editor.values["height"], 0.5)
		and label.text.ends_with("•"), "%s %s" % [main.editor.values["height"], label.text])
	label.text = ""
	await create_timer(main.FILE_REFRESH * 2).timeout
	check("el nombre y el • se ponen solos (temporizador), sin llamar a nada", label.text == "heroina.json  •", label.text)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
