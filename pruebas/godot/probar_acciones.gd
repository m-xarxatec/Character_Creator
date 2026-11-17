extends SceneTree
# Paso 4.5: barra inferior de la pestaña Cuerpo (godot/app/body_actions.gd) dentro de la ventana (main.gd):
# Prenda base, Probar huesos, Exportar .glb y la lista Animación (paso 5.1). Sin ventana. Exporta a user://acciones/ (no pisa otras pruebas).
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_acciones.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')

const OUT := "user://acciones"

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
		var bar = main.body_actions
		check("la barra tiene sus tres controles", bar.bones_button != null and bar.export_button != null
				and bar.garment_check != null)
		_check_garment(bar, main.body_view.species.mesh)
		_check_bones(bar, main.body_view)
		_check_export(bar, main.body_view)
		_check_animation(bar, main.body_view)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_garment(bar, mesh: MeshInstance3D) -> void:
	var start: bool = BodyMaterial.is_garment_visible(mesh)
	check("la casilla empieza como el material", bar.garment_check.button_pressed == start)
	bar.garment_check.button_pressed = not start
	check("pulsar la casilla cambia la prenda", BodyMaterial.is_garment_visible(mesh) == not start)
	bar.garment_check.button_pressed = start
	check("volver a pulsarla la deja como estaba", BodyMaterial.is_garment_visible(mesh) == start)


func _check_bones(bar, view) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	var hand := skeleton.find_bone("RightHand")
	var before := _poses(skeleton)
	var rest_hand := skeleton.get_bone_global_pose(hand).origin
	bar.bones_button.emit_signal("pressed")
	var t_hand := skeleton.get_bone_global_pose(hand).origin
	check("Probar huesos pone la pose T", view.pose_t and bar.bones_button.button_pressed)
	check("en pose T la mano sube", t_hand.y > rest_hand.y + 0.1, "%.3f → %.3f m" % [rest_hand.y, t_hand.y])
	var values: Dictionary = view.values.duplicate()
	values["head_size"] = 1.0
	view.set_values(values)
	check("mover un deslizador mantiene la pose T", skeleton.get_bone_global_pose(hand).origin.y > rest_hand.y + 0.1)
	values["head_size"] = 0.5
	view.set_values(values)
	bar.bones_button.emit_signal("pressed")
	check("volver al reposo deja el esqueleto igual", not view.pose_t and _poses(skeleton) == before)


func _check_export(bar, view) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var start := Time.get_ticks_msec()
	var error: Error = bar.export_to(OUT.path_join("reposo.glb"))
	print("  MEDIDA exportar: %d ms" % (Time.get_ticks_msec() - start))
	check("exportar desde el reposo da OK", error == OK, error_string(error))
	check("crea el .glb y el .tres", FileAccess.file_exists(OUT.path_join("reposo.glb"))
			and FileAccess.file_exists(OUT.path_join("reposo.tres")))
	check("el aviso dice la ruta", bar.message.visible and bar.message.dialog_text.contains("reposo.glb"))
	check("el botón vuelve a su texto", bar.export_button.text == "Exportar .glb" and not bar.export_button.disabled)
	bar.set_pose_t(true)
	bar.export_to(OUT.path_join("pose_t.glb"))
	bar.set_pose_t(false)
	var same := FileAccess.get_file_as_bytes(OUT.path_join("reposo.glb")) \
			== FileAccess.get_file_as_bytes(OUT.path_join("pose_t.glb"))
	check("desde la pose T sale el mismo archivo", same)
	error = bar.export_to("/no/existe/personaje.glb")
	check("una ruta mala da error", error != OK, error_string(error))
	check("el aviso dice que no se pudo", bar.message.dialog_text.begins_with("No se pudo"))


# Va después de _check_export: compara con reposo.glb.
func _check_animation(bar, view) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	var before := _poses(skeleton)
	check("las animaciones cargan", view.animation_error == "", view.animation_error)
	check("la lista tiene «Sin animación», los 5 clips, las 3 poses y el rango de movimiento", bar.animation_list.item_count == 10
		and bar.animation_list.get_item_text(9) == "Rango de movimiento" and not bar.animation_list.disabled)
	bar.animation_list.select(2)
	bar.animation_list.emit_signal("item_selected", 2)
	var start := _poses(skeleton)
	check("elegir Caminar mueve el maniquí", view.clip == "caminar" and start != before)
	view._process(0.2)
	check("el clip avanza con el tiempo", _poses(skeleton) != start)
	var values: Dictionary = view.values.duplicate()
	values["head_size"] = 1.0
	view.set_values(values)
	check("mover un deslizador no para la animación", view.clip == "caminar" and _poses(skeleton) != before)
	values["head_size"] = 0.5
	view.set_values(values)
	bar.export_to(OUT.path_join("animado.glb"))
	var same := FileAccess.get_file_as_bytes(OUT.path_join("reposo.glb")) \
			== FileAccess.get_file_as_bytes(OUT.path_join("animado.glb"))
	check("con una animación en marcha sale el mismo archivo", same)
	var hips := skeleton.find_bone("Hips")
	var standing := skeleton.get_bone_global_pose(hips).origin.y
	bar.set_animation(7)
	var squat := _poses(skeleton)
	check("elegir Sentadilla baja la cadera", view.clip == "sentadilla" and skeleton.get_bone_global_pose(hips).origin.y < standing - 0.2)
	view._process(0.2)
	check("una pose fija no cambia con el tiempo", _poses(skeleton) == squat)
	values["head_size"] = 1.0
	view.set_values(values)
	values["head_size"] = 0.5
	view.set_values(values)
	check("mover un deslizador y devolverlo deja la misma pose", _poses(skeleton) == squat)
	bar.set_animation(0)
	check("«Sin animación» deja el esqueleto como estaba", view.clip == "" and _poses(skeleton) == before)
	check("un clip que no existe se rechaza", not view.set_animation("volar") and view.clip == "")


func _poses(skeleton: Skeleton3D) -> Array:
	var poses := []
	for bone in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(bone))
	return poses
