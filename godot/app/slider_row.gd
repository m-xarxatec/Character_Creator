extends VBoxContainer
# Paso IU.6a: una fila de deslizador (diseno/GUIA_INTERFAZ.md §4): nombre e insignia; barra con el relleno desde el
# neutro y una marca en él; número 0–100 que se puede escribir; ↺ al neutro (atenuado si ya lo está); ayuda; extremos
# con nombre si la ayuda los trae. Habla directamente con el editor (body_editor.gd): cada acción es un cambio para
# Deshacer; un arrastre entero, uno solo.
# Uso: var help := SliderRow.load_help(); var row := SliderRow.new(); row.setup(editor, fila, "_l", help.get(id, {}))

const ThemeBuilder := preload("tema/theme_builder.gd")
const TYPE_VARIATIONS := {"Forma": "InsigniaForma", "Proporción": "InsigniaProporcion", "Por crear": "InsigniaCrear"}
const SIDES := {"_l": " (izq.)", "_r": " (der.)"}
const TO_CREATE := "Por crear"
const BADGE_WIDTH := 90.0
const NUMBER_WIDTH := 48.0
const TRACK_HEIGHT := 4.0
const MARK_HEIGHT := 12.0

var editor  # BodyEditor
var row: Dictionary  ## fila de deslizadores.csv
var side := ""
var key := ""
var neutral := 0.5
var name_label: Label
var badge: Label
var slider: HSlider
var number: LineEdit
var reset_button: Button
var track: Control  # dibuja la pista, el relleno desde el neutro y su marca, por debajo de la barra


## Ayudas de textos/ayuda_deslizadores.csv: id → {ayuda, extremo_izq, extremo_der}. Vacío si no está el archivo.
static func load_help() -> Dictionary:
	var path := (ThemeBuilder as Script).resource_path.get_base_dir().get_base_dir().path_join("textos/ayuda_deslizadores.csv")
	var help := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return help
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() == header.size() and line[0] != "":
			var entry := {}
			for i in range(1, header.size()):
				entry[header[i]] = line[i]
			help[line[0]] = entry
	return help


## help: {ayuda, extremo_izq, extremo_der} (vacío si la fila no tiene ayuda).
func setup(body_editor, table_row: Dictionary, row_side: String, help: Dictionary) -> void:
	editor = body_editor
	row = table_row
	side = row_side
	key = row["id"] + side
	neutral = float(row["neutro"])
	tooltip_text = help.get("ayuda", "")
	var top := HBoxContainer.new()
	add_child(top)
	name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.gui_input.connect(_on_name_input)
	top.add_child(name_label)
	badge = Label.new()
	badge.text = row["tipo"]
	badge.theme_type_variation = TYPE_VARIATIONS.get(row["tipo"], TYPE_VARIATIONS["Proporción"])
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.custom_minimum_size.x = BADGE_WIDTH
	top.add_child(badge)
	var line := HBoxContainer.new()
	add_child(line)
	_add_slider(line)
	number = LineEdit.new()
	number.custom_minimum_size.x = NUMBER_WIDTH
	number.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.max_length = 3
	number.text_submitted.connect(func(_text: String) -> void: number.release_focus())
	number.focus_exited.connect(_on_number_done)
	line.add_child(number)
	reset_button = Button.new()
	reset_button.icon = ThemeBuilder.icon("restablecer")
	reset_button.theme_type_variation = "BotonFantasma"
	reset_button.tooltip_text = "Volver al valor neutro"
	reset_button.pressed.connect(reset)
	line.add_child(reset_button)
	if help.get("extremo_izq", "") != "" or help.get("extremo_der", "") != "":
		add_child(_ends(help.get("extremo_izq", ""), help.get("extremo_der", "")))
	var locked: bool = row["tipo"] == TO_CREATE or not editor.values.has(key)
	slider.editable = not locked
	number.editable = not locked
	reset_button.disabled = locked
	set_symmetric(editor.symmetry)


## Nombre según la simetría: con ella, la fila de dos lados dice « ⇆»; sin ella, «(izq.)» o «(der.)».
func set_symmetric(on: bool) -> void:
	if side == "":
		name_label.text = row["nombre"]
	else:
		name_label.text = row["nombre"] + (" ⇆" if on else SIDES[side])


## Pone la barra, el número y el ↺ como el valor del editor (sin volver a avisarle).
func refresh() -> void:
	var value: float = editor.values.get(key, neutral)
	slider.set_value_no_signal(value)
	if not number.has_focus():
		number.text = str(roundi(value * 100.0))
	if not slider.editable:
		reset_button.disabled = true
	else:
		reset_button.disabled = is_equal_approx(value, neutral)
	track.queue_redraw()


## ↺: vuelve al neutro (un cambio para Deshacer).
func reset() -> void:
	_change(neutral)


## Píxeles del relleno en la pista: [inicio, fin] (para las pruebas).
func fill_span() -> Vector2:
	var a := _x_of(neutral)
	var b := _x_of(slider.value)
	return Vector2(minf(a, b), maxf(a, b))


## Centro del agarrador para un valor: Godot lo mueve por el ancho menos su propio tamaño.
func _x_of(value: float) -> float:
	var grabber := float(slider.get_theme_icon("grabber").get_width())
	return value * (track.size.x - grabber) + grabber / 2.0


func _add_slider(line: HBoxContainer) -> void:
	slider = HSlider.new()
	slider.theme_type_variation = "BarraNeutro"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.scrollable = false  # la rueda baja el panel y no cambia valores sin querer
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		editor.set_value(key, value)
		number.text = str(roundi(value * 100.0)))
	slider.gui_input.connect(_on_slider_input)  # llega antes de que la barra cambie de valor
	slider.drag_ended.connect(func(_changed: bool) -> void: _end_change())
	track = Control.new()
	track.show_behind_parent = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.draw.connect(_draw_track)
	slider.add_child(track)
	line.add_child(slider)


func _draw_track() -> void:
	var y := track.size.y / 2.0
	var line := get_theme_color("pista", "BarraNeutro")
	var fill := get_theme_color("relleno", "BarraNeutro")
	track.draw_line(Vector2(0, y), Vector2(track.size.x, y), line, TRACK_HEIGHT, true)
	var span := fill_span()
	if span.y - span.x > 0.5:
		track.draw_line(Vector2(span.x, y), Vector2(span.y, y), fill, TRACK_HEIGHT, true)
	var mark := _x_of(neutral)
	track.draw_line(Vector2(mark, y - MARK_HEIGHT / 2.0), Vector2(mark, y + MARK_HEIGHT / 2.0),
		get_theme_color("marca", "BarraNeutro"), 1.0, true)


func _ends(left: String, right: String) -> HBoxContainer:
	var ends := HBoxContainer.new()
	for text: String in [left, right]:
		var label := Label.new()
		label.text = text
		label.theme_type_variation = "Pista"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if text == left else HORIZONTAL_ALIGNMENT_RIGHT
		ends.add_child(label)
	return ends


func _on_slider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			editor.begin_change()
		else:
			_end_change()


func _on_name_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click and slider.editable:
		reset()


## Número escrito → valor (0–100 → 0–1), como un solo cambio. Lo que no es un número se ignora.
func _on_number_done() -> void:
	if not number.text.strip_edges().is_valid_int():
		refresh()
		return
	_change(clampi(number.text.strip_edges().to_int(), 0, 100) / 100.0)


func _change(value: float) -> void:
	editor.begin_change()
	editor.set_value(key, value)
	_end_change()


func _end_change() -> void:
	editor.end_change()
	refresh()
