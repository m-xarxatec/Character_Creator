extends ScrollContainer
# Paso AB.13: pestañas Pelo, Ropa y Accesorios (AB.11), y Cara y ojos (9.4: el color es el del iris). Una fila por pieza de ese tipo (packs que siguen al cuerpo): un clic la pone o la
# quita (body_view.set_piece: una por ranura, así que poner una puede quitar otra), su color y, siempre a la vista, su
# ranura, autor y licencia. Aún no entra en Deshacer ni en el proyecto .gmolde (bloque «piezas»: siguiente paso).
# Uso: panel.setup(body_view, "pelo")

const BodyMaterial := preload("../addons/creador/body_material.gd")

var view: SubViewportContainer  # BodyView
var piece_type := ""
var list := VBoxContainer.new()
var buttons := {}  # "pack/pieza" → Button
var pickers := {}  # "pack/pieza" → ColorPickerButton


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
	button.tooltip_text = "Poner o quitar (una pieza por ranura: %s)" % card["ranura"]
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
	list.add_child(row)
	var credit := Label.new()
	credit.text = "%s · %s · %s" % [card["ranura"], card["autor"], card["licencia"]]
	credit.theme_type_variation = "Pista"
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(credit)
	buttons[key] = button
	pickers[key] = picker


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
