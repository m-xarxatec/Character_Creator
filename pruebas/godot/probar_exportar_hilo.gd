extends SceneTree
# Paso P.1: exportar desde la ventana no la congela (lo pesado va en un hilo) y el .glb sale igual. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 200 godot --headless --path pruebas/godot -s probar_exportar_hilo.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: si GlbExporter.compute se hace en el hilo principal, el hueco mayor entre fotogramas pasa de 1 s.
# OPT.3a: la de referencia se exporta sin la caché de la vista y la del hilo con ella: deben salir iguales. Si
# start_export no pasa la caché, falla «las formas del cuerpo salen de la caché» (y MEDIDA al pulsar vuelve a 650–750 ms
# con ventana). OPT.3b: las dos usan ya el horneado partido; para ver que el archivo es el de antes de OPT.3, comparar
# los sha256 con los de antes del cambio; un compute_bake sin suelo lo ve probar_personaje_horneado.
# Las medidas que valen son con ventana: quitar --headless.

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
	var waited := 0  # OPT.3a: como en el uso real, la vista ya tiene en su caché las formas activas
	while not main.body_view.style.show_if_current() and waited < 1200:
		await process_frame
		waited += 1
	check("la vista del estilo está al día antes de exportar", main.body_view.style.show_if_current())
	check("exportar sin hilo y sin la caché va bien", main.body_view.export_glb(direct, false) == OK)
	await process_frame  # en frío: MeshBaker suelta sus formas en el fotograma siguiente
	await process_frame

	var mesh_baker: GDScript = load(godot_dir.path_join("addons/creador/mesh_baker.gd"))
	var body_mesh: Mesh = main.body_view.species.mesh.mesh
	var last := Time.get_ticks_msec()  # desde que se pulsa: prepare también cuenta
	actions._on_file_selected(threaded)
	var press := Time.get_ticks_msec() - last
	print("MEDIDA al pulsar (prepare, con la caché): %d ms" % press)
	check("OPT.3a: las formas del cuerpo salen de la caché, no de la malla", not mesh_baker._shapes.has(body_mesh))
	check("durante: botón desactivado y «Exportando…»", actions.export_button.disabled
		and actions.export_button.text == "Exportando…" and actions.export_running())
	main.editor.set_value("height", 0.2)  # lo que cambie ahora no entra en el archivo
	var gap := Time.get_ticks_msec() - last
	last = Time.get_ticks_msec()
	var frames := 0
	var end_gap := 0  # OPT.3b: el último fotograma, el de terminar (finish y write)
	while actions.export_running():
		await process_frame
		var now := Time.get_ticks_msec()
		end_gap = now - last
		gap = maxi(gap, end_gap)
		last = now
		frames += 1
	print("MEDIDA al terminar (finish + write): %d ms; peor fotograma de toda la exportación: %d ms" % [end_gap, gap])
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
	var ids := RegEx.create_from_string("(Shader|ShaderMaterial|Image|ImageTexture)_[a-z0-9]+")  # SH.5: también el mapa de zonas
	return ids.sub(FileAccess.get_file_as_string(path), "$1", true)


func check(text: String, ok: bool) -> void:
	print(("BIEN  " if ok else "FALLO ") + text)
	if not ok:
		failures += 1
