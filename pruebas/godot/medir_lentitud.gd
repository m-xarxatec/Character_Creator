extends SceneTree
# Paso OPT.1: dónde se va el tiempo al abrir el editor y al mover un deslizador. Solo mide (sin límites).
# Necesita ventana (no --headless): los fotogramas usan la tarjeta gráfica.
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s medir_lentitud.gd 2>&1 | grep -E 'MEDIDA|ERROR')

const REPEAT := 20  # veces que se repite cada pieza para la media
const DRAG_FRAMES := 120  # fotogramas arrastrando «Músculo» de 0 a 1 y vuelta

var root_dir: String


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var start := Time.get_ticks_usec()
	var species = load(root_dir.path_join("godot/addons/creador/species_data.gd")).new()
	species.load_folder(root_dir.path_join("godot/datos/humana"))
	_report("arranque: leer la especie (cuerpo.glb y datos)", Time.get_ticks_usec() - start)
	species.scene.free()

	start = Time.get_ticks_usec()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)
	_report("arranque: crear la ventana entera (main.gd, incluye leer la especie)", Time.get_ticks_usec() - start)
	await process_frame
	await RenderingServer.frame_post_draw
	_report("arranque: hasta el primer fotograma", Time.get_ticks_usec() - start)
	print("  MEDIDA memoria estática tras abrir: %.0f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6))

	var view = main.body_view
	var gallery = main.zone_picker.gallery
	_time("arranque: galería de plantillas (setup)", func() -> void:
		var copy = gallery.get_script().new()
		copy.setup(view.species.folder.path_join("presets"), view.species.manifest["species"], view.species.sliders)
		copy.free(), 3)
	_time("arranque: ventana «Nuevo personaje» (setup)", func() -> void:
		var copy = main.start_screen.get_script().new()
		copy.setup(gallery)
		copy.free(), 3)

	var values: Dictionary = main.editor.values.duplicate()
	var flip := [0.3]
	var next := func() -> Dictionary:
		flip[0] = 1.0 - flip[0]
		values["muscle"] = flip[0]
		return values
	_time("mover: editor.set_value (todo lo que cuelga de un cambio)", func() -> void:
		main.editor.set_value("muscle", next.call()["muscle"]))
	_time("  · body_view.set_values (formas, esqueleto, pose)", func() -> void: view.set_values(next.call()))
	_time("    · CharacterUpdater.update", func() -> void: view.updater.update(next.call(), false))
	_time("  · slider_panel.refresh (barras)", func() -> void: main.slider_panel.refresh())
	_time("  · refresh_top_bar (¿hay cambios? = preset a texto)", func() -> void: main.refresh_top_bar())
	_time("  · refresh_measures (altura y cabezas)", func() -> void: main.refresh_measures())
	if view.style != null:
		_time("al soltar (0,3 s después): style.refresh (normales del estilo)", func() -> void: view.style.refresh(), 5)

	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in DRAG_FRAMES:
		main.editor.set_value("muscle", absf(1.0 - 2.0 * fposmod(float(i) / DRAG_FRAMES * 2.0, 2.0) / 2.0))
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	print("  MEDIDA arrastrar «Músculo» (%d fotogramas): media %.1f ms, p99 %.1f ms, peor %.1f ms" % [DRAG_FRAMES,
		total / times.size(), times[int(times.size() * 0.99)], times[-1]])
	var worst := 0.0  # paso OPT.2: el tirón al soltar (el recálculo del estilo llega a los 0,3 s)
	var release := Time.get_ticks_usec()
	last = release
	while Time.get_ticks_usec() - release < 800000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	print("  MEDIDA al soltar, peor fotograma en 0,8 s: %.1f ms" % worst)
	main.free()
	quit()


func _time(label: String, action: Callable, count := REPEAT) -> void:
	var start := Time.get_ticks_usec()
	for i in count:
		action.call()
	print("  MEDIDA %s: %.2f ms de media (%d veces)" % [label, (Time.get_ticks_usec() - start) / 1000.0 / count, count])


func _report(label: String, usec: int) -> void:
	print("  MEDIDA %s: %d ms" % [label, usec / 1000])
