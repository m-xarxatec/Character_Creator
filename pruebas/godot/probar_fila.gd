extends SceneTree
# Paso IU.6a: fila de deslizador (godot/app/slider_row.gd): número 0–100, ↺, relleno desde el neutro, ayuda y extremos.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_fila.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en slider_row.gd, fill_span desde 0 (la izquierda) en vez de desde el neutro -> fallan los rellenos.

const PX := 1.0  # tolerancia del relleno, en píxeles

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var Row: GDScript = load(godot_dir.path_join("app/slider_row.gd"))
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var editor = main.editor
	var rows := {}
	for table_row: Dictionary in editor.rows:
		rows[table_row["id"]] = table_row
	var help: Dictionary = Row.load_help()
	check("ayudas leídas para las %d filas visibles" % help.size(), help.size() == 60 and help["gender"]["ayuda"] != "",
		str(help.size()))
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 340
	main.add_child(box)
	var row = Row.new()
	row.setup(editor, rows["head_width"], "", help.get("head_width", {}))
	box.add_child(row)
	row.refresh()
	await process_frame

	row.number.text = "73"
	row.number.focus_exited.emit()
	check("escribir 73 deja 0,73", is_equal_approx(editor.values["head_width"], 0.73), str(editor.values["head_width"]))
	editor.undo()
	check("y es un solo cambio para Deshacer", is_equal_approx(editor.values["head_width"], 0.5))
	row.number.text = "150"
	row.number.focus_exited.emit()
	check("escribir 150 deja 1 (como mucho 100)", is_equal_approx(editor.values["head_width"], 1.0))
	row.number.text = "hola"
	row.number.focus_exited.emit()
	check("escribir algo que no es un número no cambia nada", is_equal_approx(editor.values["head_width"], 1.0)
		and row.number.text == "100", row.number.text)
	check("↺ activo fuera del neutro", not row.reset_button.disabled)
	row.reset_button.pressed.emit()
	check("↺ vuelve al neutro y se queda atenuado", is_equal_approx(editor.values["head_width"], 0.5)
		and row.reset_button.disabled and row.number.text == "50")
	editor.undo()
	row.refresh()
	check("Deshacer después de ↺ vuelve a 1", is_equal_approx(editor.values["head_width"], 1.0))

	var grabber := float(row.slider.get_theme_icon("grabber").get_width())
	var width: float = row.track.size.x - grabber
	for value: float in [0.8, 0.2]:
		editor.set_value("head_width", value)
		row.refresh()
		var span: Vector2 = row.fill_span()
		var expected := Vector2(minf(value, 0.5), maxf(value, 0.5)) * width + Vector2.ONE * grabber / 2.0
		check("relleno del neutro a %.1f: %.0f–%.0f px" % [value, expected.x, expected.y],
			absf(span.x - expected.x) < PX and absf(span.y - expected.y) < PX, "%.1f–%.1f" % [span.x, span.y])

	var gender = Row.new()
	gender.setup(editor, rows["gender"], "", help.get("gender", {}))
	box.add_child(gender)
	var ends: Array[String] = []
	for label: Label in gender.find_children("*", "Label", true, false):
		ends.append(label.text)
	check("Complexión enseña «Femenino» y «Masculino» y su ayuda", "Femenino" in ends and "Masculino" in ends
		and gender.tooltip_text != "", str(ends))
	var hand = Row.new()
	hand.setup(editor, rows["hand_size"], "_l", help.get("hand_size", {}))
	box.add_child(hand)
	hand.set_symmetric(true)
	var with_symmetry: String = hand.name_label.text
	hand.set_symmetric(false)
	check("dos lados: «⇆» con Simetría y «(izq.)» sin ella", with_symmetry.ends_with("⇆")
		and hand.name_label.text.ends_with("(izq.)"), "%s / %s" % [with_symmetry, hand.name_label.text])
	check("la barra no se mueve con la rueda", not row.slider.scrollable)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
