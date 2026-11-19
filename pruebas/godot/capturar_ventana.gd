extends SceneTree
# Paso P.2: capturas de la ventana del editor (main.gd) para el juicio visual. Con ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --path pruebas/godot -s capturar_ventana.gd)
# Escribe en pruebas/capturas/ventana/: 1_inicio.png, 2_probar_huesos.png (informe plegado) y
# 3_animacion_desplegado.png (Reposo, informe desplegado) y 4_estilo.png (pestaña Estilo, paso IU.6c).
# Paso IU.9: 5_ajustes.png (el diálogo) y 6_tamano_150.png (al 150 %, a 1920 × 1080), en oscuro y en claro (_claro);
# borra después el user://ajustes.cfg de este proyecto.
# Paso IU.10a: 7_pista.png (la pista sobre la vista) en oscuro y en claro; borra el archivo de ajustes también al empezar.
# Paso IU.3: 8_vista.png (fondo y sombra) en oscuro y en claro, 8_vista_rejilla.png, y la MEDIDA A/B: la vista con fondo
# opaco gris frente a la transparente compuesta sobre el mismo gris (el contorno y el color no deben cambiar).
# Paso IU.7b: 9_zona_iluminada.png (oscuro, «Brazos» teñidos con su etiqueta, como al dejar quieto el ratón).

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
	await _measure_ab(main.body_view)
	for dark: bool in [true, false]:
		var suffix := "" if dark else "_claro"
		main.set_dark(dark)
		await _shoot("7_pista" + suffix)
		main.body_view.camera.rotate_by(Vector2(-60, 0))  # 3/4: se ve la sombra
		await _shoot("8_vista" + suffix)
		if dark:
			main.set_grid(true)
			await _shoot("8_vista_rejilla")
			main.set_grid(false)
		main.body_view.camera.rotate_by(Vector2(60, 0))
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
	main.set_dark(true)
	main.set_touch_zones(true)
	var view: SubViewportContainer = main.body_view
	view.set_animation("")  # quieto, en reposo
	view.camera.snap()
	await _frames(5)
	var skeleton: Skeleton3D = view.species.skeleton
	var elbow := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftLowerArm")).origin
	var arm: Vector2 = view.camera.unproject_position(elbow)
	var zone: String = view.zone_at(arm)
	print("  zona bajo el codo: ", zone)
	view.highlight(zone, arm)
	await _shoot("9_zona_iluminada")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ajustes.cfg"))
	print("Capturas en ", out)
	quit()


func _shoot(name: String) -> void:
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


## Paso IU.3: diferencia máxima (de 255) entre la vista opaca sobre gris y la transparente compuesta sobre el mismo gris.
func _measure_ab(view: SubViewportContainer) -> void:
	var gray := Color(0.32, 0.33, 0.36)
	var environment: Environment = view.viewport.find_children("*", "WorldEnvironment", false, false)[0].environment
	var clip: String = view.clip
	view.set_animation("")  # quieto: si se mueve entre las dos fotos, la diferencia no es del fondo
	view.camera.snap()  # y la cámara ya en su sitio (se reencuadra con suavidad)
	view.floor_shadow.visible = false  # la sombra no existe en la vista opaca de antes
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = gray
	view.viewport.transparent_bg = false
	await _frames(10)
	var opaque: Image = view.viewport.get_texture().get_image()
	view.viewport.transparent_bg = true
	await _frames(10)
	var clear: Image = view.viewport.get_texture().get_image()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	view.floor_shadow.visible = true
	view.set_animation(clip)
	opaque.convert(Image.FORMAT_RGBA8)
	clear.convert(Image.FORMAT_RGBA8)
	var worst := 0.0
	for y in opaque.get_height():
		for x in opaque.get_width():
			var top: Color = clear.get_pixel(x, y)
			var mixed := gray.lerp(Color(top.r, top.g, top.b), top.a)
			var a: Color = opaque.get_pixel(x, y)
			worst = maxf(worst, maxf(absf(a.r - mixed.r), maxf(absf(a.g - mixed.g), absf(a.b - mixed.b))))
	print("  MEDIDA A/B fondo transparente: diferencia máxima %.1f de 255 (límite 2, PROVISIONAL)" % (worst * 255.0))


func _frames(count: int) -> void:
	for i in count:
		await process_frame
