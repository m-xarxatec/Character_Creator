extends SceneTree
# Paso 4.4: lógica del editor de la pestaña Cuerpo (godot/app/body_editor.gd): simetría, igualar lados, deshacer y rehacer,
# y restablecer zona. Sin ventana y sin interfaz, con los deslizadores y el preset de personaje nuevo de datos/humana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_edicion.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')

var failures := 0
var editor
var changes := 0  # avisos changed del editor


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var species = load(root_dir.path_join("godot/addons/creador/species_data.gd")).new()
	species.load_folder(root_dir.path_join("godot/datos/humana"))
	check("carga datos/humana", species.error == "", species.error)
	if species.error == "":
		var preset = load(root_dir.path_join("godot/addons/creador/preset.gd"))
		var loaded: Dictionary = preset.from_text(species.preset_text(), "humana", species.sliders)
		editor = load(root_dir.path_join("godot/app/body_editor.gd")).new(species.sliders, loaded["valores"])
		editor.changed.connect(func() -> void: changes += 1)
		_check_start(loaded["valores"])
		_check_symmetry()
		_check_drag()
		_check_reset()
		_check_history()
		species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_start(preset_values: Dictionary) -> void:
	check("empieza con los valores del preset", editor.values == preset_values)
	check("y es una copia (no cambia el preset)", not is_same(editor.values, preset_values))
	check("simetría activada, sin nada que deshacer ni rehacer", editor.symmetry and not editor.can_undo() and not editor.can_redo())
	check("el preset tiene los lados iguales", editor.differing_sides().is_empty())


func _check_symmetry() -> void:
	editor.set_value("hand_size_l", 0.8)
	check("con simetría, mover la izq. mueve la der.", editor.values["hand_size_r"] == 0.8)
	check("un cambio para Deshacer y un aviso", _steps() == 1 and changes == 1, "%d / %d" % [_steps(), changes])
	editor.symmetry = false
	editor.set_value("hand_size_l", 0.3)
	check("sin simetría, la der. no se mueve", editor.values["hand_size_r"] == 0.8)
	var differences: Array[Dictionary] = editor.differing_sides()
	check("lados distintos: Manos › Tamaño, 0,3 / 0,8", differences.size() == 1 and differences[0]["zona"] == "Manos"
			and differences[0]["nombre"] == "Tamaño" and differences[0]["_l"] == 0.3 and differences[0]["_r"] == 0.8,
			str(differences))
	var steps := _steps()
	editor.match_side("_l")
	check("igualar a la izquierda copia la izq.", editor.values["hand_size_r"] == 0.3 and editor.values["hand_size_l"] == 0.3)
	check("igualar es un solo cambio", _steps() == steps + 1, str(_steps()))
	check("ya no hay lados distintos", editor.differing_sides().is_empty())
	editor.undo()
	check("deshacer igualar devuelve 0,3 / 0,8", editor.values["hand_size_l"] == 0.3 and editor.values["hand_size_r"] == 0.8)
	editor.match_side("_r")
	check("igualar a la derecha copia la der.", editor.values["hand_size_l"] == 0.8 and editor.values["hand_size_r"] == 0.8)
	steps = _steps()
	editor.match_side("_r")
	check("igualar con los lados iguales no es un cambio", _steps() == steps)
	editor.symmetry = true


func _check_drag() -> void:
	var before: Dictionary = editor.values.duplicate()
	var steps := _steps()
	editor.begin_change()
	for value in [0.6, 0.7, 0.9]:
		editor.set_value("height", value)
	editor.end_change()
	check("un arrastre entero es un solo cambio", _steps() == steps + 1, str(_steps() - steps))
	editor.undo()
	check("y se deshace de una vez", editor.values == before)
	steps = _steps()
	editor.begin_change()
	editor.end_change()
	check("pulsar y soltar sin mover no es un cambio", _steps() == steps)
	check("rechaza NaN y claves desconocidas sin cambiar nada", not editor.set_value("height", NAN)
			and not editor.set_value("no_existe", 0.5) and _steps() == steps and editor.values == before)


func _check_reset() -> void:
	editor.set_value("height", 0.9)
	editor.set_value("hand_size_l", 1.0)
	editor.set_value("hand_position_r", 0.1)
	var steps := _steps()
	editor.reset_zone("Manos")
	var hands := ["hand_size_l", "hand_size_r", "hand_position_l", "hand_position_r"]
	check("restablecer Manos: sus 4 valores al neutro (0,5)", hands.all(func(key: String) -> bool: return editor.values[key] == 0.5))
	check("y no toca otras zonas", editor.values["height"] == 0.9)
	check("restablecer es un solo cambio", _steps() == steps + 1)
	editor.undo()
	check("deshacer lo devuelve", editor.values["hand_size_l"] == 1.0 and editor.values["hand_position_r"] == 0.1)


func _check_history() -> void:
	editor.set_value("height", 0.2)
	var after: Dictionary = editor.values.duplicate()
	editor.undo()
	check("rehacer vuelve a aplicar el cambio", editor.can_redo() and editor.redo() and editor.values == after)
	editor.undo()
	editor.set_value("muscle", 0.9)
	check("un cambio nuevo borra lo que había para rehacer", not editor.can_redo())
	for i in 250:
		editor.set_value("weight", float(i % 2))
	var undone := 0
	while editor.undo():
		undone += 1
	check("el historial guarda %d cambios" % editor.MAX_HISTORY, undone == editor.MAX_HISTORY, str(undone))
	check("deshacer con el historial vacío no hace nada", not editor.undo())


func _steps() -> int:
	return editor._undo.size()
