extends Control
# Paso 4.1: ventana del editor con las pestañas de diseno/maqueta-pestana-cuerpo.html; solo Cuerpo está activa.
# Abrir: (ulimit -v 4000000; timeout 900 godot --path godot)
# Autoprueba (paso A2): (ulimit -v 4000000; timeout 120 godot --headless --path godot -- --autoprueba)
# Las pestañas se crean aquí (no en main.tscn) para que la prueba pueda cargar este script desde otro proyecto.
# Cuerpo: la vista 3D (body_view.gd) a la izquierda y el panel de deslizadores (slider_panel.gd) a la derecha; los dos
# siguen al editor (body_editor.gd). Bajo los deslizadores, el panel Acabado (finish_panel.gd, paso 4.7b). Debajo, la barra de body_actions.gd (paso 4.5; Guardar y Abrir preset, paso 7.0). Ctrl+Z deshace; Ctrl+Mayús+Z o Ctrl+Y rehacen (acciones ui_undo y ui_redo de Godot).
# Paso 5.4: con Probar huesos o una animación, el informe (report_panel.gd) ocupa el sitio de los deslizadores; su botón
# de zona sale de la prueba y abre esa zona.

const BodyView := preload("body_view.gd")
const SliderPanel := preload("slider_panel.gd")
const BodyEditor := preload("body_editor.gd")
const BodyActions := preload("body_actions.gd")
const FinishPanel := preload("finish_panel.gd")
const ReportPanel := preload("report_panel.gd")
const LicensesDialog := preload("licenses_dialog.gd")
const TAB_NAMES := ["Cuerpo", "Cara y ojos", "Pelo", "Ropa", "Accesorios", "Exportar"]
const ACTIVE_TAB := 0

var tabs: TabContainer
var body_view: SubViewportContainer
var slider_panel: ScrollContainer
var body_actions: HBoxContainer
var finish_panel: VBoxContainer
var report_panel: ScrollContainer
var editor  # BodyEditor (null si la especie no cargó)
var licenses: AcceptDialog  # paso 7.3b


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs = TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tabs)
	for tab_name in TAB_NAMES:
		var page: Control = _body_page() if tab_name == "Cuerpo" else Control.new()
		page.name = tab_name
		tabs.add_child(page)
	for i in TAB_NAMES.size():
		tabs.set_tab_disabled(i, i != ACTIVE_TAB)
	tabs.current_tab = ACTIVE_TAB
	if body_view.error == "":  # la vista ya cargó la especie (su _ready va al entrar en el árbol)
		editor = BodyEditor.new(body_view.species.sliders, body_view.values)
		editor.changed.connect(func() -> void: body_view.set_values(editor.values))
		slider_panel.setup(editor)
		body_actions.setup(body_view, editor)
		finish_panel.setup(body_view)
		body_actions.test_changed.connect(update_report)
		body_actions.look_changed.connect(finish_panel.refresh)
		report_panel.zone_chosen.connect(_on_zone_chosen)
	licenses = LicensesDialog.new()
	add_child(licenses)
	var licenses_button := Button.new()
	licenses_button.text = "Licencias"
	licenses_button.pressed.connect(func() -> void: licenses.popup_centered_ratio(0.7))
	body_actions.add_child(licenses_button)
	if "--autoprueba" in OS.get_cmdline_user_args():
		_self_test()


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


## Enseña el informe mientras se prueban los huesos (Probar huesos o una animación); si no, los deslizadores.
func update_report() -> void:
	var testing: bool = body_view.pose_t or body_view.clip != ""
	report_panel.visible = testing
	slider_panel.visible = not testing
	if testing:
		report_panel.show_results(body_view.check_report())


func _on_zone_chosen(zone: String) -> void:
	body_actions.set_animation(0)
	body_actions.set_pose_t(false)
	slider_panel.open(zone)


func _unhandled_key_input(event: InputEvent) -> void:
	if editor == null:
		return
	if event.is_action_pressed("ui_redo"):
		editor.redo()
	elif event.is_action_pressed("ui_undo"):
		editor.undo()


func _body_page() -> Control:
	var column := VBoxContainer.new()
	var page := HBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(page)
	body_view = BodyView.new()
	body_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_view.size_flags_stretch_ratio = 2.0
	page.add_child(body_view)
	slider_panel = SliderPanel.new()
	slider_panel.name = "Deslizadores"
	slider_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	finish_panel = FinishPanel.new()
	finish_panel.name = "Acabado"
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(slider_panel)
	report_panel = ReportPanel.new()
	report_panel.name = "Informe"
	report_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_panel.visible = false
	side.add_child(report_panel)
	side.add_child(HSeparator.new())
	side.add_child(finish_panel)
	page.add_child(side)
	body_actions = BodyActions.new()
	body_actions.name = "Acciones"
	column.add_child(body_actions)
	return column
