extends SceneTree
# Paso P.2: capturas de la ventana del editor (main.gd) para el juicio visual. Con ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --path pruebas/godot -s capturar_ventana.gd)
# Escribe en pruebas/capturas/ventana/: 1_inicio.png, 2_probar_huesos.png (informe plegado) y
# 3_animacion_desplegado.png (Reposo, informe desplegado) y 4_estilo.png (pestaña Estilo, paso IU.6c).
# Paso IU.9: 5_ajustes.png (el diálogo) y 6_tamano_150.png (al 150 %, a 1920 × 1080), en oscuro y en claro (_claro);
# borra después el user://ajustes.cfg de este proyecto.
# Paso IU.10a: 7_pista.png (la pista sobre la vista) en oscuro y en claro; borra el archivo de ajustes también al empezar.

var out: String


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	out = root_dir.path_join("pruebas/capturas/ventana")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ajustes.cfg"))  # paso IU.10a: que salga la pista
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))  # en Windows root.size solo no cambia la ventana
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await _shoot("1_inicio")
	main.body_actions.set_pose_t(true)
	await _shoot("2_probar_huesos")
	main.body_actions.set_pose_t(false)
	main.body_actions.set_animation(1)
	main.report_section.set_open(true)
	await _shoot("3_animacion_desplegado")
	main.top_bar.tab_bar.current_tab = main.TAB_NAMES.find("Estilo")  # paso IU.6c: el Acabado en su pestaña
	await _shoot("4_estilo")
	main.top_bar.tab_bar.current_tab = 0
	for dark: bool in [true, false]:
		var suffix := "" if dark else "_claro"
		main.set_dark(dark)
		await _shoot("7_pista" + suffix)
		main.open_settings()
		await _shoot("5_ajustes" + suffix)
		main.settings.hide()
		root.size = Vector2i(1920, 1080)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		main.set_ui_scale(1.5)
		await _shoot("6_tamano_150" + suffix)
		main.set_ui_scale(1.0)
		root.size = Vector2i(1280, 720)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ajustes.cfg"))
	print("Capturas en ", out)
	quit()


func _shoot(name: String) -> void:
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
