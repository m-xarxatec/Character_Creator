extends ScrollContainer
# Pasos 4.3, 4.4 e IU.6b: panel de ajustes de la pestaña Cuerpo, montado solo desde deslizadores.csv (vale para
# cualquier especie). Enseña una zona (la eligen la silueta de zone_picker.gd o el informe): su nombre y número de
# ajustes, sus filas (slider_row.gd) y Restablecer zona. Arriba, «Buscar ajuste…» (nombre y ayuda, en todas las zonas)
# y Simetría. Deshacer y Rehacer están en la barra de arriba (IU.4).
# Dos lados: con Simetría, una fila (la _l, con « ⇆») mueve las dos; sin ella, dos filas (izq.) y (der.).
# Todo cambio pasa por el editor (body_editor.gd). La rueda del ratón baja el panel y no mueve las barras.
# Uso: panel.setup(editor); panel.open("Cabeza")

## Paso IU.5b: avisa al abrir una zona (la silueta de zone_picker.gd la marca).
signal zone_opened(zone: String)

const SymmetryDialog := preload("symmetry_dialog.gd")
const SliderRow := preload("slider_row.gd")
const ThemeBuilder := preload("tema/theme_builder.gd")
const Tokens := preload("tema/tokens.gd")
const HIDDEN_ZONES := ["Cara", "Base"]  # sin deslizadores visibles en el MVP (pasos 3.14 y 6.2)
const SIDES := {"_l": " (izq.)", "_r": " (der.)"}
const ACCENTS := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u"}

var editor  # BodyEditor
var zones: Array[String] = []
var zone_boxes := {}  # zona → VBoxContainer con su título de búsqueda, sus filas y Restablecer zona
var zone_titles := {}  # zona → Label (solo se ve al buscar)
var reset_buttons := {}  # zona → Button
var rows := {}  # clave del valor → SliderRow
var sliders := {}  # clave del valor → HSlider (el de su fila)
var badges := {}  # la misma clave → Label con el tipo
var counts := {}  # zona → número de ajustes (filas de la tabla)
var help := {}  # id → {ayuda, extremo_izq, extremo_der}
var open_zone := ""
var title: Label
var count_label: Label
var search: LineEdit
var symmetry_box: CheckBox
var symmetry_dialog: AcceptDialog


func setup(body_editor) -> void:
	editor = body_editor
	help = SliderRow.load_help()
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)
	_add_header(list)
	for row: Dictionary in editor.rows:
		if row["zona"] in HIDDEN_ZONES:
			continue
		if not zone_boxes.has(row["zona"]):
			_add_zone(list, row["zona"])
		counts[row["zona"]] = counts.get(row["zona"], 0) + 1
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


## Enseña una zona (y deja de buscar).
func open(zone: String) -> void:
	open_zone = zone
	if search.text != "":
		search.text = ""
	_show_rows()
	zone_opened.emit(zone)


## Pone cada fila como el editor (valores, ↺ y simetría).
func refresh() -> void:
	for row: Control in rows.values():
		row.refresh()
	_show_rows()


## Filtra las filas de todas las zonas por nombre y ayuda (sin mayúsculas ni tildes). "" vuelve a la zona abierta.
func filter(text: String) -> void:
	if search.text != text:
		search.text = text
	_show_rows()


## Claves de las filas que se ven ahora (para las pruebas).
func visible_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: String in rows:
		if rows[key].visible and zone_boxes[rows[key].row["zona"]].visible:
			keys.append(key)
	return keys


func _show_rows() -> void:
	var query := _plain(search.text.strip_edges())
	var found := 0
	for zone: String in zones:
		var any := false
		for key: String in rows:
			var row: Control = rows[key]
			if row.row["zona"] != zone:
				continue
			row.set_symmetric(editor.symmetry)
			var shown: bool = (row.side != "_r" or not editor.symmetry) and (query == "" or _matches(row, query))
			row.visible = shown
			if shown:
				any = true
				found += int(row.side != "_r")
		zone_boxes[zone].visible = any if query != "" else zone == open_zone
		zone_titles[zone].visible = query != ""
		reset_buttons[zone].visible = query == ""
	title.text = open_zone if query == "" else "Resultados"
	var total: int = counts.get(open_zone, 0) if query == "" else found
	count_label.text = "%d %s" % [total, "ajuste" if total == 1 else "ajustes"]


func _matches(row: Control, query: String) -> bool:
	var text: String = row.row["nombre"] + " " + help.get(row.row["id"], {}).get("ayuda", "")
	return _plain(text).contains(query)


func _plain(text: String) -> String:
	var plain := text.to_lower()
	for accent: String in ACCENTS:
		plain = plain.replace(accent, ACCENTS[accent])
	return plain


func _add_header(list: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	title = Label.new()
	title.theme_type_variation = "TituloZona"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	count_label = Label.new()
	count_label.theme_type_variation = "Pista"
	top.add_child(count_label)
	list.add_child(top)
	search = LineEdit.new()
	search.placeholder_text = "Buscar ajuste…"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text: String) -> void: _show_rows())
	list.add_child(search)
	_tint_search()
	symmetry_box = CheckBox.new()
	symmetry_box.text = "Simetría"
	symmetry_box.tooltip_text = "Mover un lado mueve también el otro"
	symmetry_box.button_pressed = editor.symmetry
	symmetry_box.toggled.connect(_on_symmetry_toggled)
	list.add_child(symmetry_box)


func _on_symmetry_toggled(on: bool) -> void:
	var differences: Array[Dictionary] = editor.differing_sides()
	if on and not differences.is_empty():
		symmetry_dialog.ask(differences)
	else:
		editor.symmetry = on
		_show_rows()


func _on_symmetry_chosen(side: String) -> void:
	editor.symmetry = true
	if side:
		editor.match_side(side)
	_show_rows()


func _add_zone(list: VBoxContainer, zone: String) -> void:
	zones.append(zone)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Tokens.ESPACIO[2])
	list.add_child(box)
	var zone_title := Label.new()
	zone_title.text = zone
	zone_title.theme_type_variation = "Pista"
	box.add_child(zone_title)
	var reset := Button.new()
	reset.text = "Restablecer zona"
	reset.icon = ThemeBuilder.icon("restablecer")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.pressed.connect(func() -> void: editor.reset_zone(zone))
	zone_boxes[zone] = box
	zone_titles[zone] = zone_title
	reset_buttons[zone] = reset


func _add_row(box: VBoxContainer, row: Dictionary, side: String) -> void:
	var line = SliderRow.new()
	line.setup(editor, row, side, help.get(row["id"], {}))
	box.add_child(line)
	rows[line.key] = line
	sliders[line.key] = line.slider
	badges[line.key] = line.badge


## Paso IU.12: la lupa, teñida por el tema (Godot no tiñe el right_icon); se cambia con el tema claro u oscuro.
func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_tint_search()


func _tint_search() -> void:
	if search != null and has_theme_icon("buscar", "LineEdit"):  # de este nodo: el aviso llega antes que a search
		search.right_icon = get_theme_icon("buscar", "LineEdit")
