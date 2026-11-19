extends SceneTree
# Paso IU.7a/b: elegir zona tocando el cuerpo (godot/app/zone_ray.gd, body_view.gd): rayos sintéticos a cada parte, clic
# sin arrastrar solo con el ajuste encendido (apagado por defecto) y la casilla de Ajustes; IU.7b: al dejar quieto el
# ratón, la zona se tiñe (material_overlay) con su etiqueta, y lo exportado no cambia. Sin ventana.
# Borra user://ajustes.cfg al empezar y al terminar.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_zona_rayo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: no mirar si se arrastró (body_view.gd) -> falla la 2; quitar Head de BONE_ZONES -> falla la 1;
# no quitar la tinta al arrastrar -> falla la 4.

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var Settings: GDScript = load(godot_dir.path_join("app/settings_file.gd"))
	var file := ProjectSettings.globalize_path(Settings.PATH)
	DirAccess.remove_absolute(file)
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var view: SubViewportContainer = main.body_view
	var skeleton: Skeleton3D = view.species.skeleton

	# 1. Rayos de frente (desde +Z) a cada parte.
	view.zone_at(Vector2.ZERO)  # crea zone_ray y lee las posiciones de ahora
	var ray = view.zone_ray
	print("  MEDIDA refresh (formas + pose de todos los vértices): %d ms" % ray.refresh_ms)
	var head := _bone(skeleton, "Head")
	var thigh := (_bone(skeleton, "LeftUpperLeg") + _bone(skeleton, "LeftLowerLeg")) / 2.0
	var cases := [
		["la frente", head + Vector3(0, 0.08, 0), "Cabeza"],
		["la palma", _bone(skeleton, "LeftHand").lerp(_bone(skeleton, "LeftMiddleProximal"), 0.5), "Manos"],
		["el muslo", thigh, "Piernas"],
		["el pie", _bone(skeleton, "LeftFoot").lerp(_bone(skeleton, "LeftToes"), 0.5), "Pies"],
		["por encima de la cabeza", head + Vector3(0, 0.5, 0), ""],
	]
	for case: Array in cases:
		var at: Vector3 = case[1]
		var zone: String = ray.pick(Vector3(at.x, at.y, 3.0), Vector3.FORWARD)
		check("1 rayo hacia %s → «%s»" % [case[0], case[2]], zone == case[2], "«%s»" % zone)
	print("  MEDIDA pick (rayo contra %d triángulos, %d vértices): %d ms" % [ray.triangles.size() / 3, ray.slot.size(), ray.pick_ms])

	# 2. Clic sintético en el pecho.
	view.camera.snap()
	await process_frame
	var chest: Vector2 = view.camera.unproject_position(_bone(skeleton, "UpperChest").lerp(_bone(skeleton, "Neck"), 0.4) + Vector3(0, 0, 0.1))
	main.slider_panel.open("Global")
	_click(view, chest, chest)
	check("2 apagado (por defecto): el clic no cambia la zona", main.slider_panel.open_zone == "Global",
		main.slider_panel.open_zone)
	main.settings.touch_box.button_pressed = true
	_click(view, chest, chest + Vector2(20, 0))
	check("2 encendido: un arrastre de 20 px no la cambia", main.slider_panel.open_zone == "Global",
		main.slider_panel.open_zone)
	_click(view, chest, chest)
	check("2 encendido: el clic en el pecho abre «Pecho»", main.slider_panel.open_zone == "Pecho",
		main.slider_panel.open_zone)

	# 4. Paso del ratón: tinta y etiqueta; al arrastrar o fuera del cuerpo, nada. Lo exportado no cambia.
	var plain := _export(view, "user://zona_a.glb")
	_move(view, chest, 0)
	await _wait(250)
	check("4 quieto sobre el pecho: se tiñe «Pecho»", view.highlighted == "Pecho"
		and view.species.mesh.material_overlay != null and view.style.material_overlay != null, view.highlighted)
	check("4 la etiqueta lo dice", view.zone_label.visible and view.zone_label.text == "Pecho · clic para editar",
		view.zone_label.text)
	var lit := _export(view, "user://zona_b.glb")
	check("4 con la zona teñida, el .glb y el .tres son iguales", plain.size() == 2 and plain == lit)
	_move(view, chest + Vector2(5, 0), MOUSE_BUTTON_MASK_LEFT)
	check("4 al arrastrar se quita la tinta", view.highlighted == "" and view.species.mesh.material_overlay == null
		and not view.zone_label.visible)
	_move(view, Vector2(2, 2), 0)
	await _wait(250)
	check("4 fuera del cuerpo, sin tinta", view.highlighted == "" and view.species.mesh.material_overlay == null)

	# 3. La casilla se guarda y su descripción se ve solo encendida.
	check("3 la casilla se guarda", Settings.get_touch_zones())
	check("3 encendida, se ve la descripción", main.settings.touch_help.visible)
	main.settings.touch_box.button_pressed = false
	check("3 apagada, no se ve", not main.settings.touch_help.visible and not Settings.get_touch_zones())

	main.free()
	await process_frame
	DirAccess.remove_absolute(file)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures > 0 else 0)


func _bone(skeleton: Skeleton3D, name: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin


## Pulsa en press y suelta en release (coordenadas de la vista), con el botón izquierdo.
func _click(view: Control, press: Vector2, release: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = press if pressed else release
		view._gui_input(event)


func _move(view: Control, at: Vector2, buttons: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = buttons
	view._gui_input(event)


## Los Timer avanzan con los fotogramas: espera por tiempo.
func _wait(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame


## Exporta y devuelve el .glb y el .tres (sin la cabecera ni los id aleatorios de subrecursos); borra los archivos.
func _export(view: SubViewportContainer, path: String) -> Array:
	var bytes := []
	if view.export_glb(path) != OK:
		return bytes
	for file: String in [path, path.get_basename() + ".tres"]:
		var data := FileAccess.get_file_as_bytes(file)
		if file.ends_with(".tres"):
			var ids := RegEx.create_from_string('(id="|SubResource\\(")(\\w+?)_\\w+"')
			data = ids.sub("\n".join(data.get_string_from_utf8().split("\n").slice(1)), "$1$2\"", true).to_utf8_buffer()
		bytes.append(data)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	return bytes


func check(text: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + text, " ", detail)
	if not ok:
		failures += 1
