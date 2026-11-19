extends SceneTree
# Paso IU.10a: pista sobre la vista (godot/app/body_view.gd): sale la primera vez, se oculta al primer giro y no vuelve
# (user://ajustes.cfg, settings_file.gd). Sin ventana. Borra el archivo de ajustes al empezar y al terminar.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_pista.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: no llamar a set_hint_seen -> falla la 3; emitir rotated en zoom_by -> falla la 4.

var failures := 0
var Main: GDScript
var Settings: GDScript
var file: String


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	Main = load(godot_dir.path_join("app/main.gd"))
	Settings = load(godot_dir.path_join("app/settings_file.gd"))
	file = ProjectSettings.globalize_path(Settings.PATH)
	DirAccess.remove_absolute(file)

	# 1. Sin archivo: la pista se ve.
	var main: Control = await _start()
	var hint: Label = main.body_view.hint
	check("1 sin archivo, la pista se ve con su texto", hint != null and hint.visible
		and hint.text == "Arrastra para girar · Rueda para acercar · F1 atajos", str(hint))

	# 2. El primer giro la oculta y lo guarda.
	main.body_view.camera.rotate_by(Vector2(10, 0))
	check("2 al girar se oculta y se guarda", not hint.visible and Settings.get_hint_seen())
	main.free()
	await process_frame

	# 3. Reinicio: ya no hay pista.
	main = await _start()
	check("3 tras reiniciar no hay pista", main.body_view.hint == null or not main.body_view.hint.visible)
	main.free()
	await process_frame

	# 4. Con un archivo nuevo, el zoom no la oculta.
	DirAccess.remove_absolute(file)
	main = await _start()
	main.body_view.camera.zoom_by(1)
	check("4 el zoom no oculta la pista", main.body_view.hint != null and main.body_view.hint.visible
		and not Settings.get_hint_seen())
	main.free()
	await process_frame

	DirAccess.remove_absolute(file)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures > 0 else 0)


func _start() -> Control:
	var main: Control = Main.new()
	root.add_child(main)
	await process_frame
	return main


func check(text: String, ok: bool, detail := "") -> void:
	if ok:
		print("  bien  ", text)
	else:
		failures += 1
		print("  FALLO ", text, "  ", detail)
