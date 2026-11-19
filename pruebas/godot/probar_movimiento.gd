extends SceneTree
# Paso IU.10c: fundido al desplegar las zonas y el informe (godot/app/motion.gd); con «Reducir animaciones», de golpe.
# Sin ventana. Borra user://ajustes.cfg al empezar y al terminar.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_movimiento.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: quitar el paso «Reducir animaciones» de fade_in -> falla la 2.

var failures := 0
var Motion: GDScript
var Settings: GDScript


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	Motion = load(godot_dir.path_join("app/motion.gd"))
	Settings = load(godot_dir.path_join("app/settings_file.gd"))
	var file := ProjectSettings.globalize_path(Settings.PATH)
	DirAccess.remove_absolute(file)
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var picker: CanvasItem = main.zone_picker
	var report: CanvasItem = main.report_section.panel

	# 1. Sin Reducir: empieza transparente y a los 0,25 s está entero.
	main.set_zones_visible(false)
	main.set_zones_visible(true)
	main.report_section.set_open(true)
	check("1 zonas: fundido en marcha", picker.visible and picker.modulate.a < 1.0, str(picker.modulate.a))
	check("1 informe: fundido en marcha", report.visible and report.modulate.a < 1.0, str(report.modulate.a))
	check("1 fade_in devuelve un Tween", _tween_ok())
	await _wait(250)
	check("1 a los 0,25 s, zonas enteras", is_equal_approx(picker.modulate.a, 1.0), str(picker.modulate.a))
	check("1 a los 0,25 s, informe entero", is_equal_approx(report.modulate.a, 1.0), str(report.modulate.a))

	# 2. Con Reducir: de golpe.
	Settings.set_reduce_motion(true)
	main.set_zones_visible(false)
	main.set_zones_visible(true)
	main.report_section.set_open(false)
	main.report_section.set_open(true)
	check("2 zonas de golpe", picker.visible and picker.modulate.a == 1.0, str(picker.modulate.a))
	check("2 informe de golpe", report.visible and report.modulate.a == 1.0, str(report.modulate.a))
	var label := Label.new()
	root.add_child(label)
	check("2 fade_in devuelve null", Motion.fade_in(label) == null)
	label.free()

	# 3. Duración dentro de la guía.
	check("3 FADE entre 0,12 y 0,18 s", Motion.FADE >= 0.12 and Motion.FADE <= 0.18, str(Motion.FADE))

	main.free()
	await process_frame
	DirAccess.remove_absolute(file)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures > 0 else 0)


func _tween_ok() -> bool:
	var label := Label.new()
	root.add_child(label)
	var tween: Tween = Motion.fade_in(label)
	var ok := tween != null and tween.is_valid()
	label.free()
	return ok


## Los Tween avanzan con los fotogramas: espera por tiempo, no por número de fotogramas.
func _wait(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame


func check(text: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + text, " ", detail)
	if not ok:
		failures += 1
