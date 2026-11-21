extends AcceptDialog
# Paso PL.4: ventana «Nuevo personaje». Paso PL.10: Femenino, Masculino, Neutro y Aleatorio en una fila (sin «Más
# cuerpos»); «Recientes» (settings_file.gd: los 8 últimos presets abiertos o guardados que aún existen); «Abrir
# preset…» y «Mostrar al arrancar». Usa las tarjetas de la galería (template_gallery.gd): mismos nombres y miniaturas.
# Paso 10.2: en «Recientes», los proyectos .gmolde llevan su miniatura (project_io.gd).
# Solo avisa con señales; main.gd la abre al arrancar (si el ajuste lo dice) y con el botón «Nuevo…».
# Uso: screen.setup(zone_picker.gallery); screen.template_chosen.connect(editor.load_values); screen.show_screen()

signal template_chosen(values: Dictionary)
signal recent_chosen(path: String)
signal open_requested
signal random_requested  # paso PL.5

const SettingsFile := preload("settings_file.gd")
const ProjectIO := preload("project_io.gd")
const BIG := ["femenino", "masculino", "anime"]
const BIG_THUMB := 112
const RECENT_HEIGHT := 200  # px: «Recientes» se desplaza dentro, para que la ventana quepa en 648 px de alto
const RECENT_ICON := 48  # px de la miniatura de un proyecto en «Recientes» (paso 10.2)

var cards := {}  # id → Button
var random_card: Button  # paso PL.5; la cuarta de la fila (paso PL.10)
var recent_box := VBoxContainer.new()
var show_box := CheckBox.new()


func _init() -> void:
	title = "Nuevo personaje"
	ok_button_text = "Cerrar"


func setup(gallery: ScrollContainer) -> void:
	var column := VBoxContainer.new()
	add_child(column)
	var big := HBoxContainer.new()
	column.add_child(big)
	for id: String in BIG:
		if gallery.cards.has(id):
			big.add_child(_card(gallery, id, BIG_THUMB))
	random_card = gallery.random_button(BIG_THUMB + 36)
	random_card.size_flags_horizontal = Control.SIZE_FILL  # del ancho de las demás
	random_card.custom_minimum_size.x = BIG_THUMB + 16
	random_card.pressed.connect(func() -> void:
		hide()
		random_requested.emit())
	big.add_child(random_card)
	column.add_child(_title("Recientes"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = RECENT_HEIGHT
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recent_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recent_box)
	column.add_child(scroll)
	var open := Button.new()
	open.text = "Abrir…"
	open.pressed.connect(func() -> void:
		hide()
		open_requested.emit())
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()  # en una fila: la ventana cabe en 648 px de alto
	row.add_child(open)
	show_box.text = "Mostrar al arrancar"
	show_box.button_pressed = SettingsFile.get_start_screen()
	show_box.toggled.connect(SettingsFile.set_start_screen)
	row.add_child(show_box)
	column.add_child(row)


func show_screen() -> void:
	refresh_recent()
	popup_centered()


func refresh_recent() -> void:
	for child in recent_box.get_children():
		child.free()
	var recent := SettingsFile.get_recent()
	if recent.is_empty():
		var none := Label.new()
		none.text = "Todavía no hay ninguno."
		none.theme_type_variation = "Pista"
		recent_box.add_child(none)
	for path: String in recent:
		var button := Button.new()
		button.text = path.get_file()
		button.tooltip_text = path
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = "BotonFantasma"
		button.icon = ProjectIO.thumbnail(path)  # paso 10.2: null en los presets
		if button.icon != null:
			button.expand_icon = true
			button.custom_minimum_size.y = RECENT_ICON
		button.pressed.connect(func() -> void:
			hide()
			recent_chosen.emit(path))
		recent_box.add_child(button)


func _card(gallery: ScrollContainer, id: String, thumb: int) -> Button:
	var source: Button = gallery.cards[id]
	var card := Button.new()
	card.text = source.text
	card.icon = source.icon
	card.tooltip_text = source.tooltip_text
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.custom_minimum_size = Vector2(thumb + 16, thumb + 36)
	card.pressed.connect(func() -> void:
		hide()
		template_chosen.emit(gallery.templates[id].duplicate()))
	cards[id] = card
	return card


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "Pista"
	return label
