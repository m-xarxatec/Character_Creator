extends SceneTree
# Paso IU.8: medidas en vivo (godot/app/measures.gd) y barra de estado (status_bar.gd) dentro de la ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_medidas.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en main.refresh_measures, medir sin mirar la pose -> sentado, la altura cambia.

const HEIGHT_MM := 1.0  # diferencia con la medida exacta, en mm
const HEADS := 0.05  # diferencia con la medida exacta, en cabezas
const ROOT_SCALE := 1.15  # escala:Root=1.15 con Global › Altura a 1 (deslizadores.csv)

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var MeshBaker: GDScript = load(godot_dir.path_join("addons/creador/mesh_baker.gd"))
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var mesh: MeshInstance3D = main.body_view.species.mesh
	var skeleton: Skeleton3D = main.body_view.species.skeleton
	var fast: Dictionary = main.measures.measure(mesh, skeleton)
	var exact := _exact(MeshBaker.bake(mesh, skeleton)["vertices"], main.measures.head_mask(mesh, skeleton))
	print("  MEDIDA neutro: rápida %.4f m, %.3f cabezas; exacta %.4f m, %.3f cabezas" % [fast["height"], fast["heads"],
		exact["height"], exact["heads"]])
	check("altura rápida = exacta (± %.0f mm)" % HEIGHT_MM, absf(fast["height"] - exact["height"]) * 1000.0 <= HEIGHT_MM)
	check("cabezas rápidas = exactas (± %.2f)" % HEADS, absf(fast["heads"] - exact["heads"]) <= HEADS)

	main.editor.set_value("height", 1.0)
	var tall: Dictionary = main.measures.measure(mesh, skeleton)
	check("Global › Altura a 1 multiplica la altura por %.2f (± %.0f mm)" % [ROOT_SCALE, HEIGHT_MM],
		absf(tall["height"] - fast["height"] * ROOT_SCALE) * 1000.0 <= HEIGHT_MM, "%.4f m" % tall["height"])
	main.refresh_measures()
	var text: String = main.status_bar.measures_label.text
	check("la barra dice la altura con coma y las cabezas", text.begins_with("%s m" % ("%.2f" % tall["height"]).replace(".", ","))
		and text.ends_with("cabezas"), text)
	var triangles: int = mesh.mesh.surface_get_array_index_len(0) / 3
	check("la barra dice el presupuesto: %d triángulos con punto de miles y los 53 huesos que se exportan" % triangles,
		main.status_bar.budget_label.text == "%s triángulos  ·  53 huesos" % main.status_bar.thousands(triangles),
		main.status_bar.budget_label.text)
	check("26756 se escribe «26.756»", main.status_bar.thousands(26756) == "26.756" and main.status_bar.thousands(53) == "53")

	check("sin probar, la pastilla invita a probar los huesos", main.status_bar.report_button.text == main.status_bar.IDLE)
	main.body_actions.set_pose_t(true)
	var button: Button = main.status_bar.report_button
	check("con Probar huesos, la pastilla dice el resumen con su icono", button.text.begins_with("Informe: ")
		and button.text != main.status_bar.IDLE and button.icon != null, button.text)
	check("y la altura no cambia mientras se prueba (se mide en reposo)", main.status_bar.measures_label.text == text,
		main.status_bar.measures_label.text)
	button.pressed.emit()
	check("pulsar la pastilla despliega el informe", main.report_panel.visible)
	main.body_actions.set_pose_t(false)
	var entries: Array = main.body_view.animations.entries().map(func(e: Dictionary) -> String: return e["id"])
	main.body_actions.set_animation(1 + entries.find("sentarse"))
	main.refresh_measures()
	check("sentado tampoco cambia: la altura es la de pie (en reposo)", main.status_bar.measures_label.text == text,
		main.status_bar.measures_label.text)
	main.body_actions.set_animation(0)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


## La medida exacta del 3.12: toda la malla horneada; barbilla = el más bajo del centro y delante de la cabeza.
func _exact(vertices: PackedVector3Array, mask: PackedByteArray) -> Dictionary:
	var top := -INF
	var bottom := INF
	var head_box := AABB()
	var first := true
	for i in vertices.size():
		top = maxf(top, vertices[i].y)
		bottom = minf(bottom, vertices[i].y)
		if mask[i]:
			head_box = AABB(vertices[i], Vector3.ZERO) if first else head_box.expand(vertices[i])
			first = false
	var chin := INF
	for i in vertices.size():
		if mask[i] and absf(vertices[i].x) < 0.1 * head_box.size.x and vertices[i].z > head_box.get_center().z:
			chin = minf(chin, vertices[i].y)
	return {"height": top - bottom, "heads": (top - bottom) / (top - chin)}


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
