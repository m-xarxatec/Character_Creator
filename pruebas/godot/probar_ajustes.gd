extends SceneTree
# Paso IU.9: diálogo «Ajustes» (godot/app/settings_dialog.gd): tema, tamaño de la interfaz y «Reducir animaciones»,
# aplicados al momento y guardados en user://ajustes.cfg (settings_file.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_ajustes.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: quitar «if instant: snap()» de orbit_camera.gd -> falla la 5; no buscar el más cercano de
# SCALES en get_ui_scale -> falla la 4.

var failures := 0
var Main: GDScript
var Settings: GDScript


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	Main = load(godot_dir.path_join("app/main.gd"))
	Settings = load(godot_dir.path_join("app/settings_file.gd"))
	var file := ProjectSettings.globalize_path(Settings.PATH)
	DirAccess.remove_absolute(file)
	var screen: float = Settings.nearest_scale(DisplayServer.screen_get_scale())

	# 1. Sin archivo: valores por defecto.
	var main: Control = await _start()
	check("1 sin archivo: oscuro, tamaño de la pantalla, sin reducir",
		main.dark and is_equal_approx(main.ui_scale, screen) and not main.reduce_motion
		and is_equal_approx(root.content_scale_factor, screen) and not main.body_view.camera.instant,
		"%s %s %s" % [main.dark, main.ui_scale, main.reduce_motion])

	# 2. Desde el diálogo: se aplican al momento y se guardan.
	main.open_settings()
	check("2 al 100 % no hay aviso de tamaño", not main.settings.scale_warning.visible)
	main.settings.theme_option.select(1)
	main.settings.theme_option.item_selected.emit(1)
	main.settings.scale_option.select(3)
	main.settings.scale_option.item_selected.emit(3)
	main.settings.reduce_box.button_pressed = true
	check("2 a más del 100 % avisa (menos nítido, panel cortado)", main.settings.scale_warning.visible)
	main.settings.hide()
	check("2 Claro cambia el tema y el sol/luna", not main.dark
		and main.theme_button.tooltip_text == "Pasar al tema oscuro", main.theme_button.tooltip_text)
	check("2 125 % escala la ventana", is_equal_approx(root.content_scale_factor, 1.25), str(root.content_scale_factor))
	check("2 Reducir pone la cámara de golpe", main.body_view.camera.instant)
	check("2 los tres quedan en el archivo", not Settings.get_dark() and is_equal_approx(Settings.get_ui_scale(), 1.25)
		and Settings.get_reduce_motion())
	await process_frame  # liberar en el mismo fotograma en que se cierra el diálogo hace caer a Godot
	main.free()

	# 3. Reinicio: un main nuevo los lee.
	root.content_scale_factor = 1.0
	main = await _start()
	check("3 al reiniciar sigue igual", not main.dark and is_equal_approx(root.content_scale_factor, 1.25)
		and main.body_view.camera.instant)

	# 5. Con Reducir, el encuadre llega sin esperar fotogramas; sin Reducir, no.
	var camera: Camera3D = main.body_view.camera
	camera.frame(AABB(Vector3(0.5, 0, 0), Vector3(1, 3, 1)), 1.0)
	check("5 con Reducir, frame() llega de golpe", camera.target.is_equal_approx(camera.goal_target))
	main.set_reduce_motion(false)
	camera.frame(AABB(Vector3(-0.5, 0, 0), Vector3(1, 1, 1)), 1.0)
	check("5 sin Reducir, la cámara llega poco a poco", not camera.target.is_equal_approx(camera.goal_target))

	# 6. El sol/luna y el diálogo van a la par.
	main.theme_button.pressed.emit()
	main.open_settings()
	check("6 el diálogo enseña el tema del sol/luna", main.dark and main.settings.theme_option.selected == 0)
	main.settings.hide()
	await process_frame
	main.free()

	# 4. Archivos rotos o fuera de rango.
	_write_text(file, "esto no es [un archivo de ajustes\n= = =")
	root.content_scale_factor = 1.0
	main = await _start()
	check("4 archivo roto: valores por defecto y arranca", main.dark and is_equal_approx(main.ui_scale, screen)
		and not main.reduce_motion and main.body_view.error == "")
	main.free()
	_write_text(file, "[interfaz]\ntamano=3.0\nreducir_animaciones=7\n")
	check("4 tamaño 3,0 → 1,5", is_equal_approx(Settings.get_ui_scale(), 1.5), str(Settings.get_ui_scale()))
	check("4 reducir = 7 → no", not Settings.get_reduce_motion())
	_write_text(file, "[interfaz]\ntamano=1.2\n")
	check("4 tamaño 1,2 → 1,25 (el más cercano)", is_equal_approx(Settings.get_ui_scale(), 1.25), str(Settings.get_ui_scale()))
	_write_text(file, "[interfaz]\ntamano=\"abc\"\n")
	check("4 tamaño \"abc\" → el de la pantalla", is_equal_approx(Settings.get_ui_scale(), screen), str(Settings.get_ui_scale()))

	DirAccess.remove_absolute(file)  # otras pruebas suponen oscuro y 100 %
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures > 0 else 0)


func _start() -> Control:
	var main: Control = Main.new()
	root.add_child(main)
	await process_frame
	return main


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func check(text: String, ok: bool, detail := "") -> void:
	if ok:
		print("  bien  ", text)
	else:
		failures += 1
		print("  FALLO ", text, "  ", detail)
