extends SceneTree
# Paso P.4a: Ctrl+S, Ctrl+O y Ctrl+E abren Guardar preset, Abrir preset y Exportar .glb (godot/app/body_actions.gd).
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_atajos.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: sin el shortcut de un botón, su atajo no abre nada.

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var actions = main.body_actions
	for case: Array in [[KEY_S, actions.save_dialog, "Guardar preset"], [KEY_O, actions.open_dialog, "Abrir preset"],
			[KEY_E, actions.file_dialog, "Exportar .glb"]]:
		await _press(case[0])
		check("Ctrl+%s abre %s" % [OS.get_keycode_string(case[0]), case[2]], case[1].visible)
		case[1].hide()
		await process_frame
	check("la ayuda de los botones dice el atajo", actions.save_button.shortcut != null
		and actions.open_button.shortcut != null and actions.export_button.shortcut != null)
	actions.export_button.disabled = true
	await _press(KEY_E)
	check("con Exportar desactivado (exportando), Ctrl+E no abre nada", not actions.file_dialog.visible)
	actions.export_button.disabled = false
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _press(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.ctrl_pressed = true
		event.pressed = pressed
		root.push_input(event)
	await process_frame


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
