extends SceneTree
# Paso PL.3: galería de plantillas (godot/app/template_gallery.gd) en la ventana. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_plantillas.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en main.gd, conectar template_chosen a body_actions.open_preset -> no es un cambio de Deshacer.

const COUNT := 11  # anime.json (Neutro) y las 10 plantillas de PL.1
const CUSTOM_SKIN := Color(0.6, 0.4, 0.3)

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var gallery = main.zone_picker.gallery
	var ids: Array = gallery.cards.keys()
	check("%d tarjetas en el orden de la galería, la primera «Neutro»" % COUNT, ids.size() == COUNT
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
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
