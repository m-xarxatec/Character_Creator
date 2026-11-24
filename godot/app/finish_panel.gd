extends VBoxContainer
# Paso 4.7b: panel Acabado de la pestaña Cuerpo, debajo de los deslizadores.
# Color de piel (cualquier color), borde entre tonos, rim (fuerza y ancho) y grosor del contorno: van al material
# (BodyMaterial), así que el .glb y el .tres salen como se ve. No entra en Deshacer: tiene su botón Restablecer acabado.
# Paso P.5a: nombres en español claro y una ayuda de una línea en cada deslizador (sin «Rim»).
# SH.7a: interruptor «Estilo anime (beta)» (cuerpo y piezas a toon_soft) y, solo con él, la sección Piel (BodyMaterial.SKIN).
# Uso: var panel := FinishPanel.new(); panel.setup(body_view)

const BodyMaterial := preload("../addons/creador/body_material.gd")
const SKIN := "skin_color"
const NAMES := {"softness": "Suavidad de la sombra", "rim_strength": "Brillo de borde", "rim_width": "Ancho del brillo",
	"width_px": "Grosor de la línea"}
const HELP := {"softness": "Lo suave que es el paso de luz a sombra",
	"rim_strength": "Luz en el contorno del cuerpo, vista a contraluz",
	"rim_width": "Cuánto entra ese brillo hacia dentro", "width_px": "Grosor del contorno negro, en píxeles"}
const SKIN_NAMES := {"edge_strength": "Calidez del borde", "gloss_strength": "Brillo de piel", "blush_amount": "Rubor",
	"lips_amount": "Color de labios", "freckles": "Pecas", "face_shadow_receive": "Sombra en la cara",
	"face_light": "Luz en la cara", "outline_tint": "Color de la línea", "face_line": "Línea en la cara",
	"hair_band": "Brillo del pelo"}
const SKIN_HELP := {"edge_strength": "Franja cálida entre la luz y la sombra, como luz bajo la piel",
	"gloss_strength": "Satinado suave donde da la luz", "blush_amount": "Color en mejillas, nariz, orejas, hombros, codos, rodillas y nudillos",
	"lips_amount": "Color de los labios, sacado del de la piel", "freckles": "0: sin pecas; 1: pocas en la cara; 10: en todo el cuerpo",
	"face_shadow_receive": "Sombra que otras partes proyectan en la cara (la de la nariz casi no se ve en anime)",
	"face_light": "Más luz en la cara que en el cuerpo", "outline_tint": "0: línea negra; 1: del color de cada zona, más oscuro",
	"face_line": "Grosor de la línea en la cara, respecto al del cuerpo",
	"hair_band": "Anillo de brillo en el pelo, solo donde le da la luz"}
const NAME_WIDTH := 130.0
const STEPS := 400.0  # SH.7: fino para que 1,25 px y 0,075 (los del estilo anime) caigan en un paso

var mesh: MeshInstance3D
var view: SubViewportContainer
var skin_button: ColorPickerButton
var sliders := {}  # clave de BodyMaterial.FINISH → HSlider
var skin_sliders := {}  # SH.7a: clave de BodyMaterial.SKIN → HSlider
var anime_button: CheckButton
var skin_box: VBoxContainer  # SH.7a: la sección Piel, visible solo en estilo anime
var reset_button: Button


func setup(body_view: SubViewportContainer) -> void:
	view = body_view
	mesh = body_view.species.mesh
	var title := Label.new()
	title.text = "Acabado"
	add_child(title)
	anime_button = CheckButton.new()
	anime_button.text = "Estilo anime"
	anime_button.tooltip_text = "Sombra suave con color, piel con rubor, brillo y pecas. Apagado: el estilo clásico"
	anime_button.toggled.connect(set_anime)
	add_child(anime_button)
	skin_button = ColorPickerButton.new()
	skin_button.edit_alpha = false
	skin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_button.color_changed.connect(func(color: Color) -> void: BodyMaterial.set_color(mesh, SKIN, color))
	_add_row("Color de piel", skin_button)
	for key: String in NAMES:
		_add_slider(key)
	skin_box = VBoxContainer.new()
	var skin_title := Label.new()
	skin_title.text = "Piel"
	skin_box.add_child(skin_title)
	add_child(skin_box)
	for key: String in SKIN_NAMES:
		_add_skin_slider(key)
	reset_button = Button.new()
	reset_button.text = "Restablecer acabado"
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset_button.pressed.connect(reset)
	add_child(reset_button)
	refresh()


## Pone los controles como el material (sin avisar: no lo cambia).
func refresh() -> void:
	skin_button.color = BodyMaterial.get_color(mesh, SKIN)
	var finish: Dictionary = BodyMaterial.get_finish(mesh)
	for key: String in sliders:
		sliders[key].set_value_no_signal(finish[key])
	var anime := BodyMaterial.is_soft(mesh)
	anime_button.set_pressed_no_signal(anime)
	skin_box.visible = anime
	var skin: Dictionary = BodyMaterial.get_skin(mesh)
	for key: String in skin_sliders:
		skin_sliders[key].set_value_no_signal(skin[key])


## SH.7a: cuerpo y piezas al estilo anime o al clásico; el acabado vuelve al del estilo.
func set_anime(on: bool) -> void:
	view.set_anime_style(on)
	refresh()


## Vuelve a la piel y al acabado por defecto del estilo (sin cambiar de estilo).
func reset() -> void:
	BodyMaterial.set_color(mesh, SKIN, BodyMaterial.DEFAULTS[SKIN])
	var anime := BodyMaterial.is_soft(mesh)
	var finish: Dictionary = BodyMaterial.default_finish(anime)
	for key: String in finish:
		BodyMaterial.set_finish(mesh, key, finish[key])
	if anime:
		for key: String in BodyMaterial.SKIN_START:
			BodyMaterial.set_skin(mesh, key, BodyMaterial.SKIN_START[key])
		view.sync_lines()
	refresh()


func _add_slider(key: String) -> void:
	var limits: Array = BodyMaterial.FINISH[key]
	var slider := HSlider.new()
	slider.min_value = limits[0]
	slider.max_value = limits[1]
	slider.step = (limits[1] - limits[0]) / STEPS
	slider.scrollable = false  # la rueda no cambia valores sin querer (como en slider_panel.gd)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void: BodyMaterial.set_finish(mesh, key, value))
	slider.tooltip_text = HELP[key]
	sliders[key] = slider
	_add_row(NAMES[key], slider)


func _add_skin_slider(key: String) -> void:
	var limits: Array = BodyMaterial.SKIN[key]
	var slider := HSlider.new()
	slider.min_value = limits[0]
	slider.max_value = limits[1]
	slider.step = 1.0 if key == "freckles" else (limits[1] - limits[0]) / STEPS
	slider.scrollable = false
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		BodyMaterial.set_skin(mesh, key, value)
		if key in ["outline_tint", "hair_band"]:
			view.sync_lines())
	slider.tooltip_text = SKIN_HELP[key]
	skin_sliders[key] = slider
	_add_row(SKIN_NAMES[key], slider, skin_box)


func _add_row(text: String, control: Control, parent: Container = self) -> void:
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = NAME_WIDTH
	line.add_child(label)
	line.add_child(control)
	parent.add_child(line)
