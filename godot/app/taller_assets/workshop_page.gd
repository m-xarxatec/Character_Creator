extends HBoxContainer
# TA.2b: selector de modo, visor orbital y propiedades del Taller.
# TA.3c: en Espada edita una receta de la sesión y enseña su malla real, su tamaño y sus triángulos.
# Uso: la ventana principal monta la página una vez y alterna su visibilidad.

## Una regeneración correcta de la espada.
signal sword_generated

const OrbitCamera := preload("../orbit_camera.gd")
const Tokens := preload("../tema/tokens.gd")
const Recipe := preload("../../addons/creador/taller_assets/asset_recipe.gd")
const SwordGenerator := preload("../../addons/creador/taller_assets/sword_generator.gd")
const SwordPanel := preload("sword_panel.gd")
const MODES := ["Espada", "Desde imagen", "Camiseta"]
const SWORD := 0
const PROPERTIES := ["Largo, ancho y grosor de la hoja", "Imagen de origen y espesor de extrusión", "Largo de la camiseta y de las mangas"]
const VIEWS := {"Frente": Vector2(0, 0), "Perfil": Vector2(90, 0), "¾": Vector2(45, 10)}  # giro e inclinación, en grados
const PENDING := "Estas acciones estarán disponibles al incorporar los generadores y la biblioteca."
const PENDING_SWORD := "Guardar, Equipar y Exportar llegarán con la biblioteca."

var modes := ButtonGroup.new()
var title := Label.new()
var view_title := Label.new()
var planned := Label.new()
var properties := Label.new()
var pending := Label.new()
var info := Label.new()
var diagnosis := Label.new()
var actions := GridContainer.new()
var generate_button: Button
var view_buttons := {}  # nombre de la vista → Button
var view := SubViewportContainer.new()
var camera := OrbitCamera.new()
var sample := MeshInstance3D.new()
var placeholder := BoxMesh.new()
var sword_panel := SwordPanel.new()
var sword_recipe := {}
var sword_mesh: ArrayMesh  # la última malla válida
var current_mode := -1


func _ready() -> void:
	_build_selector()
	_build_viewer()
	_build_details()
	sword_panel.edited.connect(_on_sword_edited)
	sword_panel.reset_requested.connect(reset_sword)
	reset_sword()
	select_mode(SWORD)


func select_mode(index: int) -> void:
	modes.get_buttons()[index].button_pressed = true
	if index == current_mode:
		return
	current_mode = index
	var is_sword := index == SWORD
	title.text = MODES[index]
	view_title.text = "Vista de la espada" if is_sword else "Vista de muestra"
	properties.text = PROPERTIES[index]
	planned.visible = not is_sword
	properties.visible = not is_sword
	sword_panel.visible = is_sword
	info.visible = is_sword
	diagnosis.visible = is_sword and diagnosis.text != ""
	generate_button.disabled = not is_sword
	pending.text = PENDING_SWORD if is_sword else PENDING
	sample.mesh = sword_mesh if is_sword and sword_mesh != null else placeholder
	_fit_view()


## Genera la receta actual. Si falla, el visor conserva la última malla válida y se muestra el motivo.
func generate_sword() -> void:
	var result: Dictionary = SwordGenerator.generate(sword_recipe)
	diagnosis.text = "" if result.error == "" else "No se pudo generar: " + result.error
	diagnosis.visible = current_mode == SWORD and result.error != ""
	if result.error != "":
		return
	sword_mesh = result.malla
	info.text = _describe(sword_mesh)
	if current_mode == SWORD:
		sample.mesh = sword_mesh
	sword_generated.emit()


## Vuelve a las medidas y los colores iniciales con una sola regeneración.
func reset_sword() -> void:
	sword_recipe = _new_sword_recipe()
	sword_panel.show_recipe(sword_recipe)
	generate_sword()


## Vista rápida: orienta la cámara y vuelve a encuadrar la pieza entera.
func show_view(view_name: String) -> void:
	camera.yaw = VIEWS[view_name].x
	camera.pitch = VIEWS[view_name].y
	_fit_view()


func _on_sword_edited(group: String, key: String, value: Variant) -> void:
	sword_recipe[group][key] = value
	generate_sword()


func _new_sword_recipe() -> Dictionary:
	# El autor y la licencia definitivos llegan al guardar en la biblioteca (TA.5).
	return Recipe.normalize({"formato": Recipe.FORMAT, "version": 1, "id": "espada", "modo": "espada_parametrica",
		"autor": "Taller", "licencia": "propia"}).receta


func _describe(mesh: ArrayMesh) -> String:
	var size := mesh.get_aabb().size
	return "%d triángulos · Tamaño real: %s × %s × %s m (ancho × alto × fondo)" % [mesh.get_faces().size() / 3,
		_meters(size.x), _meters(size.y), _meters(size.z)]


func _meters(value: float) -> String:
	return ("%.3f" % value).replace(".", ",")


func _build_selector() -> void:
	var selector := _column(Tokens.PANEL_IZQUIERDO)
	_label(selector, "Crear un asset", "TituloZona")
	for i in MODES.size():
		var button := Button.new()
		button.text = MODES[i]
		button.toggle_mode = true
		button.button_group = modes
		button.pressed.connect(select_mode.bind(i))
		selector.add_child(button)


func _build_viewer() -> void:
	var center := _column(0)
	var head := HBoxContainer.new()
	center.add_child(head)
	view_title.theme_type_variation = "TituloZona"
	view_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(view_title)
	for view_name: String in VIEWS:
		var button := Button.new()
		button.text = view_name
		button.theme_type_variation = "Chip"
		button.tooltip_text = "Ver de " + view_name.to_lower() if view_name != "¾" else "Ver en tres cuartos"
		button.pressed.connect(show_view.bind(view_name))
		head.add_child(button)
		view_buttons[view_name] = button
	view.stretch = true
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(view)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	view.add_child(viewport)
	placeholder.size = Vector3(0.45, 1.0, 0.28)
	viewport.add_child(sample)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	viewport.add_child(light)
	camera.yaw = 25.0
	camera.instant = true
	viewport.add_child(camera)
	view.resized.connect(_frame)
	info.theme_type_variation = "Pista"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(info)
	diagnosis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnosis.hide()
	center.add_child(diagnosis)
	_label(center, "Arrastra para girar · Rueda para acercar o alejar", "Pista")


func _build_details() -> void:
	var details := _column(Tokens.PANEL_DERECHO)
	title.theme_type_variation = "TituloZona"
	details.add_child(title)
	planned.text = "Propiedades previstas"
	planned.theme_type_variation = "Pista"
	details.add_child(planned)
	properties.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(properties)
	details.add_child(sword_panel)
	details.add_child(HSeparator.new())
	actions.columns = 2  # en dos columnas: a 1280 × 720 deja más alto a los controles
	details.add_child(actions)
	for caption in ["Generar", "Guardar", "Equipar", "Exportar"]:
		var button := Button.new()
		button.text = caption
		button.disabled = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	generate_button = actions.get_child(0)
	generate_button.pressed.connect(generate_sword)
	pending.theme_type_variation = "Pista"
	pending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(pending)
	_label(details, "Las piezas creadas se equipan desde Ropa o Accesorios.", "Pista")


## Encuadre completo: al entrar en un modo y con las vistas rápidas. Editar no lo llama: conserva giro y zoom.
func _fit_view() -> void:
	camera.zoom = 1.0
	camera.recenter()
	_frame()


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
