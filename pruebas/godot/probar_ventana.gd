extends SceneTree
# TA.2a: siete accesos superiores, seis paneles de personaje y navegación con cambios pendientes.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_ventana.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')

const EXPECTED := ["Cuerpo", "Cara y ojos", "Pelo", "Ropa", "Accesorios", "Estilo"]  # IU.4: Exportar ya no es pestaña

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame  # _ready() llega con el primer fotograma
	check("la ventana crea sus pestañas", main.tabs != null)
	if main.tabs != null:
		_check_tabs(main.tabs)
		_check_top_tabs(main)
		await _check_workshop(main)
	_check_core_independent(root_dir.path_join("godot/addons/creador"))
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_tabs(tabs: TabContainer) -> void:
	var names: Array = []
	var active: Array = []
	for i in tabs.get_tab_count():
		names.append(tabs.get_tab_title(i))
		if not tabs.is_tab_disabled(i):
			active.append(tabs.get_tab_title(i))
	check("6 pestañas, con sus nombres y en orden", names == EXPECTED, str(names))
	check("todas se pueden abrir (las que faltan enseñan «Pronto», paso IU.4)", active == EXPECTED, str(active))
	check("se abre en Cuerpo", tabs.current_tab == 0, str(tabs.current_tab))


## Paso IU.4: las pestañas se eligen en la barra de arriba; las que faltan dicen «Pronto» y se pueden abrir.
func _check_top_tabs(main: Control) -> void:
	var bar: TabBar = main.top_bar.tab_bar
	var soon := 0
	for i in bar.get_tab_count():
		soon += int(bar.get_tab_title(i).ends_with("Pronto") and not bar.is_tab_disabled(i))
	check("siete accesos, cuatro «Pronto» y Taller al final",
		bar.get_tab_count() == 7 and bar.get_tab_title(6) == "Taller de Assets" and soon == 4 and not bar.get_tab_title(0).contains("Pronto")
		and not bar.get_tab_title(5).contains("Pronto"), str(soon))
	check("la pestaña de la ventana no se ve: está arriba", not main.tabs.tabs_visible)
	bar.current_tab = 2
	check("elegir Pelo arriba cambia la página", main.tabs.current_tab == 2)
	check("y la vista y las zonas siguen a la vista (IU.6c)", main.body_view.is_visible_in_tree()
		and main.zone_picker.is_visible_in_tree())
	bar.current_tab = 5
	check("Estilo enseña el Acabado (IU.6c)", main.finish_panel.is_visible_in_tree() and not main.slider_panel.is_visible_in_tree())
	main.zone_picker.zone_chosen.emit("Cabeza")
	check("elegir una zona vuelve a la pestaña Cuerpo", bar.current_tab == 0 and main.slider_panel.is_visible_in_tree())


func _check_workshop(main: Control) -> void:
	var bar: TabBar = main.top_bar.tab_bar
	var editor = main.editor
	var actions = main.body_actions
	var slider: HSlider = main.slider_panel.sliders["height"]
	var original := slider.value
	slider.value = 0.2 if original > 0.5 else 0.8
	var edited := slider.value
	check("el deslizador modifica el personaje", editor.can_undo() and is_equal_approx(editor.values.height, edited))
	bar.current_tab = 6
	await create_timer(main.FILE_REFRESH * 2).timeout
	check("solo se muestra la página del Taller", main.workshop_page.is_visible_in_tree()
		and not main.body_view.is_visible_in_tree() and not main.status_bar.is_visible_in_tree()
		and not main.report_section.is_visible_in_tree() and not actions.bones_button.is_visible_in_tree()
		and not main.top_bar.file_label.is_visible_in_tree() and not main.top_bar.actions.is_visible_in_tree())
	for key: Key in [KEY_Z, KEY_Y, KEY_O, KEY_S, KEY_E]:
		await _shortcut(key)
		check("el Taller ignora Ctrl+" + OS.get_keycode_string(key), is_equal_approx(editor.values.height, edited)
			and editor.can_undo() and not editor.can_redo() and not actions.save_dialog.visible
			and not actions.open_dialog.visible and not actions.file_dialog.visible)
	if actions.has_changes():
		main._on_close_requested()
		check("cerrar desde el Taller protege la edición", main.close_dialog.visible)
		main.close_dialog.hide()
		await process_frame
	bar.current_tab = 0
	check("Cuerpo recupera el editor, la zona y la edición pendiente", main.editor == editor
		and main.slider_panel.open_zone == "Cabeza" and main.slider_panel.is_visible_in_tree()
		and main.top_bar.file_label.text.ends_with("•") and not main.undo_button.disabled)
	await _shortcut(KEY_Z)
	check("Deshacer restaura el valor original", is_equal_approx(editor.values.height, original)
		and not actions.has_changes() and editor.can_redo())
	bar.current_tab = 5
	bar.current_tab = 6
	await _shortcut(KEY_Y)
	bar.current_tab = 5
	check("Estilo recupera el acabado y conserva Rehacer", main.finish_panel.is_visible_in_tree()
		and not main.workshop_page.visible and not main.redo_button.disabled and editor.can_redo())
	bar.current_tab = 0
	await _shortcut(KEY_E)
	check("al volver a Cuerpo Ctrl+E abre Exportar", actions.file_dialog.visible)
	actions.file_dialog.hide()
	await process_frame


func _shortcut(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.ctrl_pressed = true
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame


func _check_core_independent(folder: String) -> void:
	var offenders: Array = []
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "gdshader", "tscn", "tres"]:
			if FileAccess.get_file_as_string(folder.path_join(file)).contains("app/"):
				offenders.append(file)
	check("ningún archivo del núcleo nombra app/", offenders.is_empty(), str(offenders))
