extends SceneTree
# Paso PL.3: galería de plantillas (godot/app/template_gallery.gd) en la ventana. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_plantillas.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en main.gd, conectar template_chosen a body_actions.open_preset -> no es un cambio de Deshacer.
# Paso PL.5: «Aleatorio» (randomizer.gd) en la galería y en «Nuevo personaje». Detecta el fallo: sin igualar los lados.

const COUNT := 3  # paso PL.10: Femenino, Masculino y Neutro (anime.json)
const CUSTOM_SKIN := Color(0.6, 0.4, 0.3)
const ROLLS := 10  # cuerpos al azar con el informe en pose T

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var gallery = main.zone_picker.gallery
	var ids: Array = gallery.cards.keys()
	check("%d tarjetas en el orden de la galería, la última «Neutro»" % COUNT, ids.size() == COUNT
		and ids == gallery.ORDER and gallery.cards["anime"].text == "Neutro", str(ids))
	check("cada tarjeta lleva su miniatura de 256 px", ids.all(func(id: String) -> bool:
		return gallery.cards[id].icon != null and gallery.cards[id].icon.get_width() == 256))

	var mesh: MeshInstance3D = main.body_view.species.mesh
	var material: GDScript = load(root_dir.path_join("godot/addons/creador/body_material.gd"))
	material.set_color(mesh, "skin_color", CUSTOM_SKIN)
	var before: Dictionary = main.editor.values.duplicate()
	gallery.cards["masculino"].pressed.emit()
	var expected: Dictionary = gallery.templates["masculino"]
	check("elegir Masculino deja gender = 1 y los valores del archivo", main.editor.values["gender"] == 1.0
		and main.editor.values == expected)
	check("y no cambia el color de piel ni el archivo abierto", material.get_color(mesh, "skin_color") == CUSTOM_SKIN
		and main.body_actions.current_path == "" and main.body_actions.has_changes())
	main.editor.undo()
	check("Deshacer vuelve a los valores de antes (un solo cambio)", main.editor.values == before)
	_check_random(main, root_dir)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)



## Paso PL.5: la tarjeta «Aleatorio» cambia solo el cuerpo, dentro de 0,2–0,8 y con los lados iguales, y se deshace.
func _check_random(main: Control, root_dir: String) -> void:
	var Randomizer: GDScript = load(root_dir.path_join("godot/app/randomizer.gd"))
	var sliders: Array = main.body_view.species.sliders
	var gallery = main.zone_picker.gallery
	check("la galería empieza por «Aleatorio» con el dado", gallery.grid.get_child(0) == gallery.random_card
		and gallery.random_card.text == "Aleatorio" and gallery.random_card.icon != null)
	gallery.cards["femenino"].pressed.emit()
	var before: Dictionary = main.editor.values.duplicate()
	gallery.random_card.pressed.emit()
	var after: Dictionary = main.editor.values
	var bad := []
	for row: Dictionary in sliders:
		var sides: Array = ["_l", "_r"] if row["lados"] == "2" else [""]
		var key: String = row["id"] + sides[0]
		var kept: bool = row["zona"] in Randomizer.KEEP_ZONES or row["id"] in Randomizer.KEEP
		if kept and after[key] != before[key]:
			bad.append(key)
		elif not kept and (after[key] < Randomizer.LOW or after[key] > Randomizer.HIGH or after[row["id"] + sides[-1]] != after[key]):
			bad.append(key)
	check("Aleatorio: el cuerpo en 0,2–0,8 con los lados iguales; complexión, cabeza, cara y alisado sin tocar", bad.is_empty()
		and after != before, str(bad))
	main.editor.undo()
	check("Deshacer lo devuelve", main.editor.values == before)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 5
	b.seed = 5
	check("la misma semilla da el mismo cuerpo", Randomizer.values(before, sliders, a) == Randomizer.values(before, sliders, b))
	var errors := 0
	for i in ROLLS:
		gallery.random_card.pressed.emit()
		main.body_actions.set_pose_t(true)
		errors += main.report_panel.rows.filter(func(r: Dictionary) -> bool: return r["nivel"] == "error").size()
		main.body_actions.set_pose_t(false)
	check("%d cuerpos al azar sin errores del informe en pose T" % ROLLS, errors == 0, "%d errores" % errors)
	var screen: AcceptDialog = main.start_screen
	screen.show_screen()
	var last: Dictionary = main.editor.values.duplicate()
	screen.random_card.pressed.emit()
	check("«Nuevo personaje» tiene «Aleatorio»: cierra la ventana y cambia el cuerpo", not screen.visible
		and main.editor.values != last and screen.random_card.text == "Aleatorio")


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
