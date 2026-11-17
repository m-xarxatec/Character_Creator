extends SceneTree
# Paso A2: dentro del proyecto principal, el editor encuentra datos/ en res://datos (lo que viaja en el .pck).
# Se lanza con el proyecto principal (no con pruebas/godot, que es otro proyecto y usa la carpeta junto a app/):
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path godot -s "$PWD/pruebas/godot/probar_datos.gd" 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en body_view.gd, cambiar DATA_RES a "res://otra" -> falla «busca en res://datos».

var failures := 0


func _initialize() -> void:
	var view: SubViewportContainer = load("res://app/body_view.gd").new()
	root.add_child(view)
	await process_frame
	var folder: String = view._data_folder()
	check("busca en res://datos (dentro del proyecto)", folder == "res://datos/humana", folder)
	check("carga la especie sin error", view.error == "", view.error)
	check("carga las animaciones sin error", view.animation_error == "", view.animation_error)
	print("  MEDIDA carga del maniquí: %d ms" % view.load_ms)
	view.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
