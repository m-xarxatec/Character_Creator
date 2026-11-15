extends Control
# Paso 4.1: ventana del editor con las pestañas de diseno/maqueta-pestana-cuerpo.html; solo Cuerpo está activa.
# Abrir: (ulimit -v 4000000; timeout 120 godot --path godot)
# Las pestañas se crean aquí (no en main.tscn) para que la prueba pueda cargar este script desde otro proyecto.
# Cuerpo: la vista 3D (body_view.gd) a la izquierda y el panel de deslizadores (slider_panel.gd) a la derecha.

const BodyView := preload("body_view.gd")
const SliderPanel := preload("slider_panel.gd")
const TAB_NAMES := ["Cuerpo", "Cara y ojos", "Pelo", "Ropa", "Accesorios", "Exportar"]
const ACTIVE_TAB := 0

var tabs: TabContainer
var body_view: SubViewportContainer
var slider_panel: ScrollContainer


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
		slider_panel.setup(body_view.species.sliders, body_view.values)
		slider_panel.value_changed.connect(body_view.set_value)


func _body_page() -> Control:
	var page := HBoxContainer.new()
	body_view = BodyView.new()
	body_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_view.size_flags_stretch_ratio = 2.0
	page.add_child(body_view)
	slider_panel = SliderPanel.new()
	slider_panel.name = "Deslizadores"
	slider_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(slider_panel)
	return page
