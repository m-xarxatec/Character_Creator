extends ScrollContainer
# Pasos 4.3 y 4.4: panel de deslizadores de la pestaña Cuerpo, montado solo desde deslizadores.csv (vale para cualquier especie).
# Arriba: casilla Simetría y botones Deshacer y Rehacer. Debajo, una cabecera por zona en el orden de la tabla; al elegir
# una zona se despliegan sus deslizadores y su botón Restablecer zona, y se pliega la anterior.
# Cada fila: nombre, barra de 0 a 1 y etiqueta de tipo. Por crear se ve desactivado (Fase 6).
# Dos lados: dos filas, (izq.) = _l y (der.) = _r; con la simetría, mover una mueve las dos.
# Todo cambio pasa por el editor (body_editor.gd); un arrastre, de pulsar a soltar, es un solo cambio para Deshacer.
# La rueda del ratón baja el panel y no mueve las barras (si no, se cambian valores sin querer).
# Uso: panel.setup(editor)

const SymmetryDialog := preload("symmetry_dialog.gd")
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

var editor  # BodyEditor
var zones: Array[String] = []
var zone_buttons := {}  # zona → Button
var zone_boxes := {}  # zona → VBoxContainer con sus filas y su botón Restablecer zona
var reset_buttons := {}  # zona → Button
var sliders := {}  # clave del valor (o id, en Por crear) → HSlider
var badges := {}  # la misma clave → Label con el tipo
var open_zone := ""
var symmetry_box: CheckBox
var undo_button: Button
var redo_button: Button
var symmetry_dialog: AcceptDialog


func setup(body_editor) -> void:
	editor = body_editor
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)
	list.add_child(_top_bar())
	for row: Dictionary in editor.rows:
		if row["zona"] in HIDDEN_ZONES:
			continue
		if not zone_boxes.has(row["zona"]):
			_add_zone(list, row["zona"])
		for side: String in (SIDES.keys() if row["lados"] == "2" else [""]):
			_add_row(zone_boxes[row["zona"]], row, side)
	for zone: String in zones:
		zone_boxes[zone].add_child(reset_buttons[zone])
	symmetry_dialog = SymmetryDialog.new()
	symmetry_dialog.chosen.connect(_on_symmetry_chosen)
	add_child(symmetry_dialog)
	editor.changed.connect(refresh)
	if not zones.is_empty():
		open(zones[0])
	refresh()


## Despliega una zona y pliega las demás.
func open(zone: String) -> void:
	open_zone = zone
	for other: String in zones:
		zone_boxes[other].visible = other == zone
		zone_buttons[other].text = ("▾ " if other == zone else "▸ ") + other


## Pone cada barra en el valor del editor (sin volver a avisar al editor) y activa o no Deshacer y Rehacer.
func refresh() -> void:
	for key: String in sliders:
		if editor.values.has(key):
			sliders[key].set_value_no_signal(editor.values[key])
	undo_button.disabled = not editor.can_undo()
	redo_button.disabled = not editor.can_redo()


func _top_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	symmetry_box = CheckBox.new()
	symmetry_box.text = "Simetría"
	symmetry_box.button_pressed = editor.symmetry
	symmetry_box.toggled.connect(_on_symmetry_toggled)
	bar.add_child(symmetry_box)
	undo_button = _bar_button(bar, "Deshacer", editor.undo)
	redo_button = _bar_button(bar, "Rehacer", editor.redo)
	return bar


func _bar_button(bar: HBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void: action.call())
	bar.add_child(button)
	return button


func _on_symmetry_toggled(on: bool) -> void:
	var differences: Array[Dictionary] = editor.differing_sides()
	if on and not differences.is_empty():
		symmetry_dialog.ask(differences)
	else:
		editor.symmetry = on


func _on_symmetry_chosen(side: String) -> void:
	editor.symmetry = true
	if side:
		editor.match_side(side)


func _add_zone(list: VBoxContainer, zone: String) -> void:
	zones.append(zone)
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(open.bind(zone))
	list.add_child(button)
	var box := VBoxContainer.new()
	list.add_child(box)
	var reset := Button.new()
	reset.text = "Restablecer zona"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.pressed.connect(func() -> void: editor.reset_zone(zone))
	zone_buttons[zone] = button
	zone_boxes[zone] = box
	reset_buttons[zone] = reset


func _add_row(box: VBoxContainer, row: Dictionary, side: String) -> void:
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
	slider.scrollable = false
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if row["tipo"] == TO_CREATE or not editor.values.has(key):
		slider.value = 0.5
		slider.editable = false
	else:
		slider.value_changed.connect(func(value: float) -> void: editor.set_value(key, value))
		slider.gui_input.connect(_on_slider_input)  # llega antes de que la barra cambie de valor
		slider.drag_ended.connect(func(_changed: bool) -> void: _end_change())
	line.add_child(slider)
	line.add_child(_badge(row["tipo"], key))
	box.add_child(line)
	sliders[key] = slider


func _on_slider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			editor.begin_change()
		else:
			_end_change()


func _end_change() -> void:
	editor.end_change()
	refresh()


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
