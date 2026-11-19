extends AcceptDialog
# Paso IU.9: ventana «Ajustes» con el tema, el tamaño de la interfaz y «Reducir animaciones». Solo avisa con señales:
# main.gd los aplica al momento y los guarda (settings_file.gd). La abre el botón «Ajustes» de la barra de abajo.
# Uso: var dialog := SettingsDialog.new(); add_child(dialog); dialog.refresh(dark, scale, reduce); dialog.popup_centered()

signal dark_chosen(dark: bool)
signal scale_chosen(scale: float)
signal reduce_motion_chosen(on: bool)

const SettingsFile := preload("settings_file.gd")
## Aviso a más del 100 %: la vista 3D se dibuja a tamaño lógico (se amplía) y los paneles no se estrechan (medido en IU.9).
const SCALE_WARNING := "A más del 100 %, el personaje se ve menos nítido y, si la ventana es pequeña,\nel panel de la derecha puede quedar cortado."

var theme_option: OptionButton
var scale_option: OptionButton
var reduce_box: CheckBox
var scale_warning: Label


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
	var column := VBoxContainer.new()
	column.add_child(grid)
	column.add_child(scale_warning)
	add_child(column)


## Pone los controles como están ahora, sin emitir señales (el sol/luna puede haber cambiado el tema).
func refresh(dark: bool, scale: float, reduce: bool) -> void:
	theme_option.select(0 if dark else 1)
	scale_option.select(SettingsFile.SCALES.find(SettingsFile.nearest_scale(scale)))
	reduce_box.set_pressed_no_signal(reduce)
	scale_warning.visible = scale > 1.0


func _on_scale_selected(index: int) -> void:
	var scale: float = SettingsFile.SCALES[index]
	scale_warning.visible = scale > 1.0
	scale_chosen.emit(scale)


func _add_row(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	grid.add_child(control)
