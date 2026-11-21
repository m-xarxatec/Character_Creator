extends HBoxContainer
# TA.2b: selector de modo, muestra orbital y propiedades previstas del Taller.
# Uso: la ventana principal monta la página una vez y alterna su visibilidad.

const OrbitCamera := preload("../orbit_camera.gd")
const Tokens := preload("../tema/tokens.gd")
const MODES := ["Espada", "Desde imagen", "Camiseta"]
const PROPERTIES := ["Largo, ancho y grosor de la hoja", "Imagen de origen y espesor de extrusión", "Largo de la camiseta y de las mangas"]

var modes := ButtonGroup.new()
var title := Label.new()
var properties := Label.new()
var actions := VBoxContainer.new()
var view := SubViewportContainer.new()
var camera := OrbitCamera.new()
var sample := MeshInstance3D.new()


func _ready() -> void:
	var selector := _column(Tokens.PANEL_IZQUIERDO)
	_label(selector, "Crear un asset", "TituloZona")
	for i in MODES.size():
		var button := Button.new()
		button.text = MODES[i]
		button.toggle_mode = true
		button.button_group = modes
		button.pressed.connect(select_mode.bind(i))
		selector.add_child(button)

	var center := _column(0)
	_label(center, "Vista de muestra", "TituloZona")
	view.stretch = true
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	view.add_child(viewport)
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 1.0, 0.28)
	sample.mesh = box
	viewport.add_child(sample)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	viewport.add_child(light)
	camera.yaw = 25.0
	camera.instant = true
	viewport.add_child(camera)
	view.resized.connect(_frame)
	_frame()
	_label(center, "Arrastra para girar · Rueda para acercar o alejar", "Pista")

	var details := _column(Tokens.PANEL_DERECHO)
	title.theme_type_variation = "TituloZona"
	details.add_child(title)
	_label(details, "Propiedades previstas", "Pista")
	properties.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(properties)
	details.add_child(HSeparator.new())
	details.add_child(actions)
	for caption in ["Generar", "Guardar", "Equipar", "Exportar"]:
		var button := Button.new()
		button.text = caption
		button.disabled = true
		actions.add_child(button)
	_label(details, "Estas acciones estarán disponibles al incorporar los generadores y la biblioteca.", "Pista")
	_label(details, "Las piezas creadas se equipan desde Ropa o Accesorios.", "Pista")
	select_mode(0)


func select_mode(index: int) -> void:
	modes.get_buttons()[index].button_pressed = true
	title.text = MODES[index]
	properties.text = PROPERTIES[index]


func _frame() -> void:
	if view.size.x > 0 and view.size.y > 0:
		camera.frame(sample.get_aabb(), view.size.aspect())


func _column(width: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Tarjeta"
	panel.custom_minimum_size.x = width
	if width == 0:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	return column


func _label(column: VBoxContainer, caption: String, variation: String) -> void:
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
