extends HBoxContainer
# TA.2b: selector de modo, visor orbital y propiedades del Taller.
# TA.3c: en Espada edita una receta de la sesión y enseña su malla real, su tamaño y sus triángulos.
# TA.4c: en Desde imagen carga un PNG, enseña su contorno y su pieza 3D y la ajusta.
# Uso: la ventana principal monta la página una vez y alterna su visibilidad.

## Una regeneración correcta de la espada.
signal sword_generated
## Una regeneración correcta de la pieza de imagen.
signal image_generated
## Se ha recalculado el contorno de la imagen.
signal image_analyzed

const OrbitCamera := preload("../orbit_camera.gd")
const Tokens := preload("../tema/tokens.gd")
const SettingsFile := preload("../settings_file.gd")
const Recipe := preload("../../addons/creador/taller_assets/asset_recipe.gd")
const SwordGenerator := preload("../../addons/creador/taller_assets/sword_generator.gd")
const ImageSource := preload("../../addons/creador/taller_assets/image_source.gd")
const ImageMask := preload("../../addons/creador/taller_assets/image_mask.gd")
const SilhouetteMesh := preload("../../addons/creador/taller_assets/silhouette_mesh.gd")
const SwordPanel := preload("sword_panel.gd")
const ImagePanel := preload("image_panel.gd")
const MODES := ["Espada", "Desde imagen", "Camiseta"]
const SWORD := 0
const IMAGE := 1
const CONTOUR_DELAY := 0.15  # segundos desde el último cambio de un ajuste del contorno
const PROPERTIES := ["Largo, ancho y grosor de la hoja", "Imagen de origen y espesor de extrusión", "Largo de la camiseta y de las mangas"]
const VIEWS := {"Frente": Vector2(0, 0), "Perfil": Vector2(90, 0), "¾": Vector2(45, 10)}  # giro e inclinación, en grados
const PENDING := "Estas acciones estarán disponibles al incorporar los generadores y la biblioteca."
const PENDING_SWORD := "Guardar, Equipar y Exportar llegarán con la biblioteca."
const PENDING_IMAGE := "La pieza se actualiza sola. Guardar, Equipar y Exportar llegarán con la biblioteca."

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
var sword_problem := ""
var image_panel := ImagePanel.new()
var image_dialog := FileDialog.new()
var contour_timer := Timer.new()
var image_values := {}  # parametros y colores de los controles
var image_options := {}  # ajustes del contorno (su guardado en la receta llega con TA.5)
var image_source := {}  # lo último cargado, aunque todavía no haya dado una pieza
var image_contour := PackedVector2Array()  # el de la última pieza válida
var image_origin := {}  # archivo y sha256 de la última pieza válida
var image_recipe := {}  # la receta de la última pieza válida
var image_mesh: ArrayMesh  # la última pieza válida
var image_problem := ""
var current_mode := -1


func _ready() -> void:
	_build_selector()
	_build_viewer()
	_build_details()
	_build_image_tools()
	sword_panel.edited.connect(_on_sword_edited)
	sword_panel.reset_requested.connect(reset_sword)
	reset_sword()
	reset_image()
	select_mode(SWORD)


func select_mode(index: int) -> void:
	modes.get_buttons()[index].button_pressed = true
	if index == current_mode:
		return
	current_mode = index
	var is_sword := index == SWORD
	var is_image := index == IMAGE
	title.text = MODES[index]
	properties.text = PROPERTIES[index]
	planned.visible = not is_sword and not is_image
	properties.visible = not is_sword
	sword_panel.visible = is_sword
	image_panel.visible = is_image
	generate_button.disabled = not is_sword
	pending.text = PENDING_SWORD if is_sword else (PENDING_IMAGE if is_image else PENDING)
	_refresh_piece()
	_fit_view()


## Genera la receta actual. Si falla, el visor conserva la última malla válida y se muestra el motivo.
func generate_sword() -> void:
	var result: Dictionary = SwordGenerator.generate(sword_recipe)
	sword_problem = "" if result.error == "" else "No se pudo generar: " + result.error
	if result.error == "":
		sword_mesh = result.malla
	_refresh_piece()
	if result.error == "":
		sword_generated.emit()


## Carga un PNG y saca su pieza. Si falla, se ve el motivo y sigue la última pieza válida.
func load_image_file(path: String) -> bool:
	var loaded: Dictionary = ImageSource.load_png(path)
	if loaded.error != "":
		_fail_image("No se pudo cargar la imagen: " + loaded.error)
		return false
	image_source = loaded
	image_panel.show_source(loaded.imagen, path.get_file())
	var done := analyze_image()
	if done and current_mode == IMAGE:
		_fit_view()
	return done


## Recalcula el contorno de la imagen cargada con los ajustes actuales y rehace la pieza.
func analyze_image() -> bool:
	contour_timer.stop()
	if image_source.is_empty():
		return false
	var analysis: Dictionary = ImageMask.analyze(image_source.imagen, image_options)
	image_panel.show_contour(analysis.get("contorno", PackedVector2Array()), analysis.get("tamano", Vector2i.ONE))
	image_panel.show_notes(analysis.get("avisos", PackedStringArray()))
	image_panel.show_background(analysis.get("fondo", ""))
	image_analyzed.emit()
	if analysis.error != "":
		_fail_image("No se pudo sacar el contorno: " + analysis.error)
		return false
	image_problem = ""
	return _build_image_piece(analysis.contorno, {"archivo": image_source.archivo, "sha256": image_source.sha256})


## Vuelve a las medidas, los ajustes y el color iniciales, sin perder la imagen.
func reset_image() -> void:
	contour_timer.stop()
	image_values = Recipe.DEFAULTS["extrusion_imagen"].duplicate(true)
	image_options = ImageMask.DEFAULTS.duplicate()
	image_panel.show_values(image_values, image_options)
	if not image_source.is_empty():
		analyze_image()


func choose_image() -> void:
	var folder := SettingsFile.get_folder()
	if folder != "":
		image_dialog.current_dir = folder
	image_dialog.popup_centered_ratio(0.6)


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


## Medidas y color rehacen la pieza al momento; los ajustes del contorno esperan a que dejes de moverlos.
func _on_image_edited(group: String, key: String, value: Variant) -> void:
	if group == "contorno":
		image_options[key] = value
		contour_timer.start(CONTOUR_DELAY)
		return
	image_values[group][key] = value
	if not image_contour.is_empty():
		_build_image_piece(image_contour, image_origin)


func _build_image_piece(contour: PackedVector2Array, origin: Dictionary) -> bool:
	# El autor y la licencia definitivos llegan al guardar en la biblioteca (TA.5).
	var data := {"formato": Recipe.FORMAT, "version": 1, "id": "imagen", "modo": "extrusion_imagen", "autor": "Taller",
		"licencia": "propia", "fuente": origin, "parametros": image_values.parametros, "colores": image_values.colores}
	var result: Dictionary = SilhouetteMesh.generate(data, contour)
	if result.error != "":
		_fail_image("No se pudo crear la pieza: " + result.error)
		return false
	image_recipe = Recipe.normalize(data).receta
	image_contour = contour
	image_origin = origin.duplicate()
	image_mesh = result.malla
	_refresh_piece()
	image_generated.emit()
	return true


func _fail_image(message: String) -> void:
	image_problem = message
	_refresh_piece()


func _on_image_chosen(path: String) -> void:
	SettingsFile.set_folder(path.get_base_dir())
	load_image_file(path)


## Enseña la pieza y el estado del modo actual; cada modo guarda los suyos.
func _refresh_piece() -> void:
	var mesh: ArrayMesh = sword_mesh if current_mode == SWORD else (image_mesh if current_mode == IMAGE else null)
	var problem: String = sword_problem if current_mode == SWORD else (image_problem if current_mode == IMAGE else "")
	sample.mesh = mesh if mesh != null else placeholder
	info.text = _describe(mesh) if mesh != null else ""
	info.visible = mesh != null
	diagnosis.text = problem
	diagnosis.visible = problem != ""
	_paint_diagnosis()
	view_title.text = "Vista de muestra" if mesh == null else ("Vista de la espada" if current_mode == SWORD else "Vista de la pieza")


## En Desde imagen el motivo sale con el color de aviso del tema (claro u oscuro).
func _paint_diagnosis() -> void:
	if current_mode == IMAGE:
		diagnosis.add_theme_color_override("font_color", get_theme_color("font_color", "NivelAviso"))
	else:
		diagnosis.remove_theme_color_override("font_color")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_paint_diagnosis()


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
	details.add_child(image_panel)
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


func _build_image_tools() -> void:
	image_panel.edited.connect(_on_image_edited)
	image_panel.choose_requested.connect(choose_image)
	image_panel.reset_requested.connect(reset_image)
	contour_timer.one_shot = true
	contour_timer.timeout.connect(analyze_image)
	add_child(contour_timer)
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.filters = PackedStringArray(["*.png ; Imagen PNG"])
	image_dialog.file_selected.connect(_on_image_chosen)
	add_child(image_dialog)


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
