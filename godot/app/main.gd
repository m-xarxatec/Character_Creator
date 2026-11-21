extends Control
# Paso 4.1: ventana del editor con las pestañas de la maqueta de la pestaña Cuerpo (hoy diseno/maqueta-v2.html); solo Cuerpo está activa.
# Abrir: (ulimit -v 4000000; timeout 900 godot --path godot)
# Autoprueba (paso A2): (ulimit -v 4000000; timeout 120 godot --headless --path godot -- --autoprueba)
# Las pestañas se crean aquí (no en main.tscn) para que la prueba pueda cargar este script desde otro proyecto.
# Cuerpo: la vista 3D (body_view.gd) a la izquierda y el panel de deslizadores (slider_panel.gd) a la derecha; los dos
# siguen al editor (body_editor.gd). Bajo los deslizadores, el panel Acabado (finish_panel.gd, paso 4.7b). Debajo, la barra de body_actions.gd (paso 4.5; Guardar y Abrir preset, paso 7.0). Ctrl+Z deshace; Ctrl+Mayús+Z o Ctrl+Y rehacen (acciones ui_undo y ui_redo de Godot).
# Paso 5.4: con Probar huesos o una animación se calcula el informe (report_panel.gd); su botón de zona sale de la
# prueba y abre esa zona. Paso P.2: el informe va en un desplegable bajo la vista (report_section.gd), plegado al
# empezar; los deslizadores no se ocultan nunca.
# Paso P.4: al cerrar con cambios sin guardar, close_dialog pregunta: Guardar… / Salir sin guardar / Cancelar.
# Pasos IU.1b y IU.1c: el tema de tema/theme_builder.gd en la raíz (oscuro por defecto, D34) y un botón pequeño
# «Claro» / «Oscuro» en la barra de abajo que lo cambia y lo recuerda (settings_file.gd).
# Paso IU.2: iconos en las pestañas, en Licencias y en el botón de tema (sol o luna, sin texto).
# Paso P.8b: botón «Comandos» (junto al sol/luna) que abre la lista de atajos (commands_dialog.gd).
# Paso IU.4: barra superior (top_bar.gd) con la marca, el archivo (• si hay cambios), las pestañas (Exportar ya no es
# pestaña: D35; las que faltan dicen «Pronto») y Deshacer, Rehacer, Abrir, Guardar y Exportar (botón principal).
# Paso IU.5: a la izquierda de la vista, el panel de zonas (zone_picker.gd): silueta y lista; sigue al panel derecho.
# Paso IU.5c: un botón en su borde lo pliega («<») y lo despliega («>»).
# Paso IU.6c: [zonas] [<] [vista + informe] [panel derecho, 360 px]. Las pestañas solo cambian el panel derecho
# (Cuerpo = ajustes, Estilo = Acabado, el resto «Pronto»): la vista y las zonas se quedan.
# Paso IU.8: abajo del todo, la barra de estado (status_bar.gd): informe, altura y cabezas (measures.gd, en reposo) y
# presupuesto.
# Paso IU.9: botón «Ajustes» (delante de «Comandos») con el tema, el tamaño de la interfaz y «Reducir animaciones»
# (settings_dialog.gd); se aplican al momento y se recuerdan (settings_file.gd).

const BodyView := preload("body_view.gd")
const WorkshopPage := preload("taller_assets/workshop_page.gd")
const SliderPanel := preload("slider_panel.gd")
const BodyEditor := preload("body_editor.gd")
const BodyActions := preload("body_actions.gd")
const FinishPanel := preload("finish_panel.gd")
const ReportSection := preload("report_section.gd")
const LicensesDialog := preload("licenses_dialog.gd")
const ThemeBuilder := preload("tema/theme_builder.gd")
const CommandsDialog := preload("commands_dialog.gd")
const SettingsDialog := preload("settings_dialog.gd")
const SettingsFile := preload("settings_file.gd")
const TopBar := preload("top_bar.gd")
const StatusBar := preload("status_bar.gd")
const Measures := preload("measures.gd")
const Tokens := preload("tema/tokens.gd")
const ZonePicker := preload("zone_picker.gd")
const Motion := preload("motion.gd")
const TAB_NAMES := ["Cuerpo", "Cara y ojos", "Pelo", "Ropa", "Accesorios", "Estilo"]
const WORKSHOP := "Taller de Assets"
const TAB_ICONS := ["cuerpo", "cara", "pelo", "ropa", "accesorios", "estilo"]  # paso IU.2
## Paso IU.4: pestañas que aún no existen → qué llegará (dicen «Pronto», se pueden abrir y lo cuentan).
const SOON := {
	"Cara y ojos": "ojos, cejas y expresiones.",
	"Pelo": "elegir peinados y ajustarlos a la cabeza.",
	"Ropa": "prendas que siguen al cuerpo al moverlo.",
	"Accesorios": "armas, gafas, cuernos y otras piezas en las manos, la espalda o la cadera.",
}
const FILE_REFRESH := 0.3  # s: cada cuánto se mira si hay cambios sin guardar (el • de la barra)
const ACTIVE_TAB := 0

var tabs: TabContainer
var character_page: Control
var workshop_page: WorkshopPage
var body_view: SubViewportContainer
var slider_panel: ScrollContainer
var body_actions: HBoxContainer
var finish_panel: VBoxContainer
var report_panel: ScrollContainer  # ReportPanel, dentro de report_section
var report_section: VBoxContainer
var editor  # BodyEditor (null si la especie no cargó)
var licenses: AcceptDialog  # paso 7.3b
var close_dialog: ConfirmationDialog  # paso P.4
var theme_button: Button  # paso IU.1c
var commands_button: Button  # paso P.8b
var commands: AcceptDialog  # paso P.8b
var settings_button: Button  # paso IU.9
var settings: AcceptDialog  # paso IU.9
var ui_scale := 1.0  # paso IU.9
var reduce_motion := false  # paso IU.9
var grid := false  # paso IU.3: rejilla en el suelo de la vista
var light_turn := 0.0  # paso IU.3: luz de vista previa, solo en esta sesión
var light_energy := 1.0
var dark := true  # paso IU.1c: tema en uso
var top_bar: PanelContainer  # paso IU.4
var undo_button: Button  # paso IU.4
var redo_button: Button  # paso IU.4
var zone_picker: TabContainer  # paso IU.5
var fold_button: Button  # paso IU.5c
var status_bar: PanelContainer  # paso IU.8
var measures  # paso IU.8: Measures (null si la especie no cargó)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark = SettingsFile.get_dark()
	theme = ThemeBuilder.build(dark)
	var background := Panel.new()  # paso IU.6c: el fondo de la ventana (antes lo pintaba la página de la pestaña)
	background.theme_type_variation = "Fondo"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	top_bar = TopBar.new()
	top_bar.setup(TAB_NAMES + [WORKSHOP], TAB_ICONS + ["prenda"], SOON)
	column.add_child(top_bar)
	character_page = _body()
	column.add_child(character_page)
	workshop_page = WorkshopPage.new()
	workshop_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workshop_page.hide()
	column.add_child(workshop_page)
	body_actions = BodyActions.new()
	body_actions.name = "Acciones"
	column.add_child(body_actions)
	status_bar = StatusBar.new()
	status_bar.report_pressed.connect(func() -> void: report_section.set_open(true))
	column.add_child(status_bar)
	tabs.current_tab = ACTIVE_TAB
	top_bar.tab_bar.current_tab = ACTIVE_TAB
	top_bar.tab_bar.tab_changed.connect(_select_page)
	if body_view.error == "":  # la vista ya cargó la especie (su _ready va al entrar en el árbol)
		editor = BodyEditor.new(body_view.species.sliders, body_view.values)
		editor.changed.connect(func() -> void: body_view.set_values(editor.values))
		slider_panel.zone_opened.connect(zone_picker.select)
		slider_panel.setup(editor)
		zone_picker.setup(slider_panel.zones, _zone_counts())
		zone_picker.select(slider_panel.open_zone)
		zone_picker.zone_chosen.connect(slider_panel.open)
		zone_picker.zone_chosen.connect(func(_zone: String) -> void: top_bar.tab_bar.current_tab = ACTIVE_TAB)
		body_view.zone_touched.connect(_on_zone_touched)  # paso IU.7a: igual que elegirla en la silueta
		body_actions.setup(body_view, editor)
		finish_panel.setup(body_view)
		body_actions.test_changed.connect(update_report)
		body_actions.look_changed.connect(finish_panel.refresh)
		report_panel.zone_chosen.connect(_on_zone_chosen)
		_fill_top_bar()
		_start_measures()
	licenses = LicensesDialog.new()
	add_child(licenses)
	var licenses_button := Button.new()
	licenses_button.text = "Licencias"
	licenses_button.icon = ThemeBuilder.icon("licencias")
	licenses_button.pressed.connect(func() -> void: licenses.popup_centered_ratio(0.7))
	body_actions.add_child(licenses_button)
	commands = CommandsDialog.new()
	add_child(commands)
	commands_button = Button.new()
	commands_button.text = "Comandos"
	commands_button.icon = ThemeBuilder.icon("teclado")
	commands_button.theme_type_variation = "BotonFantasma"
	commands_button.tooltip_text = "Atajos de teclado y ratón"
	commands_button.pressed.connect(func() -> void: commands.popup_centered())
	commands_button.shortcut = _f1_shortcut()  # paso IU.10b: el atajo del botón vale esté donde esté el foco
	body_actions.add_child(commands_button)
	settings = SettingsDialog.new()
	add_child(settings)
	settings.dark_chosen.connect(set_dark)
	settings.scale_chosen.connect(set_ui_scale)
	settings.reduce_motion_chosen.connect(set_reduce_motion)
	settings.grid_chosen.connect(set_grid)  # paso IU.3
	settings.light_chosen.connect(set_light)
	settings.touch_zones_chosen.connect(set_touch_zones)  # paso IU.7a
	settings_button = Button.new()
	settings_button.text = "Ajustes"
	settings_button.icon = ThemeBuilder.icon("ajustes")
	settings_button.theme_type_variation = "BotonFantasma"
	settings_button.tooltip_text = "Tema, tamaño de la interfaz y animaciones"
	settings_button.pressed.connect(open_settings)
	body_actions.add_child(settings_button)
	body_actions.move_child(settings_button, commands_button.get_index())  # «Comandos» sigue junto al sol/luna (P.8b)
	theme_button = Button.new()
	theme_button.theme_type_variation = "BotonFantasma"
	theme_button.pressed.connect(func() -> void: set_dark(not dark))
	body_actions.add_child(theme_button)
	_name_theme_button()
	ui_scale = SettingsFile.get_ui_scale()  # paso IU.9: se aplican sin volver a guardarlos
	get_window().content_scale_factor = ui_scale
	reduce_motion = SettingsFile.get_reduce_motion()
	if body_view.camera:
		body_view.camera.instant = reduce_motion
	body_view.set_touch_zones(SettingsFile.get_touch_zones())  # paso IU.7a
	grid = SettingsFile.get_grid()  # paso IU.3
	if body_view.floor_shadow:
		body_view.floor_shadow.set_grid(grid)
	if "--autoprueba" in OS.get_cmdline_user_args():
		_self_test()
	elif editor != null:
		_add_close_dialog()
		get_tree().auto_accept_quit = false


## Paso P.4: cerrar la ventana pasa por aquí (auto_accept_quit = false).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree() and not get_tree().auto_accept_quit:
		_on_close_requested()


func _on_close_requested() -> void:
	if body_actions.has_changes():
		close_dialog.popup_centered()
	else:
		get_tree().quit()


func _add_close_dialog() -> void:
	close_dialog = ConfirmationDialog.new()
	close_dialog.title = "Cerrar GameMolde"
	close_dialog.dialog_text = "Hay cambios sin guardar."
	close_dialog.ok_button_text = "Guardar…"
	close_dialog.cancel_button_text = "Cancelar"
	close_dialog.add_button("Salir sin guardar", true, "salir")
	close_dialog.confirmed.connect(body_actions.save_and_quit)
	close_dialog.custom_action.connect(_on_close_action)
	add_child(close_dialog)


func _on_close_action(action: StringName) -> void:
	if action == &"salir":
		get_tree().quit()


## Paso IU.4: Deshacer, Rehacer, Abrir, Guardar y Exportar (principal) arriba; el nombre del archivo, al día.
func _fill_top_bar() -> void:
	undo_button = _icon_button("deshacer", "Deshacer (Ctrl+Z)", editor.undo)
	redo_button = _icon_button("rehacer", "Rehacer (Ctrl+Y)", editor.redo)
	for button: Button in [body_actions.open_button, body_actions.save_button, body_actions.export_button]:
		top_bar.add_action(button)
	body_actions.export_button.theme_type_variation = "BotonPrincipal"
	var timer := Timer.new()
	timer.wait_time = FILE_REFRESH
	timer.timeout.connect(refresh_top_bar)
	add_child(timer)
	timer.start()
	editor.changed.connect(refresh_top_bar)  # paso IU.6b: Deshacer/Rehacer al momento, sin esperar al temporizador
	refresh_top_bar()


## Nombre del archivo con • si hay cambios, y Deshacer/Rehacer activos solo si se puede.
func refresh_top_bar() -> void:
	if workshop_page.visible:
		return
	top_bar.set_file(body_actions.file_name(), body_actions.has_changes())
	undo_button.disabled = not editor.can_undo()
	redo_button.disabled = not editor.can_redo()


func _select_page(index: int) -> void:
	var character := index < TAB_NAMES.size()
	character_page.visible = character
	workshop_page.visible = not character
	status_bar.visible = character
	top_bar.actions.visible = character
	top_bar.file_label.visible = character
	if editor != null:
		for control: Control in [body_actions.bones_button, body_actions.animation_list, body_actions.garment_check]:
			control.visible = character
	if character:
		tabs.current_tab = index
		if editor != null:
			refresh_top_bar()


func _icon_button(icon_name: String, help: String, action: Callable) -> Button:
	var button := Button.new()
	button.icon = ThemeBuilder.icon(icon_name)
	button.theme_type_variation = "BotonFantasma"
	button.tooltip_text = help
	button.pressed.connect(func() -> void: action.call())
	top_bar.add_action(button)
	return button


## Paso IU.5c: pliega o despliega el panel de zonas (la vista se agranda y vuelve a encuadrar sola).
## Paso IU.10b: F1 abre «Comandos».
func _f1_shortcut() -> Shortcut:
	var event := InputEventKey.new()
	event.keycode = KEY_F1
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut


func set_zones_visible(on: bool) -> void:
	if on:
		Motion.fade_in(zone_picker)  # paso IU.10c
	else:
		zone_picker.visible = false
	_name_fold_button()


func _name_fold_button() -> void:
	fold_button.icon = ThemeBuilder.icon("plegar" if zone_picker.visible else "desplegar")
	fold_button.tooltip_text = "Ocultar las zonas" if zone_picker.visible else "Mostrar las zonas"


## Paso IU.5: zona → número de ajustes visibles (filas de la tabla; las de dos lados cuentan una).
func _zone_counts() -> Dictionary:
	var counts := {}
	for row: Dictionary in editor.rows:
		counts[row["zona"]] = counts.get(row["zona"], 0) + 1
	return counts


func _soon_page(text: String) -> Control:
	var page := CenterContainer.new()
	var label := Label.new()
	label.text = "Pronto: " + text
	label.theme_type_variation = "Pista"
	page.add_child(label)
	return page


## Paso IU.9: abre «Ajustes» con los valores de ahora.
func open_settings() -> void:
	settings.refresh(dark, ui_scale, reduce_motion)
	settings.refresh_view(grid, light_turn, light_energy, body_view.touch_zones)
	settings.popup_centered()


## Paso IU.9: tamaño de toda la interfaz (uno de SettingsFile.SCALES); lo recuerda.
func set_ui_scale(scale: float) -> void:
	ui_scale = SettingsFile.nearest_scale(scale)
	SettingsFile.set_ui_scale(ui_scale)
	get_window().content_scale_factor = ui_scale


## Paso IU.9: «Reducir animaciones»: la cámara llega de golpe al encuadre; lo recuerda.
func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	SettingsFile.set_reduce_motion(on)
	if body_view.camera:
		body_view.camera.instant = on


## Paso IU.7a: «Elegir zona tocando el cuerpo»; lo recuerda.
func set_touch_zones(on: bool) -> void:
	body_view.set_touch_zones(on)
	SettingsFile.set_touch_zones(on)


func _on_zone_touched(zone: String) -> void:
	if zone in slider_panel.zones:
		zone_picker.zone_chosen.emit(zone)


## Paso IU.3: rejilla en el suelo de la vista; la recuerda.
func set_grid(on: bool) -> void:
	grid = on
	SettingsFile.set_grid(on)
	if body_view.floor_shadow:
		body_view.floor_shadow.set_grid(on)


## Paso IU.3: luz de vista previa (no se guarda ni se exporta).
func set_light(turn_degrees: float, energy: float) -> void:
	light_turn = turn_degrees
	light_energy = energy
	body_view.set_light(turn_degrees, energy)


## Paso IU.1c: cambia el tema de toda la ventana y lo recuerda para la próxima vez.
func set_dark(on: bool) -> void:
	dark = on
	SettingsFile.set_dark(on)
	theme = ThemeBuilder.build(on)
	body_view.set_dark(on)  # paso IU.3: el degradado de la vista
	_name_theme_button()


func _name_theme_button() -> void:
	theme_button.icon = ThemeBuilder.icon("claro" if dark else "oscuro")  # dice a qué tema pasa
	theme_button.tooltip_text = "Pasar al tema claro" if dark else "Pasar al tema oscuro"


## Paso A2: autoprueba para builds (`programa -- --autoprueba`): carga, exporta a user:// y sale con 0 o 1.
## Es lo único que se puede lanzar dentro del programa ya exportado (un build no lleva pruebas/).
func _self_test() -> void:
	var problem: String = body_view.error
	if problem == "" and body_view.animation_error != "":
		problem = body_view.animation_error
	if problem == "":
		var path := "user://autoprueba.glb"
		var err: Error = body_view.export_glb(path)
		if err != OK:
			problem = "exportar dio %s" % error_string(err)
		elif not FileAccess.file_exists(path) or not FileAccess.file_exists(path.get_basename() + ".tres"):
			problem = "no se escribieron autoprueba.glb y autoprueba.tres"
		elif not FileAccess.file_exists(LicensesDialog.CREDITS) or not FileAccess.file_exists(LicensesDialog.PROGRAM_LICENSE):
			problem = "faltan las licencias (paso 7.3b)"
	print("AUTOPRUEBA: ", "TODO BIEN" if problem == "" else "FALLO " + problem)
	get_tree().quit(0 if problem == "" else 1)


## Calcula el informe mientras se prueban los huesos (Probar huesos o una animación); si no, lo vacía.
func update_report() -> void:
	if body_view.pose_t or body_view.clip != "":
		report_section.show_results(body_view.check_report())
	else:
		report_section.clear()
	status_bar.set_report(report_panel.rows)
	refresh_measures()


## Paso IU.8: medidas en reposo (si se prueban los huesos o se anima, se queda la última) y presupuesto.
func refresh_measures() -> void:
	if measures != null and not body_view.pose_t and body_view.clip == "":
		status_bar.set_measures(measures.measure(body_view.species.mesh, body_view.species.skeleton))


func _start_measures() -> void:
	var mesh: MeshInstance3D = body_view.species.mesh
	measures = Measures.new(mesh, body_view.species.skeleton)
	# Los huesos que se exportan (los de deformación del manifiesto), no los de ayuda del maniquí.
	status_bar.set_budget(mesh.mesh.surface_get_array_index_len(0) / 3, body_view.species.manifest["bones"]["deform"].size())
	body_view.frame_timer.timeout.connect(refresh_measures)  # como el encuadre: al dejar quietos los deslizadores
	refresh_measures()


func _on_zone_chosen(zone: String) -> void:
	body_actions.set_animation(0)
	body_actions.set_pose_t(false)
	slider_panel.open(zone)


func _unhandled_key_input(event: InputEvent) -> void:
	if editor == null or workshop_page.visible:
		return
	if event.is_action_pressed("ui_redo"):
		editor.redo()
	elif event.is_action_pressed("ui_undo"):
		editor.undo()


## Paso IU.6c: zonas | vista + informe | panel derecho (las páginas de las pestañas).
func _body() -> Control:
	var page := HBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone_picker = ZonePicker.new()
	zone_picker.name = "Zonas"
	page.add_child(zone_picker)
	fold_button = Button.new()
	fold_button.theme_type_variation = "BotonFantasma"
	fold_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fold_button.pressed.connect(func() -> void: set_zones_visible(not zone_picker.visible))
	page.add_child(fold_button)
	_name_fold_button()
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(left)
	body_view = BodyView.new()
	body_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(body_view)
	report_section = ReportSection.new()
	report_section.name = "InformeDeformacion"
	report_panel = report_section.panel
	left.add_child(report_section)
	tabs = TabContainer.new()
	tabs.tabs_visible = false  # paso IU.4: las pestañas están en la barra de arriba
	tabs.custom_minimum_size.x = Tokens.PANEL_DERECHO
	page.add_child(tabs)
	slider_panel = SliderPanel.new()
	finish_panel = FinishPanel.new()
	for tab_name: String in TAB_NAMES:
		var panel: Control = slider_panel if tab_name == "Cuerpo" else (finish_panel if tab_name == "Estilo"
			else _soon_page(SOON[tab_name]))
		panel.name = tab_name  # el nombre de la página es el de la pestaña
		tabs.add_child(panel)
	return page
