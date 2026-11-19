extends SceneTree
# Paso P.4b: aviso de cambios sin guardar al cerrar (godot/app/main.gd y body_actions.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_aviso_cerrar.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: si has_changes() devuelve siempre falso, fallan «mover un deslizador», «cambiar la piel» y
# «cerrar con cambios».

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var BodyMaterial: GDScript = load(godot_dir.path_join("addons/creador/body_material.gd"))
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var actions = main.body_actions
	var mesh: MeshInstance3D = main.body_view.species.mesh
	var folder := OS.get_user_data_dir().path_join("probar_aviso_cerrar")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("aviso.json")

	check("al empezar no hay cambios", not actions.has_changes())
	check("cerrar la ventana ya no sale sola", not auto_accept_quit)
	main.editor.set_value("height", 0.8)
	check("mover un deslizador es un cambio", actions.has_changes())
	check("guardar quita el cambio", actions.save_preset(path) == OK and not actions.has_changes())
	actions.message.hide()
	BodyMaterial.set_color(mesh, "skin_color", Color(0.9, 0.5, 0.3))
	check("cambiar la piel es un cambio", actions.has_changes())
	check("abrir el preset guardado quita el cambio", actions.open_preset(path) == "" and not actions.has_changes())
	main.editor.set_value("muscle", 0.9)
	main._on_close_requested()
	check("cerrar con cambios enseña el aviso y no sale", main.close_dialog.visible and main.is_inside_tree())
	check("el aviso tiene Guardar…, Cancelar y Salir sin guardar",
		main.close_dialog.ok_button_text == "Guardar…" and main.close_dialog.cancel_button_text == "Cancelar"
		and _has_button(main.close_dialog, "Salir sin guardar"))
	main.close_dialog.hide()
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _has_button(dialog: AcceptDialog, text: String) -> bool:
	for button in dialog.find_children("*", "Button", true, false):
		if button.text == text:
			return true
	return false


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
