extends VBoxContainer
# Paso 4.7b: panel Acabado de la pestaña Cuerpo, debajo de los deslizadores.
# Color de piel (cualquier color), borde entre tonos, rim (fuerza y ancho) y grosor del contorno: van al material
# (BodyMaterial), así que el .glb y el .tres salen como se ve. No entra en Deshacer: tiene su botón Restablecer acabado.
# Paso P.5a: nombres en español claro y una ayuda de una línea en cada deslizador (sin «Rim»).
# Uso: var panel := FinishPanel.new(); panel.setup(body_view)

const BodyMaterial := preload("../addons/creador/body_material.gd")
const SKIN := "skin_color"
const NAMES := {"softness": "Suavidad de la sombra", "rim_strength": "Brillo de borde", "rim_width": "Ancho del brillo",
	"width_px": "Grosor de la línea"}
const HELP := {"softness": "Lo suave que es el paso de luz a sombra",
	"rim_strength": "Luz en el contorno del cuerpo, vista a contraluz",
	"rim_width": "Cuánto entra ese brillo hacia dentro", "width_px": "Grosor del contorno negro, en píxeles"}
const NAME_WIDTH := 130.0
const STEPS := 100.0

var mesh: MeshInstance3D
var skin_button: ColorPickerButton
var sliders := {}  # clave de BodyMaterial.FINISH → HSlider
var reset_button: Button


func setup(body_view: SubViewportContainer) -> void:
	mesh = body_view.species.mesh
	var title := Label.new()
	title.text = "Acabado"
	add_child(title)
	skin_button = ColorPickerButton.new()
	skin_button.edit_alpha = false
	skin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_button.color_changed.connect(func(color: Color) -> void: BodyMaterial.set_color(mesh, SKIN, color))
	_add_row("Color de piel", skin_button)
	for key: String in NAMES:
		_add_slider(key)
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


## Vuelve a la piel y al acabado por defecto.
func reset() -> void:
	BodyMaterial.set_color(mesh, SKIN, BodyMaterial.DEFAULTS[SKIN])
	var finish: Dictionary = BodyMaterial.default_finish()
	for key: String in finish:
		BodyMaterial.set_finish(mesh, key, finish[key])
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


func _add_row(text: String, control: Control) -> void:
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = NAME_WIDTH
	line.add_child(label)
	line.add_child(control)
	add_child(line)
