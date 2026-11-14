extends Control
# Paso 4.1: ventana del editor con las pestañas de diseno/maqueta-pestana-cuerpo.html; solo Cuerpo está activa.
# Abrir: (ulimit -v 4000000; timeout 120 godot --path godot)
# Las pestañas se crean aquí (no en main.tscn) para que la prueba pueda cargar este script desde otro proyecto.

const TAB_NAMES := ["Cuerpo", "Cara y ojos", "Pelo", "Ropa", "Accesorios", "Exportar"]
const ACTIVE_TAB := 0

var tabs: TabContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs = TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tabs)
	for tab_name in TAB_NAMES:
		var page := Control.new()
		page.name = tab_name
		tabs.add_child(page)
	for i in TAB_NAMES.size():
		tabs.set_tab_disabled(i, i != ACTIVE_TAB)
	tabs.current_tab = ACTIVE_TAB
