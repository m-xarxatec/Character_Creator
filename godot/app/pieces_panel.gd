extends ScrollContainer
# Paso AB.13: pestañas Pelo, Ropa y Accesorios (AB.11). Una fila por pieza de ese tipo (packs que siguen al cuerpo): un clic la pone o la
# quita (body_view.set_piece: una por ranura, así que poner una puede quitar otra) y su color. Autor y licencia no se
# enseñan aquí: van solo en el panel de Créditos (D45, paso AB.13b). Aún no entra en Deshacer ni en el proyecto .gmolde
# (bloque «piezas»: siguiente paso).
# Paso 13.1b: las filas de accesorio llevan «Colocar» (solo con la pieza puesta): abre debajo una PlaceRow, una a la vez;
# quitar la pieza la cierra.
# Uso: panel.setup(body_view, "pelo")

const BodyMaterial := preload("../addons/creador/body_material.gd")
const PlaceRow := preload("place_row.gd")

var view: SubViewportContainer  # BodyView
var piece_type := ""
var list := VBoxContainer.new()
var buttons := {}  # "pack/pieza" → Button
var pickers := {}  # "pack/pieza" → ColorPickerButton
var place_buttons := {}  # paso 13.1b: "pack/pieza" → Button «Colocar» (solo accesorios)
var place_row: PlaceRow  # la abierta, o null
var placing := ""  # su "pack/pieza"


func _init() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(list)


func setup(body_view: SubViewportContainer, type: String) -> void:
	view = body_view
	piece_type = type
	if view.library == null:
		return
	for card: Dictionary in view.library.pieces(type, view.SPECIES):
		if card["sigue_al_cuerpo"] or card.has("generador"):  # paso AB.11: también los accesorios rígidos
			_add_row(card)
	if buttons.is_empty():
		var none := Label.new()
		none.text = "Todavía no hay piezas de este tipo."
		none.theme_type_variation = "Pista"
		list.add_child(none)
	view.pieces_changed.connect(refresh)


func _add_row(card: Dictionary) -> void:
	var key: String = card["pack"].path_join(card["id"])
	var row := HBoxContainer.new()
	var button := Button.new()
	button.toggle_mode = true
	button.text = card["nombre"]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.tooltip_text = "Poner o quitar"
	button.toggled.connect(func(on: bool) -> void:
		view.set_piece(card["pack"], card["id"], on)
		_paint(key))
	row.add_child(button)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(36, 0)
	picker.edit_alpha = false
	picker.tooltip_text = "Color de la pieza"
	picker.color_changed.connect(func(_color: Color) -> void:
		picker.set_meta("elegido", true)
		_paint(key))
	row.add_child(picker)
	if piece_type == "accesorio":
		_add_place_button(row, key)
	list.add_child(row)
	buttons[key] = button
	pickers[key] = picker


func _add_place_button(row: HBoxContainer, key: String) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.text = "Colocar"
	button.tooltip_text = "Elegir su hueso y moverla, girarla o escalarla"
	button.disabled = not view.accessories.has(key)
	button.toggled.connect(func(on: bool) -> void:
		_close_place()
		if on:
			_open_place(key))
	row.add_child(button)
	place_buttons[key] = button


func _open_place(key: String) -> void:
	placing = key
	place_buttons[key].set_pressed_no_signal(true)
	place_row = PlaceRow.new()
	list.add_child(place_row)
	list.move_child(place_row, place_buttons[key].get_parent().get_index() + 1)
	place_row.setup(view, key)


func _close_place() -> void:
	if place_row == null:
		return
	place_buttons[placing].set_pressed_no_signal(false)
	place_row.close()
	list.remove_child(place_row)
	place_row.queue_free()
	place_row = null


## Pone el color elegido en la pieza, si está puesta; si aún no se ha elegido, el selector toma el de la pieza.
func _paint(key: String) -> void:
	if not view.is_on(key):
		return
	var picker: ColorPickerButton = pickers[key]
	if not picker.has_meta("elegido"):  # aún sin elegir: el selector enseña el color de partida de la pieza
		picker.color = view.piece_color(key)
		return
	view.set_piece_color(key, picker.color)


## Marca las piezas puestas (otra pestaña o la regla de una por ranura pueden haber cambiado alguna).
func refresh() -> void:
	for key: String in buttons:
		buttons[key].set_pressed_no_signal(view.is_on(key))
		if view.is_on(key):  # p. ej. al abrir un proyecto: el selector enseña su color
			pickers[key].color = view.piece_color(key)
	for key: String in place_buttons:  # paso 13.1b
		place_buttons[key].disabled = not view.accessories.has(key)
	if place_row != null and not view.accessories.has(placing):
		_close_place()
