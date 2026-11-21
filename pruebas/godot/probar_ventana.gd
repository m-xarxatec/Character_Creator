extends SceneTree
# Paso 4.1: ventana del editor (godot/app/main.gd) con 6 pestañas (IU.4: Cuerpo y cinco «Pronto»); el núcleo no depende de la interfaz.
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
	check("la barra de arriba tiene las 6 pestañas y ninguna dice «Pronto» (pasos AB.13 y 9.4)",
		bar.get_tab_count() == 6 and soon == 0, str(soon))
	check("la pestaña de la ventana no se ve: está arriba", not main.tabs.tabs_visible)
	bar.current_tab = 2
	check("elegir Pelo arriba cambia la página", main.tabs.current_tab == 2)
	check("y la vista y las zonas siguen a la vista (IU.6c)", main.body_view.is_visible_in_tree()
		and main.zone_picker.is_visible_in_tree())
	bar.current_tab = 5
	check("Estilo enseña el Acabado (IU.6c)", main.finish_panel.is_visible_in_tree() and not main.slider_panel.is_visible_in_tree())
	main.zone_picker.zone_chosen.emit("Cabeza")
	check("elegir una zona vuelve a la pestaña Cuerpo", bar.current_tab == 0 and main.slider_panel.is_visible_in_tree())


func _check_core_independent(folder: String) -> void:
	var offenders: Array = []
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "gdshader", "tscn", "tres"]:
			if FileAccess.get_file_as_string(folder.path_join(file)).contains("app/"):
				offenders.append(file)
	check("ningún archivo del núcleo nombra app/", offenders.is_empty(), str(offenders))
