extends SceneTree
# Paso P.3: la cámara del editor encuadra el personaje entero (orbit_camera.gd frame, body_view.gd frame_character). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 200 godot --headless --path pruebas/godot -s probar_encuadre.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Proyecta todos los vértices horneados (MeshBaker, la pose de ahora) con la cámara y mira que caben y no quedan pequeños.
# Que detecta el fallo: sin frame_character, con la altura a 1 la cabeza o los pies se salen.

const MIN_FILL := 0.6  # PROVISIONAL: parte del alto (o del ancho) de la vista que ocupa el personaje

var failures := 0
var MeshBaker: GDScript


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	MeshBaker = load(godot_dir.path_join("addons/creador/mesh_baker.gd"))
	var screen := SubViewport.new()  # sin ventana, la de Godot mide 64 × 64 y no se puede cambiar
	screen.size = Vector2i(1280, 720)
	root.add_child(screen)
	var main: Control = load(godot_dir.path_join("app/main.gd")).new()
	screen.add_child(main)
	await process_frame
	await process_frame
	var view = main.body_view
	var walk: int = 1 + view.animations.entries().map(func(e: Dictionary) -> String: return e["id"]).find("caminar")
	await _case("inicio", main)
	main.editor.set_value("height", 1.0)
	main.body_actions.set_pose_t(true)
	await _case("altura 1, pose T", main)
	main.body_actions.set_pose_t(false)
	main.editor.set_value("height", 0.0)
	await _case("altura 0", main)
	main.editor.set_value("height", 1.0)
	main.body_actions.set_animation(walk)
	await _case("altura 1, Caminar", main)
	main.body_actions.set_animation(0)
	main.report_section.set_open(true)
	await _case("altura 1, informe desplegado", main)
	var start := Time.get_ticks_msec()
	view.frame_character()
	print("  MEDIDA encuadrar: %d ms" % (Time.get_ticks_msec() - start))
	view.camera.zoom_by(-3)
	check("la rueda sigue acercando", view.camera.distance < view.camera.goal_distance - 0.1)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	screen.free()
	quit(1 if failures else 0)


func _case(name: String, main: Control) -> void:
	await create_timer(0.5).timeout  # el temporizador del estilo (al soltar un deslizador) y el tamaño de la vista
	var view = main.body_view
	view.camera.snap()  # sin esperar al movimiento suave
	var camera: Camera3D = view.camera
	var size := Vector2(view.viewport.size)
	var vertices: PackedVector3Array = MeshBaker.bake(view.species.mesh, view.species.skeleton)["vertices"]
	var to_world: Transform3D = view.species.mesh.global_transform
	var low := Vector2(INF, INF)
	var high := -low
	for point in vertices:
		var screen := camera.unproject_position(to_world * point)
		low = low.min(screen)
		high = high.max(screen)
	var inside := low.x >= 0 and low.y >= 0 and high.x <= size.x and high.y <= size.y
	var fill := maxf((high.y - low.y) / size.y, (high.x - low.x) / size.x)
	print("  MEDIDA %s: vista %dx%d, personaje de %s a %s px, ocupa %.0f %%" % [name, size.x, size.y, low.round(), high.round(), fill * 100])
	check("%s: cabe entero" % name, inside)
	check("%s: no queda pequeño (%.0f %%)" % [name, fill * 100], fill >= MIN_FILL)


func check(text: String, ok: bool) -> void:
	print(("BIEN  " if ok else "FALLO ") + text)
	if not ok:
		failures += 1
