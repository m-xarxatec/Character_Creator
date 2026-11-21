extends ScrollContainer
# TA.3c: controles de la espada: siete medidas (barra y número con su unidad), tres colores y Restablecer.
# No genera nada: avisa de cada cambio y la página actualiza la receta. Los límites salen de AssetRecipe.
# Uso: panel.edited.connect(...); panel.reset_requested.connect(...); panel.show_recipe(receta)

signal edited(group: String, key: String, value: Variant)
signal reset_requested

const Recipe := preload("../../addons/creador/taller_assets/asset_recipe.gd")
const ThemeBuilder := preload("../tema/theme_builder.gd")
const Tokens := preload("../tema/tokens.gd")
const FIELDS := {
	"Hoja": {"longitud_m": ["Largo", "Longitud de la hoja"], "ancho_hoja_m": ["Ancho", "Anchura de la hoja"],
		"grosor_m": ["Grosor", "Grosor de la hoja"]},
	"Proporciones": {"escala_punta": ["Punta", "Cuánto de la hoja ocupa la punta"],
		"escala_guarda": ["Guarda", "Anchura de la guarda"], "escala_mango": ["Mango", "Grosor del mango"],
		"escala_pomo": ["Pomo", "Tamaño del pomo"]},
}
const COLORS := {"hoja": "Hoja", "guarda": "Guarda y pomo", "mango": "Mango"}
const MILLIMETERS := 1000.0  # la barra cuenta enteros: así la receta recibe valores exactos
const PERCENT := 100.0
const NAME_WIDTH := 64.0
const NUMBER_WIDTH := 68.0
const UNIT_WIDTH := 16.0

var sliders := {}  # clave de la receta → HSlider
var numbers := {}  # clave de la receta → LineEdit
var color_buttons := {}  # región → ColorPickerButton
var reset_button := Button.new()
var _loading := false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)
	for section: String in FIELDS:
		_heading(list, section)
		for key: String in FIELDS[section]:
			_add_field(list, key, FIELDS[section][key])
	_heading(list, "Colores")
	_add_colors(list)
	reset_button.text = "Restablecer"
	reset_button.icon = ThemeBuilder.icon("restablecer")
	reset_button.tooltip_text = "Volver a las medidas y los colores iniciales"
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	list.add_child(reset_button)


## Pone todos los controles como la receta, en bloque y sin avisar.
func show_recipe(recipe: Dictionary) -> void:
	_loading = true
	for key: String in sliders:
		sliders[key].value = round(recipe.parametros.get(key, 1.0) * _factor(key))
		numbers[key].text = _text(key, sliders[key].value)
	for region: String in color_buttons:
		color_buttons[region].color = Color.html(recipe.colores[region])
	_loading = false


func _heading(list: VBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = "Pista"
	list.add_child(label)


func _add_field(list: VBoxContainer, key: String, texts: Array) -> void:
	var line := HBoxContainer.new()
	list.add_child(line)
	var label := Label.new()
	label.text = texts[0]
	label.custom_minimum_size.x = NAME_WIDTH
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(label)
	var slider := _slider(key)
	line.add_child(slider)
	var number := _number(key)
	line.add_child(number)
	var unit := Label.new()
	unit.text = "m" if _is_length(key) else "%"
	unit.custom_minimum_size.x = UNIT_WIDTH
	line.add_child(unit)
	for control: Control in [label, slider, number]:
		control.tooltip_text = texts[1]
	sliders[key] = slider
	numbers[key] = number


func _slider(key: String) -> HSlider:
	var limits: Array = Recipe.SWORD_LIMITS.get(key, [Recipe.MIN_SCALE, Recipe.MAX_SCALE])
	var slider := HSlider.new()
	slider.max_value = round(limits[1] * _factor(key))  # antes que el mínimo: el máximo inicial es 100
	slider.min_value = round(limits[0] * _factor(key))
	slider.step = 1.0
	slider.scrollable = false  # la rueda baja el panel y no cambia valores sin querer
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider.bind(key))
	return slider


func _number(key: String) -> LineEdit:
	var number := LineEdit.new()
	number.custom_minimum_size.x = NUMBER_WIDTH
	number.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.text_submitted.connect(func(_text: String) -> void:
		_commit_number(key)
		number.release_focus())
	number.focus_exited.connect(_commit_number.bind(key))
	return number


func _add_colors(list: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	list.add_child(row)
	for region: String in COLORS:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var label := Label.new()
		label.text = COLORS[region]
		column.add_child(label)
		var button := ColorPickerButton.new()
		button.edit_alpha = false
		button.custom_minimum_size.y = Tokens.ALTO_MINIMO
		button.tooltip_text = "Color: " + COLORS[region].to_lower()
		button.color_changed.connect(func(color: Color) -> void:
			edited.emit("colores", region, "#" + color.to_html(false).to_upper()))
		column.add_child(button)
		color_buttons[region] = button


func _on_slider(shown: float, key: String) -> void:
	numbers[key].text = _text(key, shown)
	if not _loading:
		edited.emit("parametros", key, shown / _factor(key))


## Número escrito → valor (admite coma o punto; la barra lo recorta a sus límites). Lo que no es un número se ignora.
func _commit_number(key: String) -> void:
	var text: String = numbers[key].text.strip_edges().replace(",", ".")
	if text.is_valid_float():
		sliders[key].value = round(text.to_float() * _factor(key))
	numbers[key].text = _text(key, sliders[key].value)


func _text(key: String, shown: float) -> String:
	if _is_length(key):
		return ("%.3f" % (shown / MILLIMETERS)).replace(".", ",")
	return str(roundi(shown))


func _factor(key: String) -> float:
	return MILLIMETERS if _is_length(key) else PERCENT


func _is_length(key: String) -> bool:
	return key.ends_with("_m")
