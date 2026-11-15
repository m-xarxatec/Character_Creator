extends ScrollContainer
# Paso 4.3: panel de deslizadores de la pestaña Cuerpo, montado solo desde deslizadores.csv (vale para cualquier especie).
# Una cabecera por zona, en el orden de la tabla; al elegir una zona se despliegan sus deslizadores y se pliega la anterior.
# Cada fila: nombre, barra de 0 a 1 y etiqueta de tipo. Por crear se ve desactivado (Fase 6).
# Dos lados: dos filas, (izq.) = _l y (der.) = _r; la simetría que las une es el paso 4.4.
# Uso: panel.setup(species.sliders, values); panel.value_changed.connect(body_view.set_value)

signal value_changed(key: String, value: float)

const HIDDEN_ZONES := ["Cara"]  # sin deslizadores visibles en el MVP (paso 3.14)
const SIDES := {"_l": " (izq.)", "_r": " (der.)"}
const TO_CREATE := "Por crear"
const TYPE_COLORS := {  # fondo y texto de la etiqueta, del tema oscuro de la maqueta
	"Forma": [Color("3c3489"), Color("cecbf6")],
	"Proporción": [Color("3a3936"), Color("c2c0b6")],
	"Por crear": [Color("633806"), Color("fac775")],
}
const NAME_WIDTH := 130.0
const BADGE_WIDTH := 90.0

var zones: Array[String] = []
var zone_buttons := {}  # zona → Button
var zone_boxes := {}  # zona → VBoxContainer con sus filas
var sliders := {}  # clave del valor (o id, en Por crear) → HSlider
var badges := {}  # la misma clave → Label con el tipo
var open_zone := ""


func setup(rows: Array, values: Dictionary) -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)
	for row: Dictionary in rows:
		if row["zona"] in HIDDEN_ZONES:
			continue
		if not zone_boxes.has(row["zona"]):
			_add_zone(list, row["zona"])
		for side: String in (SIDES.keys() if row["lados"] == "2" else [""]):
			_add_row(zone_boxes[row["zona"]], row, side, values)
	if not zones.is_empty():
		open(zones[0])


## Despliega una zona y pliega las demás.
func open(zone: String) -> void:
	open_zone = zone
	for other: String in zones:
		zone_boxes[other].visible = other == zone
		zone_buttons[other].text = ("▾ " if other == zone else "▸ ") + other


func _add_zone(list: VBoxContainer, zone: String) -> void:
	zones.append(zone)
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(open.bind(zone))
	list.add_child(button)
	var box := VBoxContainer.new()
	list.add_child(box)
	zone_buttons[zone] = button
	zone_boxes[zone] = box


func _add_row(box: VBoxContainer, row: Dictionary, side: String, values: Dictionary) -> void:
	var key: String = row["id"] + side
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = row["nombre"] + SIDES.get(side, "")
	label.custom_minimum_size.x = NAME_WIDTH
	line.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if row["tipo"] == TO_CREATE or not values.has(key):
		slider.value = 0.5
		slider.editable = false
	else:
		slider.value = values[key]
		slider.value_changed.connect(func(value: float) -> void: value_changed.emit(key, value))
	line.add_child(slider)
	line.add_child(_badge(row["tipo"], key))
	box.add_child(line)
	sliders[key] = slider


func _badge(type: String, key: String) -> PanelContainer:
	var colors: Array = TYPE_COLORS.get(type, TYPE_COLORS["Proporción"])
	var style := StyleBoxFlat.new()
	style.bg_color = colors[0]
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", style)
	badge.custom_minimum_size.x = BADGE_WIDTH
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = type
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colors[1])
	label.add_theme_font_size_override("font_size", 12)
	badge.add_child(label)
	badges[key] = label
	return badge
