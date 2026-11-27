extends HBoxContainer
# Paso 4.5: barra inferior de la pestaña Cuerpo (como en la maqueta de la pestaña Cuerpo (hoy diseno/maqueta-v2.html)).
# - Probar huesos: alterna el maniquí entre el reposo (pose A) y la pose T, la que se exporta. El banco es la Fase 5.
# - Animación (paso 5.1): lista con «Sin animación», los clips de datos/animaciones (en bucle), las poses fijas (5.2) y,
#   al final, «Rango de movimiento» (5.9).
# - Exportar .glb: elige dónde guardar y exporta en pose T (GlbExporter); el .tres va al lado. Avisa con la ruta o el error.
# - Prenda base: muestra u oculta la prenda (BodyMaterial); el .glb sale como se ve. No entra en Deshacer.
# Paso 9.7.4: Expresión: lista con «Sin expresión» y las de VRM que tenga la especie (encima de la cara; no se guarda
#   ni se hornea: el .glb las lleva como formas a 0). Va aquí, con las otras pruebas: la pestaña Cara y ojos aún no existe.
# Paso 5.4: test_changed avisa al cambiar Probar huesos o la lista Animación (main.gd enseña el informe).
# Paso 7.0: Guardar preset… y Abrir preset… (preset_file.gd). Abrir se deshace con Ctrl+Z (solo los valores);
#   look_changed avisa de que cambiaron colores y acabado (main.gd refresca el panel Acabado).
# Paso P.1: exportar no congela la ventana: lo pesado (GlbExporter.compute) va en un hilo.
# Paso OPT.3b: también el horneado (GlbExporter.compute_bake), en otro hilo antes de ese.
# Paso P.4: atajos Ctrl+S, Ctrl+O y Ctrl+E (Cmd en Mac) en los botones; has_changes() dice si lo que entraría en el
#   preset es distinto de lo último guardado o abierto (exportar no cuenta). save_and_quit() guarda y cierra (main.gd).
# Paso P.5c: los tres diálogos de archivo se abren en la última carpeta usada (settings_file.gd).
# Paso 10.2: Guardar y Abrir valen para proyectos .gmolde (project_io.gd, por defecto) y presets .json, según la
#   extensión; el proyecto abierto se guarda entero (piezas, pose, escena). Sin carpeta usada: user://proyectos.
# Uso: var bar := BodyActions.new(); bar.setup(body_view, editor)

signal test_changed
signal look_changed

const BodyMaterial := preload("../addons/creador/body_material.gd")
const PresetFile := preload("preset_file.gd")
const ProjectIO := preload("project_io.gd")  # paso 10.2
const GlbExporter := preload("../addons/creador/glb_exporter.gd")
const SettingsFile := preload("settings_file.gd")
const ThemeBuilder := preload("tema/theme_builder.gd")  # paso IU.2: iconos

var view: SubViewportContainer  # BodyView
var bones_button: Button
var animation_list: OptionButton
var expression_list: OptionButton  # paso 9.7.4
var export_button: Button
var garment_check: CheckBox
var file_dialog: FileDialog
var save_dialog: FileDialog
var open_dialog: FileDialog
var message: AcceptDialog
var editor  # BodyEditor
var export_thread: Thread  # paso P.1: el hilo de exportar mientras trabaja
var save_button: Button
var open_button: Button
var saved_text := ""  # paso P.4: el preset de lo último guardado o abierto (sin nombre)
var quit_after_save := false  # paso P.4: «Guardar…» del aviso al cerrar
var current_path := ""  # paso IU.4: el preset guardado o abierto ("" = personaje nuevo)
var project := {}  # paso 10.2: el último proyecto abierto o guardado ({} si fue un preset)


func setup(body_view: SubViewportContainer, body_editor = null) -> void:
	view = body_view
	editor = body_editor
	bones_button = _button("Probar huesos", func() -> void: set_pose_t(not view.pose_t))
	bones_button.icon = ThemeBuilder.icon("vistas")
	bones_button.toggle_mode = true
	_add_animation_list()
	_add_expression_list()
	export_button = _button("Exportar .glb", func() -> void: popup_file_dialog(file_dialog))
	export_button.shortcut = _shortcut(KEY_E)
	export_button.icon = ThemeBuilder.icon("exportar")
	garment_check = CheckBox.new()
	garment_check.text = "Prenda base"
	garment_check.button_pressed = BodyMaterial.is_garment_visible(view.species.mesh)
	garment_check.toggled.connect(func(on: bool) -> void: BodyMaterial.set_garment_visible(view.species.mesh, on))
	add_child(garment_check)
	_add_dialogs()
	if editor != null:
		save_dialog = _preset_dialog(FileDialog.FILE_MODE_SAVE_FILE, save_preset)
		open_dialog = _preset_dialog(FileDialog.FILE_MODE_OPEN_FILE, open_preset)
		save_dialog.canceled.connect(func() -> void: quit_after_save = false)
		save_button = _button("Guardar…", func() -> void: popup_file_dialog(save_dialog))
		save_button.tooltip_text = "Guardar el personaje como proyecto (.gmolde) o como preset (.json)"
		save_button.shortcut = _shortcut(KEY_S)
		save_button.icon = ThemeBuilder.icon("guardar")
		open_button = _button("Abrir…", func() -> void: popup_file_dialog(open_dialog))
		open_button.tooltip_text = "Abrir un proyecto (.gmolde) o un preset (.json)"
		open_button.shortcut = _shortcut(KEY_O)
		open_button.icon = ThemeBuilder.icon("abrir")
		saved_text = _current_text()


## Paso P.4: ¿hay cambios sin guardar? (valores, colores, prenda o acabado; el nombre no cuenta)
func has_changes() -> bool:
	return editor != null and _current_text() != saved_text


## Paso IU.4: nombre del archivo para la barra de arriba.
func file_name() -> String:
	return current_path.get_file() if current_path != "" else "Personaje nuevo"


## Paso P.4: abre Guardar preset y, si se guarda bien, cierra el programa.
func save_and_quit() -> void:
	quit_after_save = true
	popup_file_dialog(save_dialog)


## Paso P.5c: abre un diálogo de archivo en la última carpeta usada (si sigue existiendo).
func popup_file_dialog(dialog: FileDialog) -> void:
	var folder := SettingsFile.get_folder()
	if folder == "" and dialog != file_dialog:
		folder = ProjectIO.default_folder()  # paso 10.2
	if folder != "":
		dialog.current_dir = folder
	dialog.popup_centered_ratio(0.6)


func _remember_folder(path: String) -> void:
	SettingsFile.set_folder(path.get_base_dir())


func _current_text() -> String:
	return PresetFile.to_text("", view, editor.values)


## Atajo con Ctrl (Cmd en Mac). En el botón: sale en su ayuda y no funciona si el botón está desactivado.
func _shortcut(key: Key) -> Shortcut:
	var event := InputEventKey.new()
	event.keycode = key
	event.command_or_control_autoremap = true
	var shortcut := Shortcut.new()
	shortcut.events = [event]
	return shortcut


## Guarda el personaje como proyecto (.gmolde) o como preset (.json), según la extensión, y avisa. Devuelve el error.
func save_preset(path: String) -> Error:
	var error: Error
	if ProjectIO.is_project(path):  # paso 10.2
		var built := ProjectIO.build(path, view, editor.values, project)
		error = ProjectIO.write(path, built)
		if error == OK:
			project = built
	else:
		error = PresetFile.save(path, view, editor.values)
	if error == OK:
		saved_text = _current_text()
		current_path = path
		SettingsFile.add_recent(path)  # paso PL.4
		if quit_after_save:
			get_tree().quit()
			return error
	quit_after_save = false
	_tell("Guardar", "Guardado:\n%s" % path if error == OK else "No se pudo guardar\n%s\n(%s)" % [path, error_string(error)])
	return error


## Abre un proyecto (.gmolde) o un preset (.json); si falla, avisa y no cambia nada. Devuelve el error ("" si fue bien).
func open_preset(path: String) -> String:
	var is_project := ProjectIO.is_project(path)  # paso 10.2
	var loaded := ProjectIO.read(path, view) if is_project else PresetFile.read(path, view)
	if loaded["error"] != "":
		_tell("Abrir", "No se pudo abrir\n%s\n%s" % [path, loaded["error"]])
		return loaded["error"]
	PresetFile.apply(loaded["preset"] if is_project else loaded, view, editor)
	project = loaded["proyecto"] if is_project else {}
	if is_project:  # paso AB.13: sus piezas, en lugar de las puestas
		loaded["avisos"].append_array(ProjectIO.wear_pieces(view, project["personajes"][0]["piezas"]))
	saved_text = _current_text()
	current_path = path
	SettingsFile.add_recent(path)  # paso PL.4
	garment_check.set_pressed_no_signal(BodyMaterial.is_garment_visible(view.species.mesh))
	look_changed.emit()
	if is_project and not loaded["avisos"].is_empty():
		_tell("Abrir", "Abierto, con estos avisos:\n%s" % "\n".join(loaded["avisos"]))
	elif not is_project and not loaded["desconocidas"].is_empty():
		_tell("Abrir", "Abierto. Se ignoraron estas claves desconocidas:\n%s" % ", ".join(loaded["desconocidas"]))
	return ""


func _tell(title: String, text: String) -> void:
	message.title = title
	message.dialog_text = text
	message.popup_centered()


func _preset_dialog(mode: FileDialog.FileMode, action: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.gmolde ; Proyecto de GameMolde", "*.json ; Preset de personaje"])  # paso 10.2
	if mode == FileDialog.FILE_MODE_OPEN_FILE:
		dialog.filters = PackedStringArray(["*.gmolde, *.json ; Proyecto o preset"]) + dialog.filters
	dialog.current_file = "personaje.gmolde"
	dialog.file_selected.connect(_remember_folder)
	dialog.file_selected.connect(action)
	add_child(dialog)
	return dialog


func set_pose_t(on: bool) -> void:
	bones_button.set_pressed_no_signal(on)
	view.set_pose_t(on)
	test_changed.emit()


## Elige una fila de la lista: 0 = sin animación; las demás, los clips y las poses en su orden.
func set_animation(index: int) -> void:
	animation_list.select(index)
	var entries: Array = view.animations.entries() if view.animations != null else []
	view.set_animation("" if index == 0 else (view.ROM_ID if index > entries.size() else entries[index - 1]["id"]))
	test_changed.emit()


## Paso 9.7.4: las expresiones que se pueden probar, en este orden (nombre VRM → texto de la lista).
const EXPRESSION_NAMES := {"happy": "Alegría", "angry": "Enfado", "sad": "Tristeza", "surprised": "Sorpresa",
	"blink": "Parpadeo", "blinkLeft": "Guiño izquierdo", "blinkRight": "Guiño derecho",
	"aa": "Vocal A", "ih": "Vocal I", "ou": "Vocal U", "ee": "Vocal E", "oh": "Vocal O"}  # paso 9.8: visemas


## Paso 9.7.4: elige una fila: 0 = sin expresión; las demás, las de EXPRESSION_NAMES que tenga la especie.
func set_expression(index: int) -> void:
	expression_list.select(index)
	view.set_expression("" if index == 0 else expression_list.get_item_metadata(index))


func _add_expression_list() -> void:
	expression_list = OptionButton.new()
	expression_list.add_item("Sin expresión")
	for name: String in EXPRESSION_NAMES:
		if view.has_expression(name):  # solo las que tiene la especie
			expression_list.add_item(EXPRESSION_NAMES[name])
			expression_list.set_item_metadata(expression_list.item_count - 1, name)
	expression_list.disabled = expression_list.item_count == 1
	expression_list.visible = not expression_list.disabled  # sin expresiones, fuera de la barra
	expression_list.tooltip_text = "Prueba una expresión en la cara (no se guarda; el .glb las lleva todas, a 0)" \
		if not expression_list.disabled else "Esta especie no tiene expresiones"
	expression_list.item_selected.connect(set_expression)
	add_child(expression_list)


func _add_animation_list() -> void:
	animation_list = OptionButton.new()
	animation_list.add_item("Sin animación")
	if view.animations != null:
		for entry: Dictionary in view.animations.entries():
			animation_list.add_item(entry["nombre"])
		if view.rom != null:
			animation_list.add_item("Rango de movimiento")
	animation_list.disabled = view.animations == null
	animation_list.tooltip_text = view.animation_error
	animation_list.item_selected.connect(set_animation)
	add_child(animation_list)


## Exporta y avisa. Devuelve el error de GlbExporter.
func export_to(path: String) -> Error:
	var error: Error = view.export_glb(path)
	_export_done(path, error)
	return error


## Exporta con lo pesado en un hilo: la ventana sigue viva y el botón dice «Exportando…».
func _on_file_selected(path: String) -> void:
	if export_running():
		return
	export_button.text = "Exportando…"
	export_button.disabled = true
	var job: Dictionary = view.start_export()
	if not await _in_thread(GlbExporter.compute_bake.bind(job)):  # OPT.3b: formas y huesos
		return
	GlbExporter.after_bake(job)
	if not await _in_thread(GlbExporter.compute.bind(job)):
		return
	_export_done(path, view.finish_export(job, path))


## Paso OPT.3b: una parte de la exportación en el hilo, dibujando mientras tanto. false si se cerró la ventana a mitad
## (_exit_tree ya esperó al hilo). Entre dos partes no pasa ningún fotograma: export_running() no deja de ser true.
func _in_thread(work: Callable) -> bool:
	var tree := get_tree()
	export_thread = Thread.new()
	export_thread.start(work)
	while export_thread != null and export_thread.is_alive():
		await tree.process_frame
	if export_thread == null:
		return false
	export_thread.wait_to_finish()
	export_thread = null
	return true


func export_running() -> bool:
	return export_thread != null


func _exit_tree() -> void:
	if export_thread != null:
		export_thread.wait_to_finish()
		export_thread = null


func _export_done(path: String, error: Error) -> void:
	export_button.text = "Exportar .glb"
	export_button.disabled = false
	if error == OK:
		_tell("Exportar .glb", "Guardado:\n%s\n%s%s" % [path, path.get_basename() + ".tres",  # PE.5: y la física del pelo
			"" if view.hair_physics.is_empty() else "\n" + path.get_basename() + ".tscn"])
	else:
		_tell("Exportar .glb", "No se pudo exportar a\n%s\n(error %d: %s)" % [path, error, error_string(error)])


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	add_child(button)
	return button


func _add_dialogs() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.glb ; Personaje glTF"])
	file_dialog.current_file = "personaje.glb"
	file_dialog.file_selected.connect(_remember_folder)
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	message = AcceptDialog.new()
	message.title = "Exportar .glb"
	add_child(message)
