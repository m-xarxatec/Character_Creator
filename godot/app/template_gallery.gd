extends ScrollContainer
# Paso PL.3: galería de plantillas (pestaña «Plantillas» del panel izquierdo): una tarjeta por preset de serie con su
# miniatura (paso PL.2) y su nombre. Un clic emite template_chosen con sus valores: solo el cuerpo (colores, prenda y
# acabado no cambian), un solo cambio para Deshacer y sin tocar el archivo abierto (Guardar no pisa la plantilla).
# Uso: gallery.setup(species.folder.path_join("presets"), species.manifest["species"], species.sliders)
#      gallery.template_chosen.connect(editor.load_values)

signal template_chosen(values: Dictionary)
signal random_requested  # paso PL.5: la tarjeta «Aleatorio» (la primera)

const Preset := preload("../addons/creador/preset.gd")
## Orden de la galería (sin campo en el preset); las que no estén aquí van detrás, por orden alfabético.
const ORDER := ["anime", "femenina", "masculino", "atletica", "atletico", "delgada", "delgado", "robusta", "robusto",
	"esbelta", "esbelto"]
const COLUMNS := 2
const THUMB := 96  # px de la miniatura en la tarjeta

var grid := GridContainer.new()
var cards := {}  # id → Button, en el orden de la galería
var templates := {}  # id → valores
var random_card: Button  # paso PL.5


func _init() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	grid.columns = COLUMNS
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(grid)


func setup(folder: String, species_id: String, sliders: Array) -> void:
	random_card = random_button(THUMB + 32)
	random_card.pressed.connect(random_requested.emit)
	grid.add_child(random_card)
	for id: String in ids(folder):
		var loaded := Preset.from_text(FileAccess.get_file_as_string(folder.path_join(id + ".json")), species_id, sliders)
		if loaded["error"] != "":
			continue
		templates[id] = loaded["valores"]
		var card := Button.new()
		card.text = loaded["nombre"]
		card.tooltip_text = "Empezar desde «%s» (Ctrl+Z lo deshace)" % loaded["nombre"]
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.custom_minimum_size.y = THUMB + 32
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.expand_icon = true
		var image := Image.load_from_file(folder.path_join(id + ".png")) if FileAccess.file_exists(folder.path_join(id + ".png")) else null
		if image != null:
			card.icon = ImageTexture.create_from_image(image)
		card.pressed.connect(func() -> void: template_chosen.emit(templates[id].duplicate()))
		grid.add_child(card)
		cards[id] = card


## Paso PL.5: tarjeta «Aleatorio» con el dado (la usa también start_screen.gd).
static func random_button(height: int) -> Button:
	var card := Button.new()
	card.text = "Aleatorio"
	card.icon = preload("tema/theme_builder.gd").icon("dado")
	card.tooltip_text = "Un cuerpo al azar desde el de ahora (Ctrl+Z lo deshace)"
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.custom_minimum_size.y = height
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return card


## Ids de los presets de la carpeta, en el orden de la galería.
static func ids(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "json":
			found.append(file.get_basename())
	found.sort_custom(func(a: String, b: String) -> bool:
		var ia := ORDER.find(a)
		var ib := ORDER.find(b)
		if ia >= 0 and ib >= 0:
			return ia < ib
		if ia >= 0 or ib >= 0:
			return ia >= 0
		return a < b)
	return found
