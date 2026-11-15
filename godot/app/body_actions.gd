extends HBoxContainer
# Paso 4.5: barra inferior de la pestaña Cuerpo (como en diseno/maqueta-pestana-cuerpo.html).
# - Probar huesos: alterna el maniquí entre el reposo (pose A) y la pose T, la que se exporta. El banco es la Fase 5.
# - Exportar .glb: elige dónde guardar y exporta en pose T (GlbExporter); el .tres va al lado. Avisa con la ruta o el error.
# - Prenda base: muestra u oculta la prenda (BodyMaterial); el .glb sale como se ve. No entra en Deshacer.
# Uso: var bar := BodyActions.new(); bar.setup(body_view)

const BodyMaterial := preload("../addons/creador/body_material.gd")

var view: SubViewportContainer  # BodyView
var bones_button: Button
var export_button: Button
var garment_check: CheckBox
var file_dialog: FileDialog
var message: AcceptDialog


func setup(body_view: SubViewportContainer) -> void:
	view = body_view
	bones_button = _button("Probar huesos", func() -> void: set_pose_t(not view.pose_t))
	bones_button.toggle_mode = true
	export_button = _button("Exportar .glb", func() -> void: file_dialog.popup_centered_ratio(0.6))
	garment_check = CheckBox.new()
	garment_check.text = "Prenda base"
	garment_check.button_pressed = BodyMaterial.is_garment_visible(view.species.mesh)
	garment_check.toggled.connect(func(on: bool) -> void: BodyMaterial.set_garment_visible(view.species.mesh, on))
	add_child(garment_check)
	_add_dialogs()


func set_pose_t(on: bool) -> void:
	bones_button.set_pressed_no_signal(on)
	view.set_pose_t(on)


## Exporta y avisa. Devuelve el error de GlbExporter.
func export_to(path: String) -> Error:
	var error: Error = view.export_glb(path)
	export_button.text = "Exportar .glb"
	export_button.disabled = false
	if error == OK:
		message.dialog_text = "Guardado:\n%s\n%s" % [path, path.get_basename() + ".tres"]
	else:
		message.dialog_text = "No se pudo exportar a\n%s\n(error %d: %s)" % [path, error, error_string(error)]
	message.popup_centered()
	return error


## Muestra «Exportando…» antes de exportar (exportar tarda ~1,5 s y bloquea la ventana).
func _on_file_selected(path: String) -> void:
	export_button.text = "Exportando…"
	export_button.disabled = true
	await get_tree().process_frame
	await get_tree().process_frame
	export_to(path)


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
