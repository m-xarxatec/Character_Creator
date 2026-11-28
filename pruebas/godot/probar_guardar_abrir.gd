extends SceneTree
# Paso 7.0: «Guardar preset…» y «Abrir preset…» de la ventana (godot/app/body_actions.gd y preset_file.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_guardar_abrir.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: si PresetFile.apply no llama a Preset.apply_look, fallan los colores, la prenda y el acabado.

const SKIN := Color(0.9, 0.5, 0.3)

var failures := 0
var BodyMaterial: GDScript
var Preset: GDScript


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	BodyMaterial = load(godot_dir.path_join("addons/creador/body_material.gd"))
	Preset = load(godot_dir.path_join("addons/creador/preset.gd"))
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var actions = main.body_actions
	var mesh: MeshInstance3D = main.body_view.species.mesh
	var folder := OS.get_user_data_dir().path_join("probar_guardar_abrir")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("heroe.json")

	main.editor.set_value("height", 0.8)
	BodyMaterial.set_color(mesh, "skin_color", SKIN)
	BodyMaterial.set_finish(mesh, "rim_width", 0.6)
	BodyMaterial.set_garment_visible(mesh, false)
	var saved_values: Dictionary = main.editor.values.duplicate()
	check("guardar va bien", actions.save_preset(path) == OK)
	var text := FileAccess.get_file_as_string(path)
	var expected: String = Preset.to_text(Preset.to_dict("heroe", "humana", saved_values,
		{"skin_color": SKIN, "garment_color": BodyMaterial.get_color(mesh, "garment_color")}, false, BodyMaterial.get_finish(mesh),
		"anime" if BodyMaterial.is_soft(mesh) else "clasico", BodyMaterial.get_skin(mesh)))  # SH.7a: estilo y piel
	check("el archivo es el preset del personaje (nombre = el del archivo)", text == expected + "\n")

	main.editor.set_value("height", 0.2)
	main.editor.set_value("muscle", 0.9)
	BodyMaterial.set_color(mesh, "skin_color", Color.WHITE)
	BodyMaterial.set_finish(mesh, "rim_width", 0.1)
	BodyMaterial.set_garment_visible(mesh, true)
	var before_open: Dictionary = main.editor.values.duplicate()
	check("abrir va bien", actions.open_preset(path) == "")
	check("vuelven los valores", main.editor.values == saved_values)
	check("vuelve el color de piel", BodyMaterial.get_color(mesh, "skin_color").is_equal_approx(SKIN),
		str(BodyMaterial.get_color(mesh, "skin_color")))
	check("vuelve la prenda (oculta) y la casilla lo enseña", not BodyMaterial.is_garment_visible(mesh)
		and not actions.garment_check.button_pressed)
	check("vuelve el acabado y el panel lo enseña", is_equal_approx(BodyMaterial.get_finish(mesh)["rim_width"], 0.6)
		and is_equal_approx(main.finish_panel.sliders["rim_width"].value, 0.6))
	check("el maniquí sigue los valores abiertos", main.body_view.values == saved_values)
	main.editor.undo()
	check("Deshacer tras abrir vuelve a los valores de antes", main.editor.values == before_open)
	main.editor.redo()

	var broken := folder.path_join("roto.json")
	FileAccess.open(broken, FileAccess.WRITE).store_string("{ esto no es json")
	var now: Dictionary = main.editor.values.duplicate()
	var error: String = actions.open_preset(broken)
	check("un archivo roto da error y no cambia nada", error != "" and main.editor.values == now, error)
	var other := folder.path_join("otra.json")
	FileAccess.open(other, FileAccess.WRITE).store_string(text.replace('"humana"', '"elfa"'))
	error = actions.open_preset(other)
	check("un preset de otra especie da error", error.contains("especie") and main.editor.values == now, error)
	check("un archivo que no existe da error", actions.open_preset(folder.path_join("no_existe.json")) != "")
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
