extends SceneTree
# Pasos 4.3 y 4.4: panel de deslizadores (godot/app/slider_panel.gd) dentro de la ventana (main.gd), conectado al editor
# y a la vista: zonas, filas, etiquetas, barras en vivo, simetría con su aviso, Deshacer, Rehacer, Ctrl+Z y Restablecer zona. Sin ventana.
# Paso IU.6b: una zona a la vista, filas nuevas (slider_row.gd), una fila por lado con Simetría, buscador; Deshacer y
# Rehacer son los de la barra de arriba. Que detecta el fallo: buscar solo en el nombre -> «ancho» da 5, no 6.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_panel.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')

const ZONES := ["Global", "Cabeza", "Cuello", "Hombros", "Torso", "Pecho", "Cintura", "Caderas", "Glúteos", "Brazos",
		"Manos", "Dedos", "Piernas", "Pies"]  # las de deslizadores.csv, en su orden, sin Cara
const ROWS := 48  # 40 deslizadores sin Cara, 8 de ellos con dos lados
const TO_CREATE := []  # desde el 6.2 no queda ningún Por crear
const TYPES := {"height": "Proporción", "gender": "Forma", "shoulder_height": "Forma", "hand_size_l": "Proporción",
		"finger_spread_r": "Forma"}

var failures := 0
var main_node: Control  # paso IU.6b: Deshacer y Rehacer están en su barra de arriba


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	main_node = main
	await process_frame
	check("la vista carga sin error", main.body_view.error == "", main.body_view.error)
	if main.body_view.error == "":
		_check_layout(main.slider_panel)
		_check_values(main.slider_panel, main.body_view)
		_check_live(main.slider_panel, main.body_view)
		_check_symmetry(main.slider_panel, main.body_view)
		_check_history(main.slider_panel, main.body_view)
		_check_search(main.slider_panel)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_layout(panel) -> void:
	check("zonas en el orden de la tabla y sin Cara", panel.zones == ZONES, str(panel.zones))
	check("%d filas" % ROWS, panel.sliders.size() == ROWS, str(panel.sliders.size()))
	check("empieza desplegada la primera zona", _open_zones(panel) == ["Global"], str(_open_zones(panel)))
	panel.open("Cabeza")
	check("elegir Cabeza la despliega y pliega Global", _open_zones(panel) == ["Cabeza"], str(_open_zones(panel)))
	check("Cabeza: Tamaño, Ancho y Alto", _rows(panel, "Cabeza") == 3)
	check("Hombros: 4 filas (Músculo con dos lados)", _rows(panel, "Hombros") == 4)
	check("cada zona acaba con su botón Restablecer zona", panel.zones.all(func(zone: String) -> bool:
			return panel.zone_boxes[zone].get_child(-1) == panel.reset_buttons[zone]))
	check("la rueda no mueve ninguna barra", panel.sliders.values().all(func(slider: HSlider) -> bool: return not slider.scrollable))
	check("empieza con Simetría marcada y sin Deshacer ni Rehacer", panel.symmetry_box.button_pressed
			and main_node.undo_button.disabled and main_node.redo_button.disabled)
	var wrong := []
	for key: String in TYPES:
		if panel.badges[key].text != TYPES[key]:
			wrong.append(key)
	check("etiqueta de tipo de cada fila", wrong.is_empty(), str(wrong))
	var locked := []
	for key: String in panel.sliders:
		if not panel.sliders[key].editable:
			locked.append(key)
	check("ninguna fila desactivada (no queda ningún Por crear)", locked == TO_CREATE, str(locked))


## Paso IU.6b: con Simetría se ve una fila por pareja; sin ella, las dos. Buscar mira el nombre y la ayuda.
func _check_search(panel) -> void:
	panel.open("Manos")
	panel.editor.symmetry = true
	panel.refresh()
	check("con Simetría, Manos enseña 2 filas (una por pareja, con ⇆)", panel.visible_keys() == ["hand_size_l", "hand_position_l"]
		and panel.rows["hand_size_l"].name_label.text.ends_with("⇆"), str(panel.visible_keys()))
	panel.symmetry_box.button_pressed = false
	check("sin Simetría, las 4 filas (izq. y der.)", panel.visible_keys().size() == 4, str(panel.visible_keys()))
	panel.editor.match_side("_l")
	panel.symmetry_box.button_pressed = true
	panel.filter("ancho")
	var found: Array[String] = panel.visible_keys()
	var zones := {}
	for key: String in found:
		zones[panel.rows[key].row["zona"]] = true
	check("buscar «ancho» encuentra 6 ajustes de 5 zonas (Torso tiene Ancho y Espalda ancha)", found.size() == 6 and zones.size() == 5
		and panel.count_label.text == "6 ajustes", "%s %s" % [found, panel.count_label.text])
	panel.filter("MUSCULO")
	check("sin mayúsculas ni tildes: «MUSCULO» encuentra Músculo", "muscle" in panel.visible_keys())
	panel.filter("")
	check("borrar la búsqueda vuelve a la zona abierta", panel.visible_keys() == ["hand_size_l", "hand_position_l"]
		and panel.title.text == "Manos", str(panel.visible_keys()))
	panel.filter("pie")
	panel.open("Cabeza")
	check("abrir una zona deja de buscar", panel.search.text == "" and panel.title.text == "Cabeza"
		and panel.count_label.text == "3 ajustes", panel.count_label.text)


func _check_values(panel, view) -> void:
	var wrong := []
	for key: String in panel.sliders:
		if panel.sliders[key].editable and not is_equal_approx(panel.sliders[key].value, view.values[key]):
			wrong.append(key)
	check("cada barra empieza con el valor del preset", wrong.is_empty(), str(wrong))


func _check_live(panel, view) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	panel.sliders["head_size"].value = 1.0
	var head := skeleton.get_bone_pose_scale(skeleton.find_bone("Head"))
	check("mover Cabeza › Tamaño a 1 escala la cabeza 1,3", head.is_equal_approx(Vector3.ONE * 1.3), str(head))
	check("y el valor queda en la vista", view.values["head_size"] == 1.0)
	var before := _blend_values(view.species.mesh)
	panel.sliders["muscle"].value = 1.0
	check("mover Global › Músculo cambia las formas de la malla", _blend_values(view.species.mesh) != before)
	check("Deshacer se activa tras un cambio", not main_node.undo_button.disabled)


func _open_zones(panel) -> Array:
	return panel.zones.filter(func(zone: String) -> bool: return panel.zone_boxes[zone].visible)


func _blend_values(mesh: MeshInstance3D) -> Array:
	var weights := []
	for i in mesh.mesh.get_blend_shape_count():
		weights.append(mesh.get_blend_shape_value(i))
	return weights


func _rows(panel, zone: String) -> int:
	return panel.zone_boxes[zone].get_children().filter(func(child: Node) -> bool: return child.get("key") != null).size()


func _scale(view, bone: String) -> Vector3:
	return view.species.skeleton.get_bone_pose_scale(view.species.skeleton.find_bone(bone))


func _check_symmetry(panel, view) -> void:
	panel.sliders["hand_size_l"].value = 1.0
	check("con simetría, mover la mano izq. mueve la barra der.", panel.sliders["hand_size_r"].value == 1.0)
	check("y las dos manos escalan 1,2", _scale(view, "RightHand").is_equal_approx(Vector3.ONE * 1.2))
	panel.symmetry_box.button_pressed = false
	check("desmarcar Simetría la apaga en el editor", not panel.editor.symmetry)
	panel.sliders["hand_size_l"].value = 0.0
	check("sin simetría, la mano izq. a 0 no mueve la der.", panel.sliders["hand_size_r"].value == 1.0
			and _scale(view, "LeftHand").is_equal_approx(Vector3.ONE * 0.8) and _scale(view, "RightHand").is_equal_approx(Vector3.ONE * 1.2))
	panel.symmetry_box.button_pressed = true
	var dialog: AcceptDialog = panel.symmetry_dialog
	check("al marcarla con lados distintos sale el aviso", dialog.visible)
	check("el aviso lista Manos › Tamaño: izq. 0,00 / der. 1,00", dialog.dialog_text.contains("Manos › Tamaño: izq. 0,00 / der. 1,00"),
			dialog.dialog_text.replace("\n", " | "))
	dialog.custom_action.emit("_r")
	check("Igualar a la derecha: la barra izq. pasa a 1,0 y se cierra el aviso", panel.sliders["hand_size_l"].value == 1.0
			and not dialog.visible and _scale(view, "LeftHand").is_equal_approx(Vector3.ONE * 1.2))
	check("y la simetría queda activada", panel.editor.symmetry)
	main_node.undo_button.pressed.emit()
	check("Deshacer devuelve la barra izq. a 0", panel.sliders["hand_size_l"].value == 0.0)
	panel.symmetry_box.button_pressed = false
	panel.symmetry_box.button_pressed = true
	dialog.confirmed.emit()
	check("Mantener como está: no cambia nada y activa la simetría", panel.sliders["hand_size_l"].value == 0.0
			and panel.sliders["hand_size_r"].value == 1.0 and panel.editor.symmetry and not dialog.visible)
	panel.editor.match_side("_l")
	panel.symmetry_box.button_pressed = false
	panel.symmetry_box.button_pressed = true
	check("con los lados iguales no sale el aviso", not dialog.visible and panel.editor.symmetry)


func _check_history(panel, view) -> void:
	panel.reset_buttons["Cabeza"].pressed.emit()
	check("Restablecer Cabeza: barra Tamaño a 0,5 y cabeza a escala 1", panel.sliders["head_size"].value == 0.5
			and _scale(view, "Head").is_equal_approx(Vector3.ONE))
	main_node.undo_button.pressed.emit()
	check("Deshacer: vuelve a 1 y la cabeza a 1,3", panel.sliders["head_size"].value == 1.0
			and _scale(view, "Head").is_equal_approx(Vector3.ONE * 1.3))
	check("Rehacer se activa", not main_node.redo_button.disabled)
	main_node.redo_button.pressed.emit()
	check("Rehacer: otra vez 0,5", panel.sliders["head_size"].value == 0.5)
	_press_keys(KEY_Z, false)
	check("Ctrl+Z deshace", panel.sliders["head_size"].value == 1.0, str(panel.sliders["head_size"].value))
	_press_keys(KEY_Z, true)
	check("Ctrl+Mayús+Z rehace", panel.sliders["head_size"].value == 0.5, str(panel.sliders["head_size"].value))
	_press_keys(KEY_Z, false)
	_press_keys(KEY_Y, false)
	check("Ctrl+Y rehace", panel.sliders["head_size"].value == 0.5, str(panel.sliders["head_size"].value))
	var steps: int = panel.editor._undo.size()
	panel.editor.begin_change()  # lo que hace el panel al pulsar la barra con el ratón
	for value in [0.6, 0.7, 0.8]:
		panel.sliders["head_size"].value = value
	panel.sliders["head_size"].drag_ended.emit(true)
	check("un arrastre de la barra es un solo cambio", panel.editor._undo.size() == steps + 1, str(panel.editor._undo.size() - steps))


func _press_keys(key: Key, shift: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.ctrl_pressed = true
	event.shift_pressed = shift
	event.pressed = true
	root.push_input(event)
