extends SceneTree
# Paso P.2: capturas de la ventana del editor (main.gd) para el juicio visual. Con ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --path pruebas/godot -s capturar_ventana.gd)
# Escribe en pruebas/capturas/ventana/: 1_inicio.png, 2_probar_huesos.png (informe plegado) y
# 3_animacion_desplegado.png (Reposo, informe desplegado) y 4_estilo.png (pestaña Estilo, paso IU.6c).

var out: String


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	out = root_dir.path_join("pruebas/capturas/ventana")
	DirAccess.make_dir_recursive_absolute(out)
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
	print("Capturas en ", out)
	quit()


func _shoot(name: String) -> void:
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
