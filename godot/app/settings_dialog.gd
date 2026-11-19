extends AcceptDialog
# Paso IU.9: ventana «Ajustes» con el tema, el tamaño de la interfaz y «Reducir animaciones». Solo avisa con señales:
# main.gd los aplica al momento y los guarda (settings_file.gd). La abre el botón «Ajustes» de la barra de abajo.
# Paso IU.7a: «Elegir zona tocando el cuerpo» (apagado por defecto) con su descripción breve al encenderlo.
# Paso IU.3: «Vista 3D»: rejilla (se guarda) y luz de vista previa (giro e intensidad; no se guarda: refresh_view).
# Uso: var dialog := SettingsDialog.new(); add_child(dialog); dialog.refresh(dark, scale, reduce); dialog.popup_centered()

signal dark_chosen(dark: bool)
signal scale_chosen(scale: float)
signal reduce_motion_chosen(on: bool)
signal grid_chosen(on: bool)
signal touch_zones_chosen(on: bool)
signal light_chosen(turn_degrees: float, energy: float)

const SettingsFile := preload("settings_file.gd")
## Paso IU.7a: descripción breve que sale al encender la casilla (también va al manual).
const TOUCH_HELP := "Haz clic en el cuerpo para abrir su zona. Al pasar el ratón, la zona se ilumina."
## Aviso a más del 100 %: la vista 3D se dibuja a tamaño lógico (se amplía) y los paneles no se estrechan (medido en IU.9).
const SCALE_WARNING := "A más del 100 %, el personaje se ve menos nítido y, si la ventana es pequeña,\nel panel de la derecha puede quedar cortado."

var theme_option: OptionButton
var scale_option: OptionButton
var reduce_box: CheckBox
var scale_warning: Label
var grid_box: CheckBox
var touch_box: CheckBox
var touch_help: Label
var light_turn: HSlider
var light_energy: HSlider


func _init() -> void:
	title = "Ajustes"
	ok_button_text = "Cerrar"
	var grid := GridContainer.new()
	grid.columns = 2
	theme_option = OptionButton.new()
	theme_option.add_item("Oscuro")
	theme_option.add_item("Claro")
	theme_option.tooltip_text = "Colores de la ventana. El botón del sol o la luna hace lo mismo"
	theme_option.item_selected.connect(func(index: int) -> void: dark_chosen.emit(index == 0))
	_add_row(grid, "Tema", theme_option)
	scale_option = OptionButton.new()
	for scale: float in SettingsFile.SCALES:
		scale_option.add_item("%d %%" % roundi(scale * 100.0))
	scale_option.tooltip_text = "Tamaño de letras, botones y paneles"
	scale_option.item_selected.connect(_on_scale_selected)
	_add_row(grid, "Tamaño de la interfaz", scale_option)
	scale_warning = Label.new()
	scale_warning.text = SCALE_WARNING
	scale_warning.theme_type_variation = "Pista"
	reduce_box = CheckBox.new()
	reduce_box.text = "Reducir animaciones"
	reduce_box.tooltip_text = "La cámara salta al sitio nuevo en vez de moverse suave"
	reduce_box.toggled.connect(func(on: bool) -> void: reduce_motion_chosen.emit(on))
	_add_row(grid, "Movimiento", reduce_box)
	_add_view_rows(grid)
	var column := VBoxContainer.new()
	column.add_child(grid)
	column.add_child(scale_warning)
	column.add_child(touch_help)
	add_child(column)


## Pone los controles como están ahora, sin emitir señales (el sol/luna puede haber cambiado el tema).
func refresh(dark: bool, scale: float, reduce: bool) -> void:
	theme_option.select(0 if dark else 1)
	scale_option.select(SettingsFile.SCALES.find(SettingsFile.nearest_scale(scale)))
	reduce_box.set_pressed_no_signal(reduce)
	scale_warning.visible = scale > 1.0


## Paso IU.3: pone la rejilla y la luz como están ahora, sin emitir señales.
func refresh_view(grid_on: bool, turn_degrees: float, energy: float, touch: bool) -> void:
	touch_box.set_pressed_no_signal(touch)
	touch_help.visible = touch
	grid_box.set_pressed_no_signal(grid_on)
	light_turn.set_value_no_signal(turn_degrees)
	light_energy.set_value_no_signal(energy)


func _add_view_rows(grid: GridContainer) -> void:
	grid_box = CheckBox.new()
	grid_box.text = "Rejilla en el suelo"
	grid_box.tooltip_text = "Líneas cada 50 cm para ver el tamaño y la postura"
	grid_box.toggled.connect(func(on: bool) -> void: grid_chosen.emit(on))
	_add_row(grid, "Vista 3D", grid_box)
	light_turn = _light_slider(-180.0, 180.0, 15.0, 0.0, "Gira la luz alrededor del personaje. Solo para mirar: no se guarda ni se exporta")
	_add_row(grid, "Giro de la luz", light_turn)
	light_energy = _light_slider(0.5, 2.0, 0.1, 1.0, "Más o menos luz. Solo para mirar: no se guarda ni se exporta")
	_add_row(grid, "Intensidad de la luz", light_energy)
	touch_box = CheckBox.new()
	touch_box.text = "Elegir zona tocando el cuerpo"
	touch_box.tooltip_text = "Apagado, las zonas se eligen solo en la silueta y en la lista"
	touch_box.toggled.connect(_on_touch_toggled)
	_add_row(grid, "Zonas", touch_box)
	touch_help = Label.new()
	touch_help.text = TOUCH_HELP
	touch_help.theme_type_variation = "Pista"
	touch_help.visible = false


func _on_touch_toggled(on: bool) -> void:
	touch_help.visible = on
	touch_zones_chosen.emit(on)


func _light_slider(low: float, high: float, step: float, value: float, help: String) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 160
	slider.tooltip_text = help
	slider.value_changed.connect(func(_value: float) -> void: light_chosen.emit(light_turn.value, light_energy.value))
	return slider


func _on_scale_selected(index: int) -> void:
	var scale: float = SettingsFile.SCALES[index]
	scale_warning.visible = scale > 1.0
	scale_chosen.emit(scale)


func _add_row(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	grid.add_child(control)
