extends SceneTree
# Paso 4.7b: panel Acabado (godot/app/finish_panel.gd) dentro de la ventana (main.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_acabado.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Paso P.5a: nombres sin «Rim» y ayuda en cada deslizador. Detecta el fallo: volver a «Rim (fuerza)».

var failures := 0
var BodyMaterial: GDScript


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	BodyMaterial = load(root_dir.path_join("godot/addons/creador/body_material.gd"))
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	check("la vista carga sin error", main.body_view.error == "", main.body_view.error)
	if main.body_view.error == "":
		_check_panel(main.finish_panel, main.body_view)
		_check_names(main.finish_panel)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Paso P.5a: sin «Rim» y con ayuda en cada deslizador.
func _check_names(panel) -> void:
	var labels: Array[String] = []
	for label: Label in panel.find_children("*", "Label", true, false):
		labels.append(label.text)
	check("ningún nombre del panel dice «Rim» (paso P.5a)", not " ".join(labels).contains("Rim")
		and labels.has("Brillo de borde"), str(labels))
	var without_help := 0
	for slider: HSlider in panel.sliders.values():
		without_help += int(slider.tooltip_text == "")
	check("cada deslizador tiene su ayuda", without_help == 0, "%d sin ayuda" % without_help)


func _check_panel(panel, view) -> void:
	var mesh: MeshInstance3D = view.species.mesh
	var defaults: Dictionary = BodyMaterial.default_finish()
	var skin: Color = BodyMaterial.DEFAULTS["skin_color"]
	check("un deslizador por cada valor del acabado", panel.sliders.keys() == BodyMaterial.FINISH.keys(), str(panel.sliders.keys()))
	check("el panel empieza como el material", panel.skin_button.color == skin and _slider_values(panel) == defaults,
		str(_slider_values(panel)))
	check("la piel no lleva transparencia", not panel.skin_button.edit_alpha)
	for key: String in panel.sliders:
		var slider: HSlider = panel.sliders[key]
		var limits: Array = BodyMaterial.FINISH[key]
		check("'%s': la barra va de %s a %s y no sigue a la rueda" % [key, limits[0], limits[1]],
			slider.min_value == limits[0] and slider.max_value == limits[1] and not slider.scrollable)
		slider.value = slider.max_value
		var top: float = BodyMaterial.get_finish(mesh)[key]
		slider.value = slider.min_value
		check("'%s': mover la barra cambia el material" % key, top == limits[1] and BodyMaterial.get_finish(mesh)[key] == limits[0])
	var green := Color(0.2, 0.7, 0.3)
	panel.skin_button.color_changed.emit(green)
	check("elegir un color cambia la piel", BodyMaterial.get_color(mesh, "skin_color").is_equal_approx(green))
	check("la prenda no cambia", BodyMaterial.get_color(mesh, "garment_color") == BodyMaterial.DEFAULTS["garment_color"])
	check("la copia con estilo de la vista usa el mismo material", view.style.material_override == mesh.material_override)
	var copy: ShaderMaterial = BodyMaterial.standalone(mesh)
	check("el .tres saldría con la piel y el acabado elegidos", (copy.get_shader_parameter("skin_color") as Color).is_equal_approx(green)
		and copy.get_shader_parameter("softness") == 0.0 and copy.next_pass.get_shader_parameter("width_px") == 0.0)
	panel.reset_button.pressed.emit()
	check("Restablecer acabado: piel y acabado por defecto, en el material y en el panel",
		BodyMaterial.get_color(mesh, "skin_color") == skin and BodyMaterial.get_finish(mesh) == defaults
		and panel.skin_button.color == skin and _slider_values(panel) == defaults, str(BodyMaterial.get_finish(mesh)))


func _slider_values(panel) -> Dictionary:
	var values := {}
	for key: String in panel.sliders:
		values[key] = panel.sliders[key].value
	return values
