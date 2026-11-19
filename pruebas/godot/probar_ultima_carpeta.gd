extends SceneTree
# Paso P.5c: los diálogos de archivo se abren en la última carpeta usada, también tras reiniciar
# (godot/app/body_actions.gd y settings_file.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_ultima_carpeta.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: si no se llama a SettingsFile.set_folder, los diálogos no abren la carpeta.

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var Main: GDScript = load(godot_dir.path_join("app/main.gd"))
	var Settings: GDScript = load(godot_dir.path_join("app/settings_file.gd"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	var folder := OS.get_user_data_dir().path_join("probar_ultima_carpeta")
	DirAccess.make_dir_recursive_absolute(folder)

	var main: Control = Main.new()
	root.add_child(main)
	await process_frame
	check("sin ajustes, no hay carpeta guardada", Settings.get_folder() == "")
	main.body_actions.save_dialog.file_selected.emit(folder.path_join("carpeta.json"))
	main.body_actions.message.hide()
	check("guardar recuerda la carpeta", Settings.get_folder() == folder, Settings.get_folder())
	main.free()

	main = Main.new()  # como tras cerrar y volver a abrir el programa
	root.add_child(main)
	await process_frame
	var actions = main.body_actions
	for dialog: FileDialog in [actions.save_dialog, actions.open_dialog, actions.file_dialog]:
		actions.popup_file_dialog(dialog)
		check("%s se abre en la última carpeta" % dialog.filters[0], _same(dialog.current_dir, folder), dialog.current_dir)
		dialog.hide()
	main.free()

	DirAccess.remove_absolute(folder.path_join("carpeta.json"))
	DirAccess.remove_absolute(folder)
	check("si la carpeta ya no existe, no se usa", Settings.get_folder() == "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _same(a: String, b: String) -> bool:
	return a.simplify_path().trim_suffix("/") == b.simplify_path().trim_suffix("/")


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
