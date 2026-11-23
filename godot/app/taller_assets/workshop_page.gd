extends HBoxContainer
# TA.2b: selector de modo, visor orbital y propiedades del Taller.
# TA.3c: en Espada edita una receta de la sesión y enseña su malla real, su tamaño y sus triángulos.
# TA.4c: en Desde imagen carga un PNG, enseña su contorno y su pieza 3D y la ajusta.
# TA.5b: guarda la pieza en la biblioteca local y la reabre para seguir editándola.
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
const AssetStore := preload("../../addons/creador/taller_assets/asset_store.gd")
const SwordPanel := preload("sword_panel.gd")
const ImagePanel := preload("image_panel.gd")
const LibraryPanel := preload("library_panel.gd")
const SaveAssetDialog := preload("save_asset_dialog.gd")
const AssetThumbnail := preload("asset_thumbnail.gd")
const MODES := ["Espada", "Desde imagen", "Camiseta"]
const SWORD := 0
const IMAGE := 1
const CONTOUR_DELAY := 0.15  # segundos desde el último cambio de un ajuste del contorno
const PROPERTIES := ["Largo, ancho y grosor de la hoja", "Imagen de origen y espesor de extrusión", "Largo de la camiseta y de las mangas"]
const VIEWS := {"Frente": Vector2(0, 0), "Perfil": Vector2(90, 0), "¾": Vector2(45, 10)}  # giro e inclinación, en grados
const PENDING := "Estas acciones estarán disponibles al incorporar los generadores y la biblioteca."
const PENDING_SWORD := "Equipar y Exportar llegarán en los próximos pasos."
const PENDING_IMAGE := "La pieza se actualiza sola. Equipar y Exportar llegarán en los próximos pasos."
const PENDING_NO_SOURCE := "Para guardar esta pieza, elige otra vez su imagen."

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
var image_contour_options := {}  # los ajustes que dieron image_contour
var image_origin_path := ""  # dónde leer la imagen de la última pieza válida
var store := AssetStore.new()
var library_panel := LibraryPanel.new()
var save_dialog := SaveAssetDialog.new()
var save_button: Button
var open_pieces := {SWORD: {}, IMAGE: {}}  # modo → la pieza de la biblioteca que se está editando
var last_author := ""
var library_loaded := false
var _saving := false
var current_mode := -1


func _ready() -> void:
	_build_selector()
	_build_viewer()
	_build_details()
	_build_image_tools()
	_build_library_tools()
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
	_refresh_piece()
	library_panel.select_piece(open_pieces.get(index, {}).get("id", ""))
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
	image_source.ruta = path
	image_panel.show_source(loaded.imagen, path.get_file())
	image_panel.set_contour_enabled(true)
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
	if not _build_image_piece(analysis.contorno, {"archivo": image_source.archivo, "sha256": image_source.sha256}):
		return false
	image_contour_options = image_options.duplicate()
	image_origin_path = image_source.ruta
	_refresh_piece()
	return true


## Vuelve a las medidas, los ajustes y el color iniciales, sin perder la imagen.
func reset_image() -> void:
	contour_timer.stop()
	image_values = Recipe.DEFAULTS["extrusion_imagen"].duplicate(true)
	image_options = ImageMask.DEFAULTS.duplicate()
	image_panel.show_values(image_values, image_options)
	if not image_source.is_empty():
		analyze_image()
	elif not image_contour.is_empty():  # pieza reabierta sin su imagen: su contorno guardado sigue valiendo
		_build_image_piece(image_contour, image_origin)


func choose_image() -> void:
	var folder := SettingsFile.get_folder()
	if folder != "":
		image_dialog.current_dir = folder
	image_dialog.popup_centered_ratio(0.6)


## Relee la biblioteca. La primera vez se hace al entrar en el Taller, para no retrasar el arranque.
func refresh_library() -> void:
	library_loaded = true
	var listed: Dictionary = store.list()
	library_panel.show_pieces(listed.piezas, listed.avisos, open_pieces.get(current_mode, {}).get("id", ""))


## Abre el diálogo de guardar con los datos de la pieza actual.
func request_save() -> void:
	if not contour_timer.is_stopped():
		analyze_image()
	if not _can_save():
		return
	var opened: Dictionary = open_pieces[current_mode]
	var new_image: bool = current_mode == IMAGE and image_origin.sha256 != opened.get("sha256", "")
	save_dialog.open_for({"nombre": opened.get("nombre", ""), "autor": opened.get("autor", last_author),
		"licencia": opened.get("licencia", "propia"), "reabierta": not opened.is_empty(), "pide_derechos": new_image})


## Guarda la pieza del modo actual. Devuelve {error, id} o {error}.
func save_piece(piece_name: String, author: String, license: String, as_new := false) -> Dictionary:
	if _saving or not _can_save():
		return {"error": "Ahora no se puede guardar esta pieza."}
	var mode := current_mode
	var entry := _save_entry(mode, piece_name, author, license, as_new)
	_saving = true
	entry.miniatura = await AssetThumbnail.render(self, entry.malla)
	var result: Dictionary = store.save(entry)
	_saving = false
	if result.error == "":
		_after_save(mode, result.id, entry)
	return result


## Reabre una pieza de la biblioteca en su modo. Si no se puede, avisa y no cambia lo que hay en pantalla.
func open_piece(id: String) -> bool:
	var opened: Dictionary = store.open(id)
	if opened.error != "":
		library_panel.show_notes(PackedStringArray([opened.error]))
		return false
	var mode := SWORD if opened.receta.modo == AssetStore.SWORD_MODE else IMAGE
	if mode == SWORD:
		_show_opened_sword(opened)
	else:
		_show_opened_image(opened)
	open_pieces[mode] = {"id": id, "nombre": opened.nombre, "autor": opened.receta.autor, "licencia": opened.receta.licencia,
		"sha256": opened.receta.fuente.sha256 if mode == IMAGE else ""}
	select_mode(mode)
	_refresh_piece()
	_fit_view()
	library_panel.select_piece(id)
	library_panel.show_notes(opened.avisos)
	return true


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


func _can_save() -> bool:
	if current_mode == SWORD:
		return sword_mesh != null and sword_problem == ""
	return current_mode == IMAGE and image_mesh != null and image_origin_path != "" and FileAccess.file_exists(image_origin_path)


## Una foto de la pieza válida: lo que se edite después no entra en este guardado.
func _save_entry(mode: int, piece_name: String, author: String, license: String, as_new: bool) -> Dictionary:
	var recipe: Dictionary = (sword_recipe if mode == SWORD else image_recipe).duplicate(true)
	recipe.autor = author
	recipe.licencia = license
	var entry := {"nombre": piece_name, "receta": recipe, "malla": sword_mesh if mode == SWORD else image_mesh, "miniatura": null}
	if not as_new and not open_pieces[mode].is_empty():
		entry.reemplaza = open_pieces[mode].id
	if mode == IMAGE:
		entry.contorno = image_contour
		entry.ajustes = image_contour_options.duplicate()
		entry.fuente_bytes = FileAccess.get_file_as_bytes(image_origin_path)
	return entry


func _after_save(mode: int, id: String, entry: Dictionary) -> void:
	last_author = entry.receta.autor
	open_pieces[mode] = {"id": id, "nombre": entry.nombre, "autor": entry.receta.autor, "licencia": entry.receta.licencia,
		"sha256": entry.receta.fuente.sha256 if mode == IMAGE else ""}
	if mode == IMAGE:  # desde ahora la copia de la biblioteca vale aunque se borre el PNG original
		image_origin_path = store.packs_folder.path_join(id).path_join(entry.receta.fuente.archivo)
		if image_source.get("sha256", "") == entry.receta.fuente.sha256:
			image_source.ruta = image_origin_path
	refresh_library()
	_refresh_piece()


func _on_save_requested(piece_name: String, author: String, license: String, as_new: bool) -> void:
	var result: Dictionary = await save_piece(piece_name, author, license, as_new)
	if result.error == "":
		save_dialog.hide()
	else:
		save_dialog.show_error(result.error)


func _show_opened_sword(opened: Dictionary) -> void:
	sword_recipe = opened.receta.duplicate(true)
	sword_panel.show_recipe(sword_recipe)
	generate_sword()


## Enseña la pieza guardada tal cual: su contorno es el guardado, aunque la imagen ya no esté.
func _show_opened_image(opened: Dictionary) -> void:
	contour_timer.stop()
	var recipe: Dictionary = opened.receta.duplicate(true)
	image_values = {"parametros": recipe.parametros.duplicate(), "colores": recipe.colores.duplicate()}
	image_options = opened.ajustes.duplicate()
	image_contour_options = opened.ajustes.duplicate()
	image_contour = opened.contorno
	image_origin = recipe.fuente.duplicate()
	image_recipe = recipe
	image_mesh = opened.malla
	image_problem = ""
	image_panel.show_values(image_values, image_options)
	var file_name: String = image_origin.archivo.get_file()
	if opened.imagen == null:
		image_source = {}
		image_origin_path = ""
		image_panel.show_missing_source(file_name)
		image_panel.show_notes(PackedStringArray())
	else:
		image_origin_path = store.packs_folder.path_join(opened.id).path_join(image_origin.archivo)
		image_source = {"error": "", "imagen": opened.imagen, "archivo": image_origin.archivo, "sha256": image_origin.sha256,
			"ruta": image_origin_path}
		image_panel.show_source(opened.imagen, file_name)
		var analysis: Dictionary = ImageMask.analyze(opened.imagen, image_options)
		image_panel.show_contour(opened.contorno, analysis.get("tamano", Vector2i.ONE))
		image_panel.show_notes(analysis.get("avisos", PackedStringArray()))
		image_panel.show_background(analysis.get("fondo", ""))
	image_panel.set_contour_enabled(opened.imagen != null)


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
	save_button.disabled = not _can_save()
	pending.text = _pending_text()
	view_title.text = "Vista de muestra" if mesh == null else ("Vista de la espada" if current_mode == SWORD else "Vista de la pieza")


func _pending_text() -> String:
	if current_mode == SWORD:
		return PENDING_SWORD
	if current_mode != IMAGE:
		return PENDING
	return PENDING_NO_SOURCE if image_mesh != null and not _can_save() else PENDING_IMAGE


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
	selector.add_child(HSeparator.new())
	selector.add_child(library_panel)


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
	save_button = actions.get_child(1)
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


func _build_library_tools() -> void:
	library_panel.piece_chosen.connect(open_piece)
	save_button.pressed.connect(request_save)
	save_dialog.save_requested.connect(_on_save_requested)
	add_child(save_dialog)
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and not library_loaded:
		refresh_library()


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
