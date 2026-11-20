extends TabContainer
# Paso IU.5a: panel izquierdo (diseno/GUIA_INTERFAZ.md §2) con dos pestañas pequeñas: Zonas (silueta + lista de zonas
# con su número de ajustes) y Plantillas (template_gallery.gd, paso PL.3). Elegir una zona emite zone_chosen; select() solo marca.
# Uso: picker.setup(slider_panel.zones, counts); picker.zone_chosen.connect(slider_panel.open)

signal zone_chosen(zone: String)

const ZoneSilhouette := preload("zone_silhouette.gd")
const TemplateGallery := preload("template_gallery.gd")
const Tokens := preload("tema/tokens.gd")

var silhouette: Control  # ZoneSilhouette
var gallery: ScrollContainer  # TemplateGallery (paso PL.3)
var buttons := {}  # zona → Button de la lista
var group := ButtonGroup.new()


func _init() -> void:
	custom_minimum_size.x = Tokens.PANEL_IZQUIERDO
	var zones_page := VBoxContainer.new()
	zones_page.name = "Zonas"
	add_child(zones_page)
	silhouette = ZoneSilhouette.new()
	silhouette.zone_chosen.connect(_choose)
	zones_page.add_child(silhouette)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	zones_page.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Lista"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	gallery = TemplateGallery.new()
	gallery.name = "Plantillas"  # el nombre del nodo es el título de la pestaña
	add_child(gallery)


## zones en el orden de la tabla; counts: zona → número de ajustes.
func setup(zones: Array, counts: Dictionary) -> void:
	var list: VBoxContainer = find_child("Lista", true, false)
	for zone: String in zones:
		var button := Button.new()
		button.text = "%s   %d" % [zone, counts.get(zone, 0)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = "BotonFantasma"
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_choose.bind(zone))
		list.add_child(button)
		buttons[zone] = button


## Marca una zona en la silueta y en la lista, sin avisar.
func select(zone: String) -> void:
	silhouette.selected_zone = zone
	if buttons.has(zone):
		buttons[zone].set_pressed_no_signal(true)


func _choose(zone: String) -> void:
	select(zone)
	zone_chosen.emit(zone)
