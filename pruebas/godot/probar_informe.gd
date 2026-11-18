extends SceneTree
# Paso 5.4: informe del banco de pruebas (godot/app/report_panel.gd) dentro de la ventana (main.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_informe.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en BONE_ZONES, poner ["Chest", "Torso"] antes que ["UpperChest", "Pecho"] -> falla «UpperChest».

var failures := 0
var Report: GDScript


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	Report = load(root_dir.path_join("godot/app/report_panel.gd"))
	_check_zones(JSON.parse_string(FileAccess.get_file_as_string(root_dir.path_join("godot/datos/humana/manifiesto.json"))))
	_check_rows()
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	check("la vista carga sin error", main.body_view.error == "", main.body_view.error)
	if main.body_view.error == "":
		_check_window(main)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_zones(manifest: Dictionary) -> void:
	check("LeftLowerArm → Brazos", Report.zone_of(PackedStringArray(["LeftLowerArm"])) == "Brazos")
	check("RightIndexProximal → Dedos", Report.zone_of(PackedStringArray(["RightIndexProximal"])) == "Dedos")
	check("UpperChest → Pecho (no Torso)", Report.zone_of(PackedStringArray(["UpperChest"])) == "Pecho",
		Report.zone_of(PackedStringArray(["UpperChest"])))
	check("sin huesos, sin zona", Report.zone_of(PackedStringArray()) == "")
	var without := []
	for bone: String in manifest["bones"]["deform"]:
		if bone != "Root" and Report.zone_of(PackedStringArray([bone])) == "":
			without.append(bone)
	check("cada hueso del manifiesto (menos Root) tiene zona", without.is_empty(), str(without))


func _check_rows() -> void:
	var panel: ScrollContainer = Report.new()
	var good := {"id": "x", "nivel": "bien", "texto": "bien", "huesos": PackedStringArray()}
	panel.show_results([good, {"id": "a", "nivel": "aviso", "texto": "aviso", "huesos": PackedStringArray(["Neck"])},
		good, {"id": "e", "nivel": "error", "texto": "error", "huesos": PackedStringArray(["LeftHand"])}, good])
	check("5 resultados, 5 filas, el error primero y luego el aviso", panel.rows.size() == 5 and panel.list.get_child_count() == 5
		and panel.rows[0]["nivel"] == "error" and panel.rows[1]["nivel"] == "aviso")
	check("resumen «1 errores, 1 avisos»", panel.summary.text == "1 errores, 1 avisos", panel.summary.text)
	check("botón de zona solo en las filas con huesos (Manos y Cuello)", panel.zone_buttons.size() == 2
		and panel.zone_buttons[0].text == "Manos" and panel.zone_buttons[1].text == "Cuello")
	panel.show_results([good])
	check("todo bien: el resumen lo dice", panel.summary.text == "Todo bien" and panel.rows.size() == 1)
	panel.free()


func _check_window(main: Control) -> void:
	var bar = main.body_actions
	var section = main.report_section
	check("al empezar: informe plegado, cabecera «pulsa…» y deslizadores visibles", not main.report_panel.visible
		and main.slider_panel.visible and section.header.text.contains(section.IDLE)
		and section.header.text.contains("Informe de deformación"))
	var start := Time.get_ticks_msec()
	bar.set_pose_t(true)
	print("  MEDIDA informe en pose T: %d ms" % (Time.get_ticks_msec() - start))
	var errors: Array = main.report_panel.rows.filter(func(r: Dictionary) -> bool: return r["nivel"] == "error")
	check("Probar huesos calcula el informe (cabecera con el resumen), y el neutro no tiene errores",
		main.report_panel.rows.size() >= 8 and errors.is_empty()
		and section.header.text.contains(main.report_panel.summary.text), str(errors))
	check("los deslizadores siguen visibles al probar huesos (paso P.2)", main.slider_panel.visible)
	section.header.toggled.emit(true)
	check("desplegar enseña las filas", main.report_panel.visible and section.header.text.begins_with("▾"))

	var one := {}
	for row: Dictionary in main.body_view.species.sliders:
		if row["tipo"] != "Por crear":
			for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
				one[row["id"] + side] = 1.0
	main.body_view.set_values(one)
	var sit: int = 1 + main.body_view.animations.entries().map(func(e: Dictionary) -> String: return e["id"]).find("sentarse")
	start = Time.get_ticks_msec()
	bar.set_animation(sit)
	print("  MEDIDA informe con el clip Sentarse (todo a 1): %d ms" % (Time.get_ticks_msec() - start))
	var mesh_ids := ["seccion", "cruce", "estiramiento", "degenerados"]
	var deform: Array = main.report_panel.rows.filter(func(r: Dictionary) -> bool:
		return r["id"] in mesh_ids and r["nivel"] != "bien")
	var zones := deform.map(func(r: Dictionary) -> String: return Report.zone_of(r["huesos"]))
	check("todo a 1 al sentarse: al menos un aviso de deformación, con zona", not deform.is_empty() and not "" in zones,
		str(deform.map(func(r: Dictionary) -> String: return r["texto"])))
	var crossing: Array = deform.filter(func(r: Dictionary) -> bool: return r["id"] == "cruce")
	check("el cruce de la mano con el muslo sale, en Dedos o Manos", crossing.any(func(r: Dictionary) -> bool:
		return Report.zone_of(r["huesos"]) in ["Dedos", "Manos"]))
	for row: Dictionary in main.report_panel.rows:
		if row["nivel"] != "bien":
			print("  MEDIDA fila: [%s] %s → %s" % [row["nivel"], row["texto"], Report.zone_of(row["huesos"])])

	var button: Button = main.report_panel.zone_buttons[0]
	var zone := button.text
	button.pressed.emit()
	check("pulsar la zona sale de la prueba y abre %s" % zone, section.header.text.contains(section.IDLE)
		and main.report_panel.rows.is_empty() and main.slider_panel.visible
		and not main.body_view.pose_t and main.body_view.clip == "" and main.slider_panel.open_zone == zone
		and not bar.bones_button.button_pressed and bar.animation_list.selected == 0)
