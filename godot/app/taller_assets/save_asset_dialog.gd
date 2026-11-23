extends ConfirmationDialog
# TA.5b: pide nombre, autor y licencia antes de guardar una pieza. Una imagen importada exige confirmar los derechos.
# No guarda nada: avisa con save_requested y sigue abierto hasta que la página lo cierre o le pase un error.
# Uso: dialog.save_requested.connect(...); dialog.open_for({"nombre", "autor", "licencia", "reabierta", "pide_derechos"})

signal save_requested(piece_name: String, author: String, license: String, as_new: bool)

const AssetStore := preload("../../addons/creador/taller_assets/asset_store.gd")
const LICENSES := {"propia": "Propia", "CC0-1.0": "CC0 (dominio público)"}
const WIDTH := 420

var name_edit := LineEdit.new()
var author_edit := LineEdit.new()
var license_menu := OptionButton.new()
var rights_box := CheckBox.new()
var as_new_box := CheckBox.new()
var message := Label.new()


func _init() -> void:
	title = "Guardar en la biblioteca"
	ok_button_text = "Guardar"
	cancel_button_text = "Cancelar"
	dialog_hide_on_ok = false
	var column := VBoxContainer.new()
	add_child(column)
	name_edit.max_length = AssetStore.MAX_NAME
	_add_field(column, "Nombre", name_edit)
	_add_field(column, "Autor", author_edit)
	for key: String in LICENSES:
		license_menu.add_item(LICENSES[key])
		license_menu.set_item_metadata(license_menu.item_count - 1, key)
	_add_field(column, "Licencia", license_menu)
	rights_box.text = "Tengo derecho a usar esta imagen"
	rights_box.tooltip_text = "Una obra de otra persona no pasa a ser tuya ni CC0 por importarla"
	column.add_child(rights_box)
	as_new_box.text = "Guardar como pieza nueva"
	as_new_box.tooltip_text = "Conserva la pieza abierta y crea otra"
	column.add_child(as_new_box)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = WIDTH
	message.hide()
	column.add_child(message)
	name_edit.text_changed.connect(_on_text_changed)
	author_edit.text_changed.connect(_on_text_changed)
	rights_box.toggled.connect(func(_on: bool) -> void: refresh_ok())
	register_text_enter(name_edit)
	register_text_enter(author_edit)
	confirmed.connect(_on_confirmed)


func open_for(piece: Dictionary) -> void:
	name_edit.text = piece.nombre
	author_edit.text = piece.autor
	for i in license_menu.item_count:
		if license_menu.get_item_metadata(i) == piece.licencia:
			license_menu.select(i)
	rights_box.visible = piece.pide_derechos
	rights_box.button_pressed = false
	as_new_box.visible = piece.reabierta
	as_new_box.button_pressed = false
	message.hide()
	refresh_ok()
	popup_centered(Vector2i(WIDTH, 0))
	name_edit.grab_focus()


func show_error(text: String) -> void:
	message.text = text
	message.add_theme_color_override("font_color", get_theme_color("font_color", "NivelAviso"))
	message.show()


func refresh_ok() -> void:
	get_ok_button().disabled = name_edit.text.strip_edges().is_empty() or author_edit.text.strip_edges().is_empty() \
		or (rights_box.visible and not rights_box.button_pressed)


func _add_field(column: VBoxContainer, caption: String, control: Control) -> void:
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = "Pista"
	column.add_child(label)
	column.add_child(control)


func _on_text_changed(_text: String) -> void:
	message.hide()
	refresh_ok()


## Pulsar Intro también llega aquí: con Guardar desactivado no hace nada.
func _on_confirmed() -> void:
	if get_ok_button().disabled:
		return
	message.hide()
	save_requested.emit(name_edit.text.strip_edges(), author_edit.text.strip_edges(),
		license_menu.get_item_metadata(license_menu.selected), as_new_box.visible and as_new_box.button_pressed)
