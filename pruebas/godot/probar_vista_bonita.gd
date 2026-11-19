extends SceneTree
# Paso IU.3: vista 3D bonita (godot/app/body_view.gd, floor_shadow.gd): fondo degradado del tema detrás, sombra de suelo
# que sigue a la cadera, rejilla guardada y luz de vista previa que no cambia lo exportado. Sin ventana.
# Borra user://ajustes.cfg al empezar y al terminar.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_vista_bonita.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: no seguir a la cadera (floor_shadow._process) -> falla la 2; no guardar la rejilla -> falla la 3.

const SAME := 0.001  # m

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var Settings: GDScript = load(godot_dir.path_join("app/settings_file.gd"))
	var Tokens: GDScript = load(godot_dir.path_join("app/tema/tokens.gd"))
	var file := ProjectSettings.globalize_path(Settings.PATH)
	DirAccess.remove_absolute(file)
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var view: SubViewportContainer = main.body_view

	# 1. Fondo transparente y degradado del tema detrás.
	var colors: PackedColorArray = view.background.texture.gradient.colors
	var dark: Dictionary = Tokens.palette(true)
	check("1 fondo transparente y degradado detrás", view.viewport.transparent_bg and view.background.show_behind_parent)
	check("1 colores del tema oscuro", colors[0] == dark["vista_centro"] and colors[1] == dark["vista_borde"], str(colors))
	main.set_dark(false)
	colors = view.background.texture.gradient.colors
	var light: Dictionary = Tokens.palette(false)
	check("1 con Claro, colores del claro", colors[0] == light["vista_centro"] and colors[1] == light["vista_borde"], str(colors))

	# 2. La sombra sigue a la cadera y se queda en el suelo al animar.
	view.set_animation(view.animations.entries()[0]["id"])
	var shadow: Node3D = view.floor_shadow
	var skeleton: Skeleton3D = view.species.skeleton
	var hips := skeleton.find_bone("Hips")
	var worst := 0.0
	var low := Vector2.INF
	var high := -Vector2.INF
	var end := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < end:
		await process_frame
		var at: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hips).origin
		var place: Vector3 = shadow.global_position
		worst = maxf(worst, maxf(Vector2(at.x - place.x, at.z - place.z).length(), absf(place.y)))
		low = low.min(Vector2(at.x, at.z))
		high = high.max(Vector2(at.x, at.z))
	print("  MEDIDA la cadera recorre %.1f mm en X/Z" % ((high - low).length() * 1000.0))
	check("2 sombra en y = 0 y bajo la cadera (± 1 mm)", worst <= SAME, "%.4f m" % worst)
	view.set_animation("")

	# 3. Rejilla apagada por defecto; se enciende y se guarda.
	check("3 rejilla apagada por defecto", not shadow.grid and not Settings.get_grid())
	main.settings.grid_box.button_pressed = true
	check("3 la casilla la enciende y la guarda", shadow.grid and Settings.get_grid())

	# 4. La luz de vista previa no cambia lo exportado.
	var plain := _export(view, "user://vista_bonita_a.glb")
	main.settings.light_turn.value = 120.0
	main.settings.light_energy.value = 2.0
	check("4 la luz se gira y cambia de intensidad", is_equal_approx(view.light.light_energy, 2.0)
		and is_equal_approx(view.light.rotation_degrees.y, view.LIGHT_ANGLES.y + 120.0), str(view.light.rotation_degrees))
	var turned := _export(view, "user://vista_bonita_b.glb")
	check("4 con la luz girada, el .glb y el .tres son iguales", plain.size() == 2 and plain == turned)
	check("4 la luz no se guarda", not FileAccess.get_file_as_string(file).contains("luz"))

	main.free()
	await process_frame
	DirAccess.remove_absolute(file)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures > 0 else 0)


## Exporta y devuelve el contenido del .glb y del .tres; borra los archivos.
func _export(view: SubViewportContainer, path: String) -> Array:
	var bytes := []
	if view.export_glb(path) != OK:
		return bytes
	for file: String in [path, path.get_basename() + ".tres"]:
		var data := FileAccess.get_file_as_bytes(file)
		if file.ends_with(".tres"):  # cabecera (uid) e id de subrecursos son aleatorios: se comparan sin ellos
			data = _without_ids(data.get_string_from_utf8()).to_utf8_buffer()
		bytes.append(data)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	return bytes


func _without_ids(text: String) -> String:
	var ids := RegEx.create_from_string('(id="|SubResource\\(")(\\w+?)_\\w+"')
	return ids.sub("\n".join(text.split("\n").slice(1)), "$1$2\"", true)


func check(text: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + text, " ", detail)
	if not ok:
		failures += 1
