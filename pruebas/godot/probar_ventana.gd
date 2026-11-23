extends SceneTree
# TA.2a y TA.2b: navegación con cambios pendientes, modos del Taller y aislamiento del visor.
# TA.3c: edición de la espada con los controles reales, cotejada con el generador.
# TA.4c: recorrido de «Desde imagen» con PNG de user://ta4c_ventana (carpeta de este proyecto de pruebas; se borra al final).
# TA.5b: guardar y reabrir desde el Taller, con una biblioteca en user://ta5b_ventana (se borra al final).
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_ventana.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')

const EXPECTED := ["Cuerpo", "Cara y ojos", "Pelo", "Ropa", "Accesorios", "Estilo"]  # IU.4: Exportar ya no es pestaña
const SWORD_PARAMS := {"longitud_m": 1.0, "ancho_hoja_m": 0.09, "grosor_m": 0.018}
const SWORD_COLORS := {"hoja": "#B9C0C8", "guarda": "#77747A", "mango": "#514336"}
const SWORD_PARTS := ["hoja", "guarda", "mango", "pomo"]

var failures := 0
var generator: GDScript
var generations := 0
var mask_script: GDScript
var silhouette_script: GDScript
var analyses := 0
var image_builds := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame  # _ready() llega con el primer fotograma
	check("la ventana crea sus pestañas", main.tabs != null)
	if main.tabs != null:
		_check_tabs(main.tabs)
		_check_top_tabs(main)
		generator = load(root_dir.path_join("godot/addons/creador/taller_assets/sword_generator.gd"))
		await _check_workshop(main)
		await _check_sword_editor(main)
		await _check_image_editor(main, root_dir)
		await _check_library(main, root_dir)
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
	check("siete accesos, solo Cara y ojos dice «Pronto» (AB.13) y Taller al final",
		bar.get_tab_count() == 7 and bar.get_tab_title(6) == "Taller de Assets" and soon == 1
		and bar.get_tab_title(1).contains("Pronto"), str(soon))
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
	_check_workspace(main)
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
	check("el Taller conserva Camiseta al regresar", main.workshop_page.title.text == "Camiseta")
	await _shortcut(KEY_Y)
	bar.current_tab = 5
	check("Estilo recupera el acabado y conserva Rehacer", main.finish_panel.is_visible_in_tree()
		and not main.workshop_page.visible and not main.redo_button.disabled and editor.can_redo())
	bar.current_tab = 0
	await _shortcut(KEY_E)
	check("al volver a Cuerpo Ctrl+E abre Exportar", actions.file_dialog.visible)
	actions.file_dialog.hide()
	await process_frame


func _check_workspace(main: Control) -> void:
	var page = main.workshop_page
	check("el Taller abre en Espada", page.title.text == "Espada")
	_check_sword_mesh(page, "al abrir, la malla real con sus cuatro piezas", SWORD_PARAMS, SWORD_COLORS)
	var expected := {"Espada": "hoja", "Desde imagen": "extrusión", "Camiseta": "mangas"}
	for button: Button in page.modes.get_buttons():
		button.pressed.emit()
		var selected := 0
		for option: Button in page.modes.get_buttons():
			selected += int(option.button_pressed)
		check("propiedades de " + button.text, page.title.text == button.text
			and page.properties.text.contains(expected[button.text]) and button.button_pressed and selected == 1)
	var names := []
	for button: Button in page.actions.get_children():
		if button.disabled:
			names.append(button.text)
	check("cuatro acciones pendientes", names == ["Generar", "Guardar", "Equipar", "Exportar"])
	var camera = page.camera
	var body = main.body_view.camera
	check("mundos independientes", camera.get_world_3d() != body.get_world_3d())
	var before: Transform3D = body.transform
	var yaw: float = camera.yaw
	var distance: float = camera.distance
	var center: Vector2 = page.view.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.position = center
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(32, 0)
	motion.relative = Vector2(32, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	press = press.duplicate()
	press.pressed = false
	root.push_input(press, true)
	var wheel := InputEventMouseButton.new()
	wheel.position = center
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	check("arrastrar gira la muestra", not is_equal_approx(yaw, camera.yaw))
	check("la rueda acerca la muestra", camera.distance < distance)
	check("el encuadre del personaje se conserva", before.is_equal_approx(body.transform))


## TA.3c: cada control real cambia la malla visible, y la edición sobrevive a los cambios de modo y de pestaña.
func _check_sword_editor(main: Control) -> void:
	var bar: TabBar = main.top_bar.tab_bar
	var page = main.workshop_page
	var panel = page.sword_panel
	var editor = main.editor
	var body_values: Dictionary = editor.values.duplicate()
	var history := [editor.can_undo(), editor.can_redo()]
	page.sword_generated.connect(func() -> void: generations += 1)
	bar.current_tab = 6
	await process_frame
	page.modes.get_buttons()[0].pressed.emit()
	await process_frame
	check("en Espada se editan los controles, no la lista prevista", panel.is_visible_in_tree()
		and not page.properties.visible and not page.generate_button.disabled)
	check("Guardar activo; Equipar y Exportar siguen pendientes", not page.save_button.disabled
		and page.actions.get_child(2).disabled and page.actions.get_child(3).disabled)
	check("el visor indica triángulos y tamaño real", page.info.text.begins_with("144 triángulos")
		and page.info.text.contains("0,297 × 1,260 × 0,059 m"), page.info.text)
	_check_view_buttons(page)
	page.camera.rotate_by(Vector2(40, 12))
	page.camera.zoom_by(-1)
	var yaw: float = page.camera.yaw
	var pitch: float = page.camera.pitch
	var distance: float = page.camera.distance
	var params := SWORD_PARAMS.duplicate()
	var colors := SWORD_COLORS.duplicate()
	_check_sword_fields(page, panel, params)
	_check_sword_colors(page, panel, params, colors)
	check("editar conserva el giro y el zoom", is_equal_approx(page.camera.yaw, yaw)
		and is_equal_approx(page.camera.pitch, pitch) and is_equal_approx(page.camera.distance, distance))
	var before := generations
	page.generate_button.pressed.emit()
	check("Generar regenera una vez la receta actual", generations == before + 1)
	_check_sword_mesh(page, "Generar conserva la edición", params, colors)
	await _check_sword_return(main, page, params, colors)
	_check_sword_error(page, params, colors)
	before = generations
	panel.reset_button.pressed.emit()
	check("Restablecer regenera una sola vez", generations == before + 1, str(generations - before))
	_check_sword_mesh(page, "Restablecer recupera la espada inicial", SWORD_PARAMS, SWORD_COLORS)
	check("Restablecer pone los controles y limpia las escalas", panel.numbers["longitud_m"].text == "1,000"
		and panel.numbers["escala_pomo"].text == "100" and panel.sliders["grosor_m"].value == 18
		and panel.color_buttons["hoja"].color.is_equal_approx(Color("#B9C0C8"))
		and not page.sword_recipe.parametros.has("escala_punta"))
	check("el historial del personaje no cambia", editor.values == body_values
		and [editor.can_undo(), editor.can_redo()] == history)
	bar.current_tab = 0
	await process_frame


func _check_view_buttons(page) -> void:
	for view_name: String in page.VIEWS:
		page.view_buttons[view_name].pressed.emit()
		check("la vista " + view_name + " orienta la cámara",
			is_equal_approx(page.camera.yaw, page.VIEWS[view_name].x) and is_equal_approx(page.camera.pitch, page.VIEWS[view_name].y))


## Extremos de longitud, número escrito (coma, recorte y texto inválido) y un cambio de cada proporción.
func _check_sword_fields(page, panel, params: Dictionary) -> void:
	for shown: float in [500.0, 1500.0]:
		panel.sliders["longitud_m"].value = shown
		params.longitud_m = shown / 1000.0
		_check_sword_mesh(page, "longitud extrema %.1f m" % params.longitud_m, params, SWORD_COLORS)
	_type_number(panel, "longitud_m", "0,75")
	params.longitud_m = 0.75
	_check_sword_mesh(page, "número escrito con coma", params, SWORD_COLORS)
	_type_number(panel, "ancho_hoja_m", "9")
	params.ancho_hoja_m = 0.135
	check("el número se recorta al máximo", panel.numbers["ancho_hoja_m"].text == "0,135", panel.numbers["ancho_hoja_m"].text)
	_check_sword_mesh(page, "ancho máximo escrito", params, SWORD_COLORS)
	_type_number(panel, "grosor_m", "abc")
	check("el texto inválido se ignora", panel.numbers["grosor_m"].text == "0,018" and page.sword_recipe.parametros.grosor_m == 0.018)
	panel.sliders["grosor_m"].value = 9
	params.grosor_m = 0.009
	_check_sword_mesh(page, "grosor mínimo", params, SWORD_COLORS)
	for key: String in panel.sliders:
		if key.begins_with("escala_"):
			panel.sliders[key].value = 125
			params[key] = 1.25
			_check_sword_mesh(page, "proporción " + key, params, SWORD_COLORS)


func _check_sword_colors(page, panel, params: Dictionary, colors: Dictionary) -> void:
	for region: String in ["hoja", "guarda", "mango"]:
		var hex: String = {"hoja": "#4968AA", "guarda": "#BB8844", "mango": "#224422"}[region]
		panel.color_buttons[region].color = Color.html(hex)
		panel.color_buttons[region].color_changed.emit(Color.html(hex))
		colors[region] = hex
		_check_sword_mesh(page, "color de " + region, params, colors)


## La edición sigue al volver de otro modo y de Cuerpo; los otros modos recuperan su muestra y sus acciones.
func _check_sword_return(main: Control, page, params: Dictionary, colors: Dictionary) -> void:
	var bar: TabBar = main.top_bar.tab_bar
	for index: int in [1, 2]:
		page.modes.get_buttons()[index].pressed.emit()
		check("%s recupera su panel y su muestra" % page.MODES[index], page.sample.mesh is BoxMesh
			and page.properties.visible and page.properties.text == page.PROPERTIES[index]
			and not page.sword_panel.visible and not page.info.visible and page.generate_button.disabled)
		page.modes.get_buttons()[0].pressed.emit()
		_check_sword_mesh(page, "al volver de " + page.MODES[index], params, colors)
	bar.current_tab = 0
	await process_frame
	bar.current_tab = 6
	await process_frame
	check("al volver de Cuerpo sigue en Espada", page.title.text == "Espada" and page.sword_panel.is_visible_in_tree())
	_check_sword_mesh(page, "al volver de Cuerpo", params, colors)


func _check_sword_error(page, params: Dictionary, colors: Dictionary) -> void:
	var valid: Variant = page.sample.mesh
	var good: float = page.sword_recipe.parametros.longitud_m
	page.sword_recipe.parametros.longitud_m = -1.0
	page.generate_sword()
	check("un error conserva la última malla y da el motivo", page.sample.mesh == valid and page.diagnosis.visible
		and page.diagnosis.text.contains("longitud_m"), page.diagnosis.text)
	page.sword_recipe.parametros.longitud_m = good
	page.generate_sword()
	check("generar bien retira el aviso", not page.diagnosis.visible)
	_check_sword_mesh(page, "tras recuperar el error", params, colors)


func _type_number(panel, key: String, text: String) -> void:
	panel.numbers[key].text = text
	panel.numbers[key].text_submitted.emit(text)


## Coteja la malla del visor con la que da el generador para unos valores decididos por la prueba, no por la página.
func _check_sword_mesh(page, label: String, params: Dictionary, colors: Dictionary) -> void:
	var result: Dictionary = generator.generate({"formato": "gamemolde-asset-receta", "version": 1, "id": "espada",
		"modo": "espada_parametrica", "autor": "Taller", "licencia": "propia", "parametros": params, "colores": colors})
	var shown: Mesh = page.sample.mesh
	var same: bool = result.error == "" and shown is ArrayMesh and shown.get_surface_count() == SWORD_PARTS.size()
	if same:
		for i in SWORD_PARTS.size():
			same = same and shown.surface_get_name(i) == SWORD_PARTS[i]
			same = same and shown.surface_get_arrays(i) == result.malla.surface_get_arrays(i)
			same = same and shown.surface_get_material(i).albedo_color == result.malla.surface_get_material(i).albedo_color
	check(label, same, result.error)


## TA.4c: cargar, editar cada control, error con la última pieza conservada, Restablecer y cambio de modo.
func _check_image_editor(main: Control, root_dir: String) -> void:
	var page = main.workshop_page
	var folder := ProjectSettings.globalize_path("user://ta4c_ventana")
	DirAccess.make_dir_recursive_absolute(folder)
	var core := root_dir.path_join("godot/addons/creador/taller_assets")
	mask_script = load(core.path_join("image_mask.gd"))
	silhouette_script = load(core.path_join("silhouette_mesh.gd"))
	page.image_analyzed.connect(func() -> void: analyses += 1)
	page.image_generated.connect(func() -> void: image_builds += 1)
	main.top_bar.tab_bar.current_tab = 6
	await process_frame
	page.modes.get_buttons()[1].pressed.emit()
	await process_frame
	check("Desde imagen enseña su panel y aún no tiene pieza", page.image_panel.is_visible_in_tree()
		and not page.sword_panel.visible and page.sample.mesh is BoxMesh and not page.info.visible)
	var alpha := _alpha_image()
	var alpha_path := folder.path_join("con_alfa.png")
	alpha.save_png(alpha_path)
	check("carga un PNG con alfa", page.load_image_file(alpha_path), page.diagnosis.text)
	_check_image_mesh(page, "la pieza sale del contorno", alpha, {}, {"altura_m": 1.0, "grosor_m": 0.02}, "#FFFFFF")
	check("el visor indica triángulos y tamaño", page.info.visible and page.info.text.contains("triángulos"), page.info.text)
	check("con alfa se ve Umbral y no Tolerancia", page.image_panel.rows["umbral_alfa"].visible
		and not page.image_panel.rows["tolerancia"].visible)
	check("con pieza se puede Guardar; Equipar y Exportar siguen desactivados", not page.save_button.disabled
		and page.actions.get_child(2).disabled and page.actions.get_child(3).disabled)
	_check_image_sizes(page, alpha)
	await _check_image_contour(page, alpha)
	_check_image_error(page, folder)
	_check_image_modes(page, alpha)
	await _check_image_background(page, folder)
	page.modes.get_buttons()[0].pressed.emit()
	main.top_bar.tab_bar.current_tab = 0
	await process_frame
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


## Altura, grosor y color rehacen la pieza al momento, sin recalcular el contorno.
func _check_image_sizes(page, image: Image) -> void:
	var panel = page.image_panel
	var before := analyses
	var builds := image_builds
	panel.sliders["altura_m"].value = 1500
	_check_image_mesh(page, "la altura cambia la pieza al momento", image, {}, {"altura_m": 1.5, "grosor_m": 0.02}, "#FFFFFF")
	_type_number(panel, "grosor_m", "0,05")
	_check_image_mesh(page, "el grosor escrito cambia la pieza", image, {}, {"altura_m": 1.5, "grosor_m": 0.05}, "#FFFFFF")
	panel.color_button.color = Color("#4968AA")
	panel.color_button.color_changed.emit(Color("#4968AA"))
	_check_image_mesh(page, "el color cambia la pieza", image, {}, {"altura_m": 1.5, "grosor_m": 0.05}, "#4968AA")
	check("cada cambio rehace la pieza una vez", image_builds == builds + 3, str(image_builds - builds))
	check("medidas y color no recalculan el contorno", analyses == before, str(analyses - before))
	_type_number(panel, "altura_m", "99")
	check("la altura escrita se recorta al máximo", is_equal_approx(page.image_recipe.parametros.altura_m, 3.0))
	_type_number(panel, "grosor_m", "0")
	check("el grosor escrito se recorta al mínimo", is_equal_approx(page.image_recipe.parametros.grosor_m, 0.002))
	panel.reset_button.pressed.emit()
	_check_image_mesh(page, "Restablecer recupera la pieza inicial", image, {}, {"altura_m": 1.0, "grosor_m": 0.02}, "#FFFFFF")
	check("Restablecer pone los controles", panel.numbers["altura_m"].text == "1,000" and panel.numbers["grosor_m"].text == "0,020"
		and panel.color_button.color.is_equal_approx(Color.WHITE))


## Los ajustes del contorno esperan: varios cambios seguidos dan un solo análisis.
func _check_image_contour(page, image: Image) -> void:
	var panel = page.image_panel
	var size := {"altura_m": 1.0, "grosor_m": 0.02}
	var before := analyses
	panel.sliders["umbral_alfa"].value = 40
	panel.sliders["umbral_alfa"].value = 30
	panel.sliders["umbral_alfa"].value = 20
	check("el contorno espera al último cambio", analyses == before, str(analyses - before))
	await create_timer(page.CONTOUR_DELAY * 2.0).timeout
	check("tres cambios seguidos, un solo análisis", analyses == before + 1, str(analyses - before))
	_check_image_mesh(page, "el umbral cambia la pieza", image, {"umbral_alfa": 0.2}, size, "#FFFFFF")
	panel.sliders["simplificacion"].value = 30
	await create_timer(page.CONTOUR_DELAY * 2.0).timeout
	_check_image_mesh(page, "simplificar cambia el contorno", image, {"umbral_alfa": 0.2, "simplificacion": 3.0}, size, "#FFFFFF")
	panel.invert_box.button_pressed = true
	await create_timer(page.CONTOUR_DELAY * 2.0).timeout
	check("invertir llega al análisis", page.image_options.invertir == true)
	panel.invert_box.button_pressed = false
	panel.reset_button.pressed.emit()
	var count := analyses
	await create_timer(page.CONTOUR_DELAY * 2.0).timeout
	check("Restablecer cancela la espera pendiente", analyses == count, str(analyses - count))
	_check_image_mesh(page, "Restablecer recupera el contorno", image, {}, size, "#FFFFFF")


## Un archivo malo no toca la última pieza válida ni su receta.
func _check_image_error(page, folder: String) -> void:
	var valid: Variant = page.sample.mesh
	var saved_recipe: Dictionary = page.image_recipe.duplicate(true)
	var bad_path := folder.path_join("danado.png")
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("esto no es un png")
	file.close()
	check("un archivo dañado no se carga", not page.load_image_file(bad_path))
	check("el error conserva la pieza y da el motivo", page.sample.mesh == valid and page.image_recipe == saved_recipe
		and page.diagnosis.visible and page.diagnosis.text.contains("PNG"), page.diagnosis.text)
	var heavy_path := folder.path_join("pesado.png")
	var heavy := FileAccess.open(heavy_path, FileAccess.WRITE)
	heavy.store_buffer(FileAccess.get_file_as_bytes(folder.path_join("con_alfa.png")))
	heavy.seek(256 * 1024 * 1024)
	heavy.store_8(0)
	heavy.close()
	check("un archivo de más de 256 MB no se carga", not page.load_image_file(heavy_path))
	DirAccess.remove_absolute(heavy_path)
	check("avisa del tope y conserva la pieza", page.sample.mesh == valid and page.image_recipe == saved_recipe
		and page.diagnosis.visible and page.diagnosis.text.contains("máximo es 256 MB")
		and page.diagnosis.get_theme_color("font_color") == page.get_theme_color("font_color", "NivelAviso"), page.diagnosis.text)
	var noisy := Image.create_empty(16, 16, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 16:
			noisy.set_pixel(x, y, Color.BLACK if (x + y) % 2 == 0 else Color.WHITE)
	noisy.set_pixel(0, 0, Color.RED)
	noisy.set_pixel(15, 15, Color.GREEN)
	var noisy_path := folder.path_join("sin_fondo.png")
	noisy.save_png(noisy_path)
	check("una imagen sin fondo claro no da pieza", not page.load_image_file(noisy_path))
	check("el análisis fallido conserva la pieza y su receta", page.sample.mesh == valid
		and page.image_recipe == saved_recipe and page.diagnosis.text.contains("contorno"), page.diagnosis.text)
	check("tras ese fallo se puede ajustar la tolerancia", page.image_panel.rows["tolerancia"].visible)
	check("una imagen válida retira el aviso", page.load_image_file(folder.path_join("con_alfa.png"))
		and not page.diagnosis.visible, page.diagnosis.text)


## Cambiar de modo no pierde la imagen ni la espada.
func _check_image_modes(page, image: Image) -> void:
	var shown: Variant = page.sample.mesh
	page.modes.get_buttons()[0].pressed.emit()
	_check_sword_mesh(page, "Espada sigue igual tras usar la imagen", SWORD_PARAMS, SWORD_COLORS)
	check("en Espada no se ve el panel de imagen", not page.image_panel.visible)
	page.modes.get_buttons()[2].pressed.emit()
	check("Camiseta enseña su muestra", page.sample.mesh is BoxMesh and page.planned.visible and not page.info.visible)
	page.modes.get_buttons()[1].pressed.emit()
	check("al volver sigue la misma pieza", page.sample.mesh == shown and page.image_panel.visible and page.info.visible)
	_check_image_mesh(page, "y coincide con su contorno", image, {}, {"altura_m": 1.0, "grosor_m": 0.02}, "#FFFFFF")


## Sin transparencia manda la tolerancia.
func _check_image_background(page, folder: String) -> void:
	var opaque := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	opaque.fill(Color(0.0, 0.0, 1.0))
	opaque.fill_rect(Rect2i(16, 8, 32, 48), Color.WHITE)
	opaque.fill_rect(Rect2i(48, 20, 10, 12), Color(0.2, 0.2, 1.0))
	var path := folder.path_join("fondo_color.png")
	opaque.save_png(path)
	check("carga un PNG con fondo de color", page.load_image_file(path), page.diagnosis.text)
	check("sin alfa se ve Tolerancia y no Umbral", page.image_panel.rows["tolerancia"].visible
		and not page.image_panel.rows["umbral_alfa"].visible)
	check("avisa de que el fondo sale del color", page.image_panel.notes.visible
		and page.image_panel.notes.text.contains("esquinas"), page.image_panel.notes.text)
	var size := {"altura_m": 1.0, "grosor_m": 0.02}
	_check_image_mesh(page, "la tolerancia inicial incluye la franja", opaque, {}, size, "#FFFFFF")
	var wide: AABB = page.sample.mesh.get_aabb()
	page.image_panel.sliders["tolerancia"].value = 50
	await create_timer(page.CONTOUR_DELAY * 2.0).timeout
	_check_image_mesh(page, "la tolerancia cambia la pieza", opaque, {"tolerancia": 0.5}, size, "#FFFFFF")
	check("más tolerancia deja fuera la franja", page.sample.mesh.get_aabb().size.x < wide.size.x,
		"%s < %s" % [page.sample.mesh.get_aabb().size.x, wide.size.x])
	page.image_panel.reset_button.pressed.emit()


## Una silueta con una zona semitransparente: el umbral decide si entra.
func _alpha_image() -> Image:
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(16, 8, 24, 48), Color.WHITE)
	image.fill_rect(Rect2i(40, 20, 14, 12), Color(1.0, 1.0, 1.0, 0.4))
	return image


## Coteja la pieza del visor con la que dan el análisis y el generador para valores decididos por la prueba.
func _check_image_mesh(page, label: String, image: Image, options: Dictionary, params: Dictionary, color: String) -> void:
	var analysis: Dictionary = mask_script.analyze(image, options)
	var same: bool = analysis.error == ""
	var detail: String = analysis.error
	if same:
		var result: Dictionary = silhouette_script.generate({"formato": "gamemolde-asset-receta", "version": 1, "id": "imagen",
			"modo": "extrusion_imagen", "autor": "Taller", "licencia": "propia",
			"fuente": {"archivo": "fuentes/prueba.png", "sha256": "ab".repeat(32)},
			"parametros": params, "colores": {"principal": color}}, analysis.contorno)
		var shown: Mesh = page.sample.mesh
		detail = result.error
		same = result.error == "" and shown is ArrayMesh and shown.get_surface_count() == 1
		same = same and shown.surface_get_arrays(0) == result.malla.surface_get_arrays(0)
		same = same and shown.surface_get_material(0).albedo_color == result.malla.surface_get_material(0).albedo_color
	check(label, same, detail)


## TA.5b: guardar, ver en la lista, reabrir, actualizar, imagen perdida y otra sesión.
func _check_library(main: Control, root_dir: String) -> void:
	var page = main.workshop_page
	var folder := ProjectSettings.globalize_path("user://ta5b_ventana")
	_remove_tree(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	var store_script: GDScript = load(root_dir.path_join("godot/addons/creador/taller_assets/asset_store.gd"))
	page.store = store_script.new(folder.path_join("packs"), folder.path_join("temporal"))
	main.top_bar.tab_bar.current_tab = 6
	await process_frame
	page.modes.get_buttons()[0].pressed.emit()
	page.sword_panel.reset_button.pressed.emit()
	page.refresh_library()
	check("biblioteca vacía: lo dice", page.library_panel.empty_label.visible and not page.library_panel.list.visible)
	page.modes.get_buttons()[2].pressed.emit()
	check("Camiseta todavía no se guarda", page.save_button.disabled)
	page.modes.get_buttons()[0].pressed.emit()
	await _check_save_dialog(page)
	await _check_reopen_sword(page)
	await _check_image_library(page, folder)
	await _check_library_damage(page, store_script, folder)
	page.modes.get_buttons()[0].pressed.emit()
	main.top_bar.tab_bar.current_tab = 0
	await process_frame
	_remove_tree(folder)


func _check_save_dialog(page) -> void:
	var dialog = page.save_dialog
	page.sword_panel.sliders["longitud_m"].value = 1200
	page.save_button.pressed.emit()
	check("Guardar abre el diálogo", dialog.visible)
	check("sin nombre ni autor no se puede confirmar", dialog.get_ok_button().disabled)
	check("una espada no pide derechos de imagen", not dialog.rights_box.visible and not dialog.as_new_box.visible)
	_type_field(dialog.name_edit, "Espada larga")
	check("falta el autor", dialog.get_ok_button().disabled)
	dialog.confirmed.emit()
	check("Intro con datos incompletos no guarda", page.library_panel.ids.is_empty() and dialog.visible)
	_type_field(dialog.author_edit, "Autora")
	check("con nombre y autor se puede confirmar", not dialog.get_ok_button().disabled)
	dialog.confirmed.emit()
	await process_frame
	check("guarda y cierra el diálogo", page.library_panel.ids.size() == 1 and not dialog.visible, str(page.library_panel.ids))
	check("la pieza sale en la lista", page.library_panel.list.get_item_text(0) == "Espada larga"
		and page.library_panel.list.visible and not page.library_panel.empty_label.visible)
	check("queda seleccionada", page.library_panel.list.is_selected(0))
	page.save_button.pressed.emit()
	check("reabierta propone su nombre, autor y copia", dialog.name_edit.text == "Espada larga"
		and dialog.author_edit.text == "Autora" and dialog.as_new_box.visible)
	dialog.as_new_box.button_pressed = true
	dialog.confirmed.emit()
	await process_frame
	check("un nombre repetido deja el diálogo abierto con el motivo", dialog.visible and dialog.message.visible
		and dialog.message.text.contains("Ya hay") and page.library_panel.ids.size() == 1, dialog.message.text)
	dialog.hide()


func _check_reopen_sword(page) -> void:
	var library = page.library_panel
	var first: String = library.ids[0]
	var long_params := SWORD_PARAMS.merged({"longitud_m": 1.2}, true)
	var copy: Dictionary = await page.save_piece("Daga", "Autora", "CC0-1.0", true)
	check("Guardar como nueva crea otra pieza", copy.error == "" and copy.id != first and library.ids.size() == 2, str(copy))
	page.sword_panel.sliders["longitud_m"].value = 700
	var short_params := SWORD_PARAMS.merged({"longitud_m": 0.7}, true)
	var updated: Dictionary = await page.save_piece("Daga", "Autora", "CC0-1.0")
	check("Guardar actualiza la pieza abierta", updated.get("id") == copy.id and library.ids.size() == 2, str(updated))
	library.list.item_clicked.emit(library.ids.find(first), Vector2.ZERO, MOUSE_BUTTON_LEFT)
	_check_sword_mesh(page, "un clic reabre la pieza guardada", long_params, SWORD_COLORS)
	check("reabrir pone sus controles", page.sword_panel.numbers["longitud_m"].text == "1,200" and library.list.is_selected(library.ids.find(first)))
	check("reabrir recuerda cuál se edita", page.open_pieces[page.SWORD].id == first and page.open_pieces[page.SWORD].autor == "Autora")
	library.list.item_clicked.emit(library.ids.find(copy.id), Vector2.ZERO, MOUSE_BUTTON_RIGHT)
	check("el botón derecho no reabre", page.open_pieces[page.SWORD].id == first)
	library.list.item_clicked.emit(library.ids.find(copy.id), Vector2.ZERO, MOUSE_BUTTON_LEFT)
	_check_sword_mesh(page, "la pieza actualizada conserva su edición", short_params, SWORD_COLORS)
	check("conserva su licencia", page.open_pieces[page.SWORD].licencia == "CC0-1.0")


func _check_image_library(page, folder: String) -> void:
	var library = page.library_panel
	var dialog = page.save_dialog
	var image := _alpha_image()
	var path := folder.path_join("origen.png")
	image.save_png(path)
	page.modes.get_buttons()[1].pressed.emit()
	page.image_panel.reset_button.pressed.emit()
	check("carga la imagen a guardar", page.load_image_file(path), page.diagnosis.text)
	page.image_panel.sliders["altura_m"].value = 1500
	page.image_panel.sliders["umbral_alfa"].value = 20
	page.save_button.pressed.emit()  # con el ajuste aún en espera: lo aplica antes de guardar
	var size := {"altura_m": 1.5, "grosor_m": 0.02}
	_check_image_mesh(page, "guardar aplica el ajuste pendiente", image, {"umbral_alfa": 0.2}, size, "#FFFFFF")
	check("una imagen exige confirmar los derechos", dialog.rights_box.visible)
	_type_field(dialog.name_edit, "Silueta")
	_type_field(dialog.author_edit, "Autora")
	check("sin confirmar no se puede guardar", dialog.get_ok_button().disabled)
	dialog.rights_box.button_pressed = true
	check("confirmados se puede guardar", not dialog.get_ok_button().disabled)
	dialog.confirmed.emit()
	await process_frame
	check("guarda la pieza de imagen", library.ids.size() == 3 and not dialog.visible, dialog.message.text)
	var id: String = page.open_pieces[page.IMAGE].id
	DirAccess.remove_absolute(path)
	check("sin el PNG original se puede seguir guardando", not page.save_button.disabled)
	page.save_button.pressed.emit()
	check("la misma imagen no vuelve a pedir derechos", not dialog.rights_box.visible)
	dialog.hide()
	page.image_panel.sliders["altura_m"].value = 2000
	page.image_panel.reset_button.pressed.emit()
	await create_timer(page.CONTOUR_DELAY * 2.0).timeout
	library.list.item_clicked.emit(library.ids.find(id), Vector2.ZERO, MOUSE_BUTTON_LEFT)
	_check_image_mesh(page, "reabrir recupera la pieza de imagen", image, {"umbral_alfa": 0.2}, size, "#FFFFFF")
	check("reabrir pone medidas y ajustes", page.image_panel.numbers["altura_m"].text == "1,500"
		and page.image_panel.numbers["umbral_alfa"].text == "20" and page.image_options.umbral_alfa == 0.2)
	check("reabrir enseña la imagen", page.image_panel.preview.texture != null and page.image_panel.preview.contour == page.image_contour)
	var before := analyses
	await create_timer(page.CONTOUR_DELAY * 2.0).timeout
	check("reabrir no deja análisis pendientes", analyses == before)
	_check_lost_source(page, id, image, size)


## Sin su imagen: aviso, contorno bloqueado, medidas editables y no se guarda hasta elegirla.
func _check_lost_source(page, id: String, image: Image, size: Dictionary) -> void:
	var library = page.library_panel
	var panel = page.image_panel
	var source: String = page.store.packs_folder.path_join(id).path_join(page.image_origin.archivo)
	var keep := FileAccess.get_file_as_bytes(source)
	DirAccess.remove_absolute(source)
	library.list.item_clicked.emit(library.ids.find(id), Vector2.ZERO, MOUSE_BUTTON_LEFT)
	_check_image_mesh(page, "sin imagen, la pieza se abre igual", image, {"umbral_alfa": 0.2}, size, "#FFFFFF")
	check("avisa de la imagen perdida", library.notes.visible and library.notes.text.contains("imagen de origen"), library.notes.text)
	check("bloquea el contorno", not panel.sliders["umbral_alfa"].editable and not panel.numbers["simplificacion"].editable
		and panel.invert_box.disabled and panel.preview.texture == null)
	check("sin imagen no se guarda y explica por qué", page.save_button.disabled and page.pending.text.contains("elige otra vez"))
	panel.sliders["altura_m"].value = 1200
	_check_image_mesh(page, "las medidas se siguen editando", image, {"umbral_alfa": 0.2}, {"altura_m": 1.2, "grosor_m": 0.02}, "#FFFFFF")
	panel.reset_button.pressed.emit()
	_check_image_mesh(page, "Restablecer funciona sin imagen", image, {"umbral_alfa": 0.2}, {"altura_m": 1.0, "grosor_m": 0.02}, "#FFFFFF")
	var again := source.get_base_dir().path_join("elegida.png")
	var file := FileAccess.open(again, FileAccess.WRITE)
	file.store_buffer(keep)
	file.close()
	check("elegir la imagen de nuevo funciona", page.load_image_file(again), page.diagnosis.text)
	check("y desbloquea el contorno y Guardar", panel.sliders["umbral_alfa"].editable and not panel.invert_box.disabled
		and not page.save_button.disabled)
	DirAccess.remove_absolute(again)
	file = FileAccess.open(source, FileAccess.WRITE)
	file.store_buffer(keep)
	file.close()


## Una pieza dañada avisa y no se lleva a las demás; otra sesión ve la biblioteca igual.
func _check_library_damage(page, store_script: GDScript, folder: String) -> void:
	var library = page.library_panel
	var victim: String = library.ids[0]
	var path: String = page.store.packs_folder.path_join(victim).path_join("edicion.json")
	var keep := FileAccess.get_file_as_bytes(path)
	var shown: Mesh = page.sample.mesh
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{")
	file.close()
	check("abrir una pieza recién dañada no cambia lo que hay", not page.open_piece(victim) and page.sample.mesh == shown
		and library.notes.text.contains("dañada"), library.notes.text)
	page.refresh_library()
	check("la dañada sale de la lista con un aviso", library.ids.size() == 2 and not victim in library.ids
		and library.notes.visible, library.notes.text)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(keep)
	file.close()
	var other = page.get_script().new()
	other.store = store_script.new(folder.path_join("packs"), folder.path_join("temporal"))
	root.add_child(other)
	await process_frame
	check("otra sesión ve las tres piezas", other.library_panel.ids.size() == 3, str(other.library_panel.ids))
	check("y las reabre", other.open_piece(page.open_pieces[page.SWORD].id) and other.title.text == "Espada")
	other.free()


func _type_field(field: LineEdit, text: String) -> void:
	field.text = text
	field.text_changed.emit(text)


func _remove_tree(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for child in DirAccess.get_directories_at(folder):
		_remove_tree(folder.path_join(child))
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


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
