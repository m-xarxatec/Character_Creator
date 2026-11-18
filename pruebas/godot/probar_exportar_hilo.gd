extends SceneTree
# Paso P.1: exportar desde la ventana no la congela (lo pesado va en un hilo) y el .glb sale igual. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 200 godot --headless --path pruebas/godot -s probar_exportar_hilo.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: si GlbExporter.compute se hace en el hilo principal, el hueco mayor entre fotogramas pasa de 1 s.

const MAX_GAP_MS := 300  # PROVISIONAL

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var actions = main.body_actions
	var folder := OS.get_user_data_dir().path_join("probar_exportar_hilo")
	DirAccess.make_dir_recursive_absolute(folder)
	var direct := folder.path_join("directo.glb")
	var threaded := folder.path_join("hilo.glb")
	main.editor.set_value("height", 0.7)
	check("exportar sin hilo va bien", main.body_view.export_glb(direct) == OK)

	var last := Time.get_ticks_msec()  # desde que se pulsa: prepare también cuenta
	actions._on_file_selected(threaded)
	check("durante: botón desactivado y «Exportando…»", actions.export_button.disabled
		and actions.export_button.text == "Exportando…" and actions.export_running())
	main.editor.set_value("height", 0.2)  # lo que cambie ahora no entra en el archivo
	var gap := Time.get_ticks_msec() - last
	last = Time.get_ticks_msec()
	var frames := 0
	while actions.export_running():
		await process_frame
		var now := Time.get_ticks_msec()
		gap = maxi(gap, now - last)
		last = now
		frames += 1
	check("la ventana sigue dibujando (hueco mayor %d ms, %d fotogramas)" % [gap, frames], gap < MAX_GAP_MS and frames > 3)
	check("el .glb es el mismo, byte a byte", _same(direct, threaded))
	check("el .tres es el mismo (sin los id aleatorios de los subrecursos)",
		_without_ids(direct.get_basename() + ".tres") == _without_ids(threaded.get_basename() + ".tres"))
	check("después: botón activo y aviso «Guardado»", not actions.export_button.disabled
		and actions.export_button.text == "Exportar .glb" and actions.message.dialog_text.begins_with("Guardado"))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	main.free()
	quit(1 if failures else 0)


func _same(a: String, b: String) -> bool:
	return FileAccess.file_exists(a) and FileAccess.get_sha256(a) == FileAccess.get_sha256(b)


## Godot da a cada subrecurso un id aleatorio al guardar (dos exportaciones sin hilo también difieren en eso).
func _without_ids(path: String) -> String:
	var ids := RegEx.create_from_string("(Shader|ShaderMaterial)_[a-z0-9]+")
	return ids.sub(FileAccess.get_file_as_string(path), "$1", true)


func check(text: String, ok: bool) -> void:
	print(("BIEN  " if ok else "FALLO ") + text)
	if not ok:
		failures += 1
