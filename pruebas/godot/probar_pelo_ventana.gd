extends SceneTree
# Paso PE.4b (corrección): con una animación en marcha, cambiar de peinado con cadenas (HairChains.remove rehace los
# huesos) no congela el cuerpo: la GPU sigue recibiendo la pose de la piel del cuerpo y de su copia de estilo.
# NECESITA VENTANA (sin ella el servidor de dibujo es de mentira y no guarda poses).
# Uso: (ulimit -v 4000000; timeout 120 godot --path pruebas/godot -s probar_pelo_ventana.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en HairChains.remove, quitar el bucle que vuelve a dar el esqueleto a las mallas -> falla
# «tras cambiar de peinado, el cuerpo se sigue moviendo».

const FRAMES := 20
const MIN_DISTINCT := 15  # PROVISIONAL: de FRAMES fotogramas, cuántas poses distintas del brazo en la GPU (medido 20)
const ARM_BIND := 20  # un bind del cuerpo que se mueve con «atacar»
var failures := 0


func _initialize() -> void:
	var main: Control = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/main.gd").simplify_path()).new()
	root.add_child(main)
	await process_frame
	var view = main.body_view
	if RenderingServer.get_rendering_device() == null and DisplayServer.get_name() == "headless":
		print("ERROR: esta prueba necesita ventana")
		quit(1)
		return
	view.set_animation("atacar")
	view.set_piece("makehuman", "bob02", true)
	await _check(view, "con bob02")
	view.set_piece("makehuman", "short02", true)  # quita bob02 y sus cadenas
	await _check(view, "tras cambiar de peinado")
	view.set_piece("makehuman", "short02", false)
	await _check(view, "tras quitar el peinado")
	view.set_animation("")
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check(view, label: String) -> void:
	for mesh: MeshInstance3D in [view.species.mesh, view.style]:
		var reference := mesh.get_skin_reference()
		var seen := {}
		for f in FRAMES:
			await process_frame
			if reference != null:
				seen[str(RenderingServer.skeleton_bone_get_transform(reference.get_skeleton(), ARM_BIND))] = true
		print("  MEDIDA %s, %s: %d poses distintas en %d fotogramas" % [label, mesh.name, seen.size(), FRAMES])
		check("%s, el cuerpo se sigue moviendo (%s)" % [label, mesh.name], seen.size() >= MIN_DISTINCT, "%d" % seen.size())
