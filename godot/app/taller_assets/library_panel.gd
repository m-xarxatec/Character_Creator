extends VBoxContainer
# TA.5b: lista de la biblioteca del Taller, con miniatura y nombre. Un clic pide reabrir la pieza.
# No lee ni escribe archivos de piezas: la página le pasa las fichas de AssetStore.list().
# Uso: panel.piece_chosen.connect(...); panel.show_pieces(fichas, avisos, id_seleccionado)

signal piece_chosen(id: String)

const ThemeBuilder := preload("../tema/theme_builder.gd")
const ICON_SIZE := 48

var list := ItemList.new()
var empty_label := Label.new()
var notes := Label.new()
var ids := PackedStringArray()


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Label.new()
	heading.text = "Biblioteca"
	heading.theme_type_variation = "TituloZona"
	add_child(heading)
	empty_label.text = "Aún no hay piezas guardadas."
	empty_label.theme_type_variation = "Pista"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(empty_label)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(ICON_SIZE, ICON_SIZE)
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.item_clicked.connect(_on_clicked)
	list.item_activated.connect(_choose)
	add_child(list)
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.hide()
	add_child(notes)


func show_pieces(cards: Array, warnings: PackedStringArray, selected := "") -> void:
	list.clear()
	ids.clear()
	for card: Dictionary in cards:
		var index := list.add_item(card.nombre, _icon(card.miniatura))
		list.set_item_tooltip(index, card.nombre)
		ids.append(card.id)
	empty_label.visible = cards.is_empty()
	list.visible = not cards.is_empty()
	show_notes(warnings)
	select_piece(selected)


func select_piece(id: String) -> void:
	var index := ids.find(id)
	if index >= 0:
		list.select(index)
	else:
		list.deselect_all()


func show_notes(warnings: PackedStringArray) -> void:
	notes.text = "\n".join(warnings)
	notes.visible = not warnings.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		notes.add_theme_color_override("font_color", get_theme_color("font_color", "NivelAviso"))
		_paint_list()


## El tema de la app no define ItemList: usa los colores de sus etiquetas y botones, en claro y en oscuro.
func _paint_list() -> void:
	for state: String in ["panel", "cursor", "cursor_unfocused"]:
		list.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		list.add_theme_stylebox_override(state, get_theme_stylebox("pressed", "Button"))
	list.add_theme_stylebox_override("hovered", get_theme_stylebox("hover", "Button"))
	for key: String in ["font_color", "font_hovered_color"]:
		list.add_theme_color_override(key, get_theme_color("font_color", "Label"))
	for key: String in ["font_selected_color", "font_hovered_selected_color"]:
		list.add_theme_color_override(key, get_theme_color("font_pressed_color", "Button"))
	list.add_theme_color_override("guide_color", Color.TRANSPARENT)


func _on_clicked(index: int, _position: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_choose(index)


func _choose(index: int) -> void:
	piece_chosen.emit(ids[index])


func _icon(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(path) if path != "" else null
	if image == null or image.is_empty():
		return ThemeBuilder.icon("prenda")
	return ImageTexture.create_from_image(image)
