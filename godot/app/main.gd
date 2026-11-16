extends Control
# Paso 4.1: ventana del editor con las pestañas de diseno/maqueta-pestana-cuerpo.html; solo Cuerpo está activa.
# Abrir: (ulimit -v 4000000; timeout 900 godot --path godot)
# Las pestañas se crean aquí (no en main.tscn) para que la prueba pueda cargar este script desde otro proyecto.
# Cuerpo: la vista 3D (body_view.gd) a la izquierda y el panel de deslizadores (slider_panel.gd) a la derecha; los dos
# siguen al editor (body_editor.gd). Bajo los deslizadores, el panel Acabado (finish_panel.gd, paso 4.7b). Debajo, la barra de body_actions.gd (paso 4.5). Ctrl+Z deshace; Ctrl+Mayús+Z o Ctrl+Y rehacen (acciones ui_undo y ui_redo de Godot).

const BodyView := preload("body_view.gd")
const SliderPanel := preload("slider_panel.gd")
const BodyEditor := preload("body_editor.gd")
const BodyActions := preload("body_actions.gd")
const FinishPanel := preload("finish_panel.gd")
const TAB_NAMES := ["Cuerpo", "Cara y ojos", "Pelo", "Ropa", "Accesorios", "Exportar"]
const ACTIVE_TAB := 0

var tabs: TabContainer
var body_view: SubViewportContainer
var slider_panel: ScrollContainer
var body_actions: HBoxContainer
var finish_panel: VBoxContainer
var editor  # BodyEditor (null si la especie no cargó)


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
		body_actions.setup(body_view)
		finish_panel.setup(body_view)


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
	side.add_child(HSeparator.new())
	side.add_child(finish_panel)
	page.add_child(side)
	body_actions = BodyActions.new()
	body_actions.name = "Acciones"
	column.add_child(body_actions)
	return column
