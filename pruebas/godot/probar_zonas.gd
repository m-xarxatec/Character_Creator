extends SceneTree
# Paso IU.5: panel de zonas a la izquierda (godot/app/zone_picker.gd y zone_silhouette.gd) dentro de la ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_zonas.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en zone_silhouette.gd, reflejar sin «BOX.x -» -> el clic en las formas de la derecha falla.
# IU.5c: el botón de plegar; sin conectarlo fallan sus comprobaciones.

## Puntos fijos del lado derecho de la caja 100 × 200 → zona que tienen que abrir (el reflejo de los de la izquierda).
const RIGHT_SIDE := [["Brazos", Vector2(71, 65)], ["Manos", Vector2(71.5, 89)], ["Piernas", Vector2(57, 130)],
	["Pies", Vector2(60, 180)], ["Hombros", Vector2(64, 40)]]

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	await process_frame  # la silueta ya tiene su tamaño
	var picker = main.zone_picker
	var panel = main.slider_panel
	var silhouette = picker.silhouette
	var table := _visible_zones(root_dir.path_join("godot/datos/humana/deslizadores.csv"), panel.HIDDEN_ZONES)
	check("la lista tiene las %d zonas visibles en el orden de la tabla" % table.size(), picker.buttons.keys() == table.keys()
		and table.size() == 15, str(picker.buttons.keys()))  # 15 con Cara (paso 9.1)
	var counts_ok := table.keys().all(func(z: String) -> bool: return picker.buttons[z].text.ends_with(" %d" % table[z]))
	check("cada zona dice su número de ajustes", counts_ok)
	check("al empezar, la zona abierta está marcada", silhouette.selected_zone == panel.open_zone
		and picker.buttons[panel.open_zone].button_pressed, panel.open_zone)

	var wrong: Array[String] = []
	for shape: Array in silhouette.shapes:
		var point: Vector2 = silhouette.to_control(_inside(shape[1]))
		silhouette._gui_input(_motion(point))
		var hovered: bool = silhouette.hover_zone == shape[0]
		silhouette._gui_input(_click(point))
		if not hovered or panel.open_zone != shape[0] or silhouette.selected_zone != shape[0] \
				or not picker.buttons[shape[0]].button_pressed:
			wrong.append("%s (%s)" % [shape[0], panel.open_zone])
	check("pasar el ratón ilumina y un clic abre y marca cada una de las %d formas" % silhouette.shapes.size(),
		wrong.is_empty(), str(wrong))
	var right_wrong: Array[String] = []
	for case: Array in RIGHT_SIDE:
		silhouette._gui_input(_click(silhouette.to_control(case[1])))
		if panel.open_zone != case[0]:
			right_wrong.append("%s → %s" % [case[0], panel.open_zone])
	check("el lado derecho (reflejado) está en su sitio: brazo, mano, pierna y pie", right_wrong.is_empty(), str(right_wrong))
	var before: String = panel.open_zone
	silhouette._gui_input(_click(silhouette.to_control(Vector2(5, 5))))
	check("un clic fuera del cuerpo no cambia nada", panel.open_zone == before)
	picker.buttons["Glúteos"].pressed.emit()
	check("Glúteos (sin forma de frente) se abre desde la lista", panel.open_zone == "Glúteos"
		and silhouette.selected_zone == "Glúteos")
	main._on_zone_chosen("Manos")
	check("el botón de zona del informe también mueve la marca", silhouette.selected_zone == "Manos"
		and picker.buttons["Manos"].button_pressed)
	await _check_fold(main)
	check("la pestaña «Género» existe (pasos PL.3 y PL.10)", picker.get_tab_title(1) == "Género", picker.get_tab_title(1))
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


## Paso IU.5c: el botón del borde pliega («<») y despliega («>») el panel; la vista gana el sitio.
func _check_fold(main: Control) -> void:
	var button: Button = main.fold_button
	root.size = Vector2i(1280, 720)  # sin ventana mide 64 × 64 y todo queda en su mínimo: el tamaño mínimo de la guía
	await process_frame
	var view_width: float = main.body_view.size.x
	check("al empezar el panel se ve y el botón ofrece ocultarlo («<»)", main.zone_picker.visible
		and button.tooltip_text == "Ocultar las zonas" and button.icon == main.ThemeBuilder.icon("plegar"))
	button.pressed.emit()
	await process_frame
	check("pulsarlo oculta el panel, el botón pasa a «>» y la vista gana su sitio", not main.zone_picker.visible
		and button.icon == main.ThemeBuilder.icon("desplegar") and button.is_visible_in_tree()
		and main.body_view.size.x >= view_width + main.Tokens.PANEL_IZQUIERDO, "%.0f → %.0f px" % [view_width, main.body_view.size.x])
	button.pressed.emit()
	check("pulsarlo otra vez lo vuelve a enseñar", main.zone_picker.visible and button.tooltip_text == "Ocultar las zonas")


## Zona → número de filas, en el orden de la tabla, sin las ocultas.
func _visible_zones(csv_path: String, hidden: Array) -> Dictionary:
	var zones := {}
	var file := FileAccess.open(csv_path, FileAccess.READ)
	var header := file.get_csv_line()
	var column := Array(header).find("zona")
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() > column and line[column] != "" and not line[column] in hidden:
			zones[line[column]] = zones.get(line[column], 0) + 1
	return zones


## Un punto de dentro de un polígono (el centro de su primer triángulo; vale también si es cóncavo).
func _inside(polygon: PackedVector2Array) -> Vector2:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	return (polygon[triangles[0]] + polygon[triangles[1]] + polygon[triangles[2]]) / 3.0


func _motion(point: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = point
	return event


func _click(point: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
