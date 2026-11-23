extends ScrollContainer
# TA.4c: controles de «Desde imagen»: elegir PNG, miniatura con su contorno, medidas, ajustes del contorno, color y avisos.
# No genera nada: avisa de cada cambio y la página decide. Los límites salen de AssetRecipe e ImageMask.
# Uso: panel.edited.connect(...); panel.choose_requested.connect(...); panel.reset_requested.connect(...)
#      panel.show_values(valores, opciones); panel.show_source(imagen, nombre); panel.show_contour(contorno, tamaño)

signal edited(group: String, key: String, value: Variant)
signal choose_requested
signal reset_requested

const Recipe := preload("../../addons/creador/taller_assets/asset_recipe.gd")
const ImageMask := preload("../../addons/creador/taller_assets/image_mask.gd")
const ThemeBuilder := preload("../tema/theme_builder.gd")
const Tokens := preload("../tema/tokens.gd")
const FIELDS := {
	"Tamaño": {"altura_m": ["Altura", "Altura de la pieza"], "grosor_m": ["Grosor", "Grosor de la pieza"]},
	"Contorno": {"umbral_alfa": ["Umbral", "Hasta qué transparencia un píxel cuenta como fondo"],
		"tolerancia": ["Tolerancia", "Cuánto puede parecerse un color al fondo para contar como fondo"],
		"simplificacion": ["Simplificar", "Cuánto se simplifica el contorno, en píxeles"]},
}
const MILLIMETERS := 1000.0  # la barra cuenta enteros: así la receta recibe valores exactos
const PERCENT := 100.0
const TENTHS := 10.0
const NAME_WIDTH := 84.0
const NUMBER_WIDTH := 60.0
const UNIT_WIDTH := 20.0
const PREVIEW_HEIGHT := 128.0
const THUMB_SIDE := 256

var sliders := {}  # clave → HSlider
var numbers := {}  # clave → LineEdit
var rows := {}  # clave → fila
var choose_button := Button.new()
var file_label := Label.new()
var preview := Preview.new()
var invert_box := CheckBox.new()
var color_button := ColorPickerButton.new()
var notes := Label.new()
var reset_button := Button.new()
var _has_alpha := true
var _loading := false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)
	_add_source(list)
	for section: String in FIELDS:
		_heading(list, section)
		for key: String in FIELDS[section]:
			_add_field(list, key, FIELDS[section][key])
	_add_invert(list)
	_heading(list, "Color")
	_add_color(list)
	notes.theme_type_variation = "Pista"
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.hide()
	list.add_child(notes)
	reset_button.text = "Restablecer"
	reset_button.icon = ThemeBuilder.icon("restablecer")
	reset_button.tooltip_text = "Volver a las medidas, los ajustes y el color iniciales"
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	list.add_child(reset_button)


## Pone todos los controles como los valores dados, en bloque y sin avisar.
func show_values(values: Dictionary, options: Dictionary) -> void:
	_loading = true
	for key: String in sliders:
		var value: float = values.parametros[key] if values.parametros.has(key) else options[key]
		sliders[key].value = round(value * _factor(key))
		numbers[key].text = _text(key, sliders[key].value)
	invert_box.button_pressed = options.invertir
	color_button.color = Color.html(values.colores.principal)
	_loading = false


func show_source(image: Image, file_name: String) -> void:
	_has_alpha = image.detect_alpha() != Image.ALPHA_NONE
	file_label.text = file_name
	preview.show_image(image)


func show_contour(contour: PackedVector2Array, source_size: Vector2i) -> void:
	preview.show_contour(contour, source_size)


## TA.5b: pieza reabierta sin su imagen de origen.
func show_missing_source(file_name: String) -> void:
	file_label.text = file_name + " (no disponible)"
	preview.clear()


## TA.5b: sin imagen no se puede recalcular el contorno; medidas y color siguen activos.
func set_contour_enabled(enabled: bool) -> void:
	for key: String in FIELDS["Contorno"]:
		sliders[key].editable = enabled
		numbers[key].editable = enabled
	invert_box.disabled = not enabled


func show_notes(warnings: PackedStringArray) -> void:
	notes.text = "\n".join(warnings)
	notes.visible = not warnings.is_empty()


## El umbral solo actúa si hay transparencia; la tolerancia, cuando el fondo se toma del color.
func show_background(background: String) -> void:
	rows["umbral_alfa"].visible = _has_alpha
	rows["tolerancia"].visible = not _has_alpha or background != "alfa"


func _add_source(list: VBoxContainer) -> void:
	choose_button.text = "Elegir imagen"
	choose_button.tooltip_text = "Elegir un archivo PNG"
	choose_button.pressed.connect(func() -> void: choose_requested.emit())
	list.add_child(choose_button)
	file_label.theme_type_variation = "Pista"
	file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.add_child(file_label)
	preview.custom_minimum_size.y = PREVIEW_HEIGHT
	list.add_child(preview)


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
	unit.text = "m" if _is_length(key) else ("px" if key == "simplificacion" else "%")
	unit.custom_minimum_size.x = UNIT_WIDTH
	line.add_child(unit)
	for control: Control in [label, slider, number]:
		control.tooltip_text = texts[1]
	sliders[key] = slider
	numbers[key] = number
	rows[key] = line


func _slider(key: String) -> HSlider:
	var limits: Array = Recipe.EXTRUSION_LIMITS[key] if _is_length(key) else ImageMask.RANGES[key]
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


func _add_invert(list: VBoxContainer) -> void:
	invert_box.text = "Invertir"
	invert_box.tooltip_text = "Usar como pieza lo que ahora es fondo"
	invert_box.toggled.connect(func(on: bool) -> void:
		if not _loading:
			edited.emit("contorno", "invertir", on))
	list.add_child(invert_box)


func _add_color(list: VBoxContainer) -> void:
	color_button.edit_alpha = false
	color_button.custom_minimum_size.y = Tokens.ALTO_MINIMO
	color_button.tooltip_text = "Color de la pieza"
	color_button.color_changed.connect(func(color: Color) -> void:
		if not _loading:
			edited.emit("colores", "principal", "#" + color.to_html(false).to_upper()))
	list.add_child(color_button)


func _on_slider(shown: float, key: String) -> void:
	numbers[key].text = _text(key, shown)
	if not _loading:
		edited.emit("parametros" if _is_length(key) else "contorno", key, shown / _factor(key))


## Número escrito → valor (admite coma o punto; la barra lo recorta a sus límites). Lo que no es un número se ignora.
func _commit_number(key: String) -> void:
	var text: String = numbers[key].text.strip_edges().replace(",", ".")
	if text.is_valid_float():
		sliders[key].value = round(text.to_float() * _factor(key))
	numbers[key].text = _text(key, sliders[key].value)


func _text(key: String, shown: float) -> String:
	if _is_length(key):
		return ("%.3f" % (shown / MILLIMETERS)).replace(".", ",")
	if key == "simplificacion":
		return ("%.1f" % (shown / TENTHS)).replace(".", ",")
	return str(roundi(shown))


func _factor(key: String) -> float:
	if _is_length(key):
		return MILLIMETERS
	return TENTHS if key == "simplificacion" else PERCENT


func _is_length(key: String) -> bool:
	return key.ends_with("_m")


## Miniatura de la imagen con el contorno encima.
class Preview extends Control:
	var texture: ImageTexture
	var contour := PackedVector2Array()
	var source_size := Vector2.ONE

	func show_image(image: Image) -> void:
		var thumb: Image = image.duplicate()
		thumb.convert(Image.FORMAT_RGBA8)
		var factor := minf(1.0, float(THUMB_SIDE) / maxi(thumb.get_width(), thumb.get_height()))
		thumb.resize(maxi(roundi(thumb.get_width() * factor), 1), maxi(roundi(thumb.get_height() * factor), 1),
			Image.INTERPOLATE_BILINEAR)
		texture = ImageTexture.create_from_image(thumb)
		contour = PackedVector2Array()
		queue_redraw()

	func clear() -> void:
		texture = null
		contour = PackedVector2Array()
		queue_redraw()

	func show_contour(points: PackedVector2Array, work_size: Vector2i) -> void:
		contour = points
		source_size = Vector2(work_size)
		queue_redraw()

	func _draw() -> void:
		if texture == null:
			return
		var scale_factor := minf(size.x / texture.get_width(), size.y / texture.get_height())
		var shown := Vector2(texture.get_size()) * scale_factor
		var area := Rect2((size - shown) * 0.5, shown)
		draw_texture_rect(texture, area, false)
		if contour.size() < 3:
			return
		var line := PackedVector2Array()
		for point in contour:
			line.append(area.position + point * area.size / source_size)
		line.append(line[0])
		draw_polyline(line, Tokens.OSCURO.acento_linea, 1.5, true)
