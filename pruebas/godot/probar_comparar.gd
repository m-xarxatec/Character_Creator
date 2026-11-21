extends SceneTree
# Paso PL.7: «Comparar» (botón y tecla C mantenidos) enseña el personaje como estaba al abrir o guardar. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_comparar.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en BodyActions.show_saved, pasar por editor.load_values -> cambia el editor y Deshacer.

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var view = main.body_view
	var start: Dictionary = main.editor.values.duplicate()
	main.zone_picker.gallery.cards["masculino"].pressed.emit()
	var now: Dictionary = main.editor.values.duplicate()
	var can_undo: bool = main.editor.can_undo()
	main.body_actions.compare_button.button_down.emit()
	check("pulsar «Comparar» enseña el personaje del principio", view.values == start and view.values != now)
	check("sin tocar el editor ni Deshacer", main.editor.values == now and main.editor.can_undo() == can_undo)
	main.body_actions.compare_button.button_up.emit()
	check("soltar vuelve al de ahora", view.values == now)
	main._unhandled_input(_key(true))
	check("la tecla C mantenida hace lo mismo", view.values == start)
	main._unhandled_input(_key(false))
	check("y al soltarla vuelve", view.values == now)
	var path := OS.get_user_data_dir().path_join("comparar_prueba.json")
	main.body_actions.save_preset(path)
	main.zone_picker.gallery.cards["femenino"].pressed.emit()
	main.body_actions.compare_button.button_down.emit()
	check("después de guardar, compara con lo guardado", view.values == now)
	main.body_actions.compare_button.button_up.emit()
	DirAccess.remove_absolute(path)
	check("«Comandos» lista la C", main.commands.COMMANDS.any(func(row: Array) -> bool: return row[0].begins_with("C ")))
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _key(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_C
	event.pressed = pressed
	return event


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
