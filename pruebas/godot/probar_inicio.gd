extends SceneTree
# Paso PL.4: ventana «Nuevo personaje» (godot/app/start_screen.gd) y «Recientes» (settings_file.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_inicio.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en SettingsFile.get_recent, no mirar si el archivo existe -> «Recientes» lista uno borrado.

const BIG := ["femenino", "masculino", "anime"]
const TITLE := 40  # PROVISIONAL: px de la barra de título de la ventana

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var settings: GDScript = load(root_dir.path_join("godot/app/settings_file.gd"))
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var screen: AcceptDialog = main.start_screen
	check("en las pruebas no se abre sola (main no es la escena principal)", not screen.visible)
	main.new_button.pressed.emit()
	check("«Nuevo…» la abre", screen.visible and screen.title == "Nuevo personaje")
	var project := ConfigFile.new()
	project.load(root_dir.path_join("godot/project.godot"))
	var height: int = project.get_value("display", "window/size/viewport_height", 0)
	check("cabe en la ventana del programa (%d px de alto, %d de barra de título)" % [height, TITLE], height > 0
		and screen.size.y + TITLE <= height, "%d px" % screen.size.y)
	var ids: Array = screen.cards.keys()
	check("Femenino, Masculino y Neutro, sin «Más cuerpos» (paso PL.10)", ids == BIG
		and screen.cards["anime"].text == "Neutro" and screen.cards["femenino"].icon != null, str(ids))
	screen.cards["femenino"].pressed.emit()
	check("elegir Femenino la cierra y pone ese cuerpo", not screen.visible
		and main.editor.values == main.zone_picker.gallery.templates["femenino"] and main.editor.values["gender"] == 0.0)

	var folder := OS.get_user_data_dir().path_join("recientes_prueba")
	DirAccess.make_dir_recursive_absolute(folder)
	settings._write("archivos", "recientes", PackedStringArray())
	for i in 10:
		var path := folder.path_join("p%d.json" % i)
		check("guardar p%d.json" % i, main.body_actions.save_preset(path) == OK) if i == 0 else main.body_actions.save_preset(path)
	DirAccess.remove_absolute(folder.path_join("p8.json"))
	var recent: PackedStringArray = settings.get_recent()
	check("Recientes: de los 8 últimos, los que existen (7: p8 se borró), el más nuevo primero", recent.size() == 7
		and recent[0].ends_with("p9.json") and not Array(recent).any(func(p: String) -> bool: return p.ends_with("p8.json")),
		str(Array(recent).map(func(p: String) -> String: return p.get_file())))
	main.body_actions.save_preset(folder.path_join("p5.json"))
	check("volver a guardar uno lo sube arriba sin repetirlo", settings.get_recent()[0].ends_with("p5.json")
		and settings.get_recent().count(settings.get_recent()[0]) == 1)
	screen.show_screen()
	check("la ventana lista los recientes", screen.recent_box.get_child_count() == 7)
	screen.recent_box.get_child(1).pressed.emit()
	check("elegir uno lo abre", main.body_actions.current_path == settings.get_recent()[0] and not screen.visible,
		main.body_actions.current_path.get_file())
	settings._write("archivos", "recientes", PackedStringArray())
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
