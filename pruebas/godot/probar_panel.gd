extends SceneTree
# Paso 4.3: panel de deslizadores (godot/app/slider_panel.gd) dentro de la ventana (main.gd), conectado a la vista. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_panel.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')

const ZONES := ["Global", "Cabeza", "Cuello", "Hombros", "Torso", "Pecho", "Cintura", "Caderas", "Glúteos", "Brazos",
		"Manos", "Dedos", "Piernas", "Pies"]  # las de deslizadores.csv, en su orden, sin Cara
const ROWS := 48  # 40 deslizadores sin Cara, 8 de ellos con dos lados
const TO_CREATE := ["shoulder_height", "buttocks_height", "buttocks_roundness"]
const TYPES := {"height": "Proporción", "gender": "Forma", "shoulder_height": "Por crear", "hand_size_l": "Proporción",
		"finger_spread_r": "Forma"}

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	check("la vista carga sin error", main.body_view.error == "", main.body_view.error)
	if main.body_view.error == "":
		_check_layout(main.slider_panel)
		_check_values(main.slider_panel, main.body_view)
		_check_live(main.slider_panel, main.body_view)
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
	panel.zone_buttons["Cabeza"].pressed.emit()
	check("elegir Cabeza la despliega y pliega Global", _open_zones(panel) == ["Cabeza"], str(_open_zones(panel)))
	check("Cabeza: Tamaño, Ancho y Alto", panel.zone_boxes["Cabeza"].get_child_count() == 3)
	check("Hombros: 4 filas (Músculo con dos lados)", panel.zone_boxes["Hombros"].get_child_count() == 4)
	var wrong := []
	for key: String in TYPES:
		if panel.badges[key].text != TYPES[key]:
			wrong.append(key)
	check("etiqueta de tipo de cada fila", wrong.is_empty(), str(wrong))
	var locked := []
	for key: String in panel.sliders:
		if not panel.sliders[key].editable:
			locked.append(key)
	check("solo los Por crear desactivados", locked == TO_CREATE, str(locked))


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
	panel.sliders["hand_size_l"].value = 1.0
	var left := skeleton.get_bone_pose_scale(skeleton.find_bone("LeftHand"))
	var right := skeleton.get_bone_pose_scale(skeleton.find_bone("RightHand"))
	check("mano izq. a 1: escala 1,2 solo en la izquierda (sin simetría hasta el 4.4)",
			left.is_equal_approx(Vector3.ONE * 1.2) and right.is_equal_approx(Vector3.ONE), "%s / %s" % [left, right])


func _open_zones(panel) -> Array:
	return panel.zones.filter(func(zone: String) -> bool: return panel.zone_boxes[zone].visible)


func _blend_values(mesh: MeshInstance3D) -> Array:
	var weights := []
	for i in mesh.mesh.get_blend_shape_count():
		weights.append(mesh.get_blend_shape_value(i))
	return weights
