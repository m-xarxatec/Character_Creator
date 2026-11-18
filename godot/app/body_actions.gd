extends HBoxContainer
# Paso 4.5: barra inferior de la pestaña Cuerpo (como en diseno/maqueta-pestana-cuerpo.html).
# - Probar huesos: alterna el maniquí entre el reposo (pose A) y la pose T, la que se exporta. El banco es la Fase 5.
# - Animación (paso 5.1): lista con «Sin animación», los clips de datos/animaciones (en bucle), las poses fijas (5.2) y,
#   al final, «Rango de movimiento» (5.9).
# - Exportar .glb: elige dónde guardar y exporta en pose T (GlbExporter); el .tres va al lado. Avisa con la ruta o el error.
# - Prenda base: muestra u oculta la prenda (BodyMaterial); el .glb sale como se ve. No entra en Deshacer.
# Paso 5.4: test_changed avisa al cambiar Probar huesos o la lista Animación (main.gd enseña el informe).
# Paso 7.0: Guardar preset… y Abrir preset… (preset_file.gd). Abrir se deshace con Ctrl+Z (solo los valores);
#   look_changed avisa de que cambiaron colores y acabado (main.gd refresca el panel Acabado).
# Paso P.1: exportar no congela la ventana: lo pesado (GlbExporter.compute) va en un hilo.
# Uso: var bar := BodyActions.new(); bar.setup(body_view, editor)

signal test_changed
signal look_changed

const BodyMaterial := preload("../addons/creador/body_material.gd")
const PresetFile := preload("preset_file.gd")
const GlbExporter := preload("../addons/creador/glb_exporter.gd")

var view: SubViewportContainer  # BodyView
var bones_button: Button
var animation_list: OptionButton
var export_button: Button
var garment_check: CheckBox
var file_dialog: FileDialog
var save_dialog: FileDialog
var open_dialog: FileDialog
var message: AcceptDialog
var editor  # BodyEditor
var export_thread: Thread  # paso P.1: el hilo de exportar mientras trabaja


func setup(body_view: SubViewportContainer, body_editor = null) -> void:
	view = body_view
	editor = body_editor
	bones_button = _button("Probar huesos", func() -> void: set_pose_t(not view.pose_t))
	bones_button.toggle_mode = true
	_add_animation_list()
	export_button = _button("Exportar .glb", func() -> void: file_dialog.popup_centered_ratio(0.6))
	garment_check = CheckBox.new()
	garment_check.text = "Prenda base"
	garment_check.button_pressed = BodyMaterial.is_garment_visible(view.species.mesh)
	garment_check.toggled.connect(func(on: bool) -> void: BodyMaterial.set_garment_visible(view.species.mesh, on))
	add_child(garment_check)
	_add_dialogs()
	if editor != null:
		save_dialog = _preset_dialog(FileDialog.FILE_MODE_SAVE_FILE, save_preset)
		open_dialog = _preset_dialog(FileDialog.FILE_MODE_OPEN_FILE, open_preset)
		_button("Guardar preset…", func() -> void: save_dialog.popup_centered_ratio(0.6))
		_button("Abrir preset…", func() -> void: open_dialog.popup_centered_ratio(0.6))


## Guarda el personaje como preset y avisa. Devuelve el error.
func save_preset(path: String) -> Error:
	var error := PresetFile.save(path, view, editor.values)
	_tell("Guardar preset", "Guardado:\n%s" % path if error == OK else "No se pudo guardar\n%s\n(%s)" % [path, error_string(error)])
	return error


## Abre un preset; si falla, avisa y no cambia nada. Devuelve el error ("" si fue bien).
func open_preset(path: String) -> String:
	var loaded := PresetFile.read(path, view)
	if loaded["error"] != "":
		_tell("Abrir preset", "No se pudo abrir\n%s\n%s" % [path, loaded["error"]])
		return loaded["error"]
	PresetFile.apply(loaded, view, editor)
	garment_check.set_pressed_no_signal(BodyMaterial.is_garment_visible(view.species.mesh))
	look_changed.emit()
	if not loaded["desconocidas"].is_empty():
		_tell("Abrir preset", "Abierto. Se ignoraron estas claves desconocidas:\n%s" % ", ".join(loaded["desconocidas"]))
	return ""


func _tell(title: String, text: String) -> void:
	message.title = title
	message.dialog_text = text
	message.popup_centered()


func _preset_dialog(mode: FileDialog.FileMode, action: Callable) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Preset de personaje"])
	dialog.current_file = "personaje.json"
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
	var tree := get_tree()
	export_thread = Thread.new()
	export_thread.start(GlbExporter.compute.bind(job))
	while export_thread != null and export_thread.is_alive():
		await tree.process_frame
	if export_thread == null:  # se cerró la ventana mientras tanto (_exit_tree ya esperó al hilo)
		return
	export_thread.wait_to_finish()
	export_thread = null
	_export_done(path, view.finish_export(job, path))


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
		_tell("Exportar .glb", "Guardado:\n%s\n%s" % [path, path.get_basename() + ".tres"])
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
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	message = AcceptDialog.new()
	message.title = "Exportar .glb"
	add_child(message)
